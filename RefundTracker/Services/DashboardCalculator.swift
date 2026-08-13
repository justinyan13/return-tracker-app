import Foundation

struct DashboardMetrics {
    let totalAwaitingRefund: Decimal
    let headlineCurrencyCode: String
    let awaitingAmountsByCurrency: [String: Decimal]
    let openReturnCount: Int
    let overdueRefundCount: Int
    let refundedCount: Int
    let completedThisMonthCount: Int
    let completedThisMonthAmount: Decimal
    let attentionRefunds: [Refund]
    let upcomingRefunds: [Refund]

    static let empty = DashboardMetrics(
        totalAwaitingRefund: 0,
        headlineCurrencyCode: Locale.current.currency?.identifier ?? "USD",
        awaitingAmountsByCurrency: [:],
        openReturnCount: 0,
        overdueRefundCount: 0,
        refundedCount: 0,
        completedThisMonthCount: 0,
        completedThisMonthAmount: 0,
        attentionRefunds: [],
        upcomingRefunds: []
    )
}

enum DashboardCalculator {
    static func calculate(
        refunds: [Refund],
        now: Date = .now,
        calendar: Calendar = .current,
        upcomingDays: Int = 14,
        headlineCurrencyCode: String? = nil
    ) -> DashboardMetrics {
        let openRefunds = refunds.filter {
            $0.effectiveStatus(on: now, calendar: calendar).isOpen
        }

        let amountsByCurrency = Dictionary(
            grouping: openRefunds,
            by: { $0.currencyCode.uppercased() }
        )
            .mapValues { records in
                records.reduce(Decimal.zero) { $0 + $1.refundAmount }
            }

        let preferredCurrency = (
            headlineCurrencyCode ??
            (amountsByCurrency.count == 1 ? amountsByCurrency.keys.first : nil) ??
            Locale.current.currency?.identifier ??
            "USD"
        ).uppercased()
        let totalAwaiting = amountsByCurrency[preferredCurrency] ?? 0

        let overdue = refunds.filter {
            $0.effectiveStatus(on: now, calendar: calendar) == .overdue
        }

        let refunded = refunds.filter {
            $0.effectiveStatus(on: now, calendar: calendar) == .refunded
        }

        let completedThisMonth = refunds.filter { refund in
            guard refund.effectiveStatus(on: now, calendar: calendar) == .refunded else {
                return false
            }
            let completionDate = refund.actualRefundDate ?? refund.lastUpdatedDate
            return calendar.isDate(
                completionDate,
                equalTo: now,
                toGranularity: .month
            ) &&
                calendar.isDate(
                    completionDate,
                    equalTo: now,
                    toGranularity: .year
                )
        }

        let attention = refunds
            .filter {
                let status = $0.effectiveStatus(on: now, calendar: calendar)
                return status == .overdue || status == .disputed
            }
            .sorted {
                let lhsStatus = $0.effectiveStatus(on: now, calendar: calendar)
                let rhsStatus = $1.effectiveStatus(on: now, calendar: calendar)
                if lhsStatus.sortOrder != rhsStatus.sortOrder {
                    return lhsStatus.sortOrder < rhsStatus.sortOrder
                }
                return $0.expectedRefundDate < $1.expectedRefundDate
            }

        let startOfToday = calendar.startOfDay(for: now)
        let upcomingLimit = calendar.date(
            byAdding: .day,
            value: max(0, upcomingDays),
            to: startOfToday
        ) ?? startOfToday

        let upcoming = refunds
            .filter { refund in
                let status = refund.effectiveStatus(on: now, calendar: calendar)
                guard status.isOpen, status != .overdue, status != .disputed else {
                    return false
                }
                let expectedDay = calendar.startOfDay(for: refund.expectedRefundDate)
                return expectedDay >= startOfToday && expectedDay <= upcomingLimit
            }
            .sorted { $0.expectedRefundDate < $1.expectedRefundDate }

        return DashboardMetrics(
            totalAwaitingRefund: totalAwaiting,
            headlineCurrencyCode: preferredCurrency,
            awaitingAmountsByCurrency: amountsByCurrency,
            openReturnCount: openRefunds.count,
            overdueRefundCount: overdue.count,
            refundedCount: refunded.count,
            completedThisMonthCount: completedThisMonth.count,
            completedThisMonthAmount: completedThisMonth.reduce(Decimal.zero) {
                $1.currencyCode.uppercased() == preferredCurrency
                    ? $0 + $1.refundAmount
                    : $0
            },
            attentionRefunds: attention,
            upcomingRefunds: upcoming
        )
    }
}
