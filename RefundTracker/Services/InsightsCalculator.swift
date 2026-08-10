import Foundation

struct RetailerRefundPerformance: Identifiable, Equatable {
    var id: String { retailerName }
    let retailerName: String
    let averageDays: Double
    let completedRefundCount: Int
}

struct MonthlyRefundTotal: Identifiable, Equatable {
    var id: Date { month }
    let month: Date
    let amount: Decimal
    let refundCount: Int
}

struct InsightsMetrics {
    let totalRefundsReceived: Decimal
    let totalRefundsPending: Decimal
    let completedRefundCount: Int
    let completedRetailerCount: Int
    let averageRefundDays: Double?
    let retailerPerformance: [RetailerRefundPerformance]
    let overdueRefundCount: Int
    let overdueRefundValue: Decimal
    let monthlyRefundTotals: [MonthlyRefundTotal]
    let currencyCode: String
}

enum InsightsCalculator {
    static func calculate(
        refunds: [Refund],
        currencyCode: String,
        now: Date = .now,
        calendar: Calendar = .current,
        monthCount: Int = 6
    ) -> InsightsMetrics {
        let normalizedCurrency = currencyCode.uppercased()
        let records = refunds.filter {
            $0.currencyCode.uppercased() == normalizedCurrency
        }
        let completed = records.filter {
            $0.effectiveStatus(on: now, calendar: calendar) == .refunded
        }
        let pending = records.filter {
            $0.effectiveStatus(on: now, calendar: calendar).isOpen
        }
        let overdue = records.filter {
            $0.effectiveStatus(on: now, calendar: calendar) == .overdue
        }

        let durations = completed.compactMap { refund -> Int? in
            guard let actualDate = refund.actualRefundDate else { return nil }
            return max(
                0,
                calendar.dateComponents(
                    [.day],
                    from: calendar.startOfDay(for: refund.returnDate),
                    to: calendar.startOfDay(for: actualDate)
                ).day ?? 0
            )
        }

        let averageDays = durations.isEmpty
            ? nil
            : Double(durations.reduce(0, +)) / Double(durations.count)

        let retailerPerformance = Dictionary(grouping: completed, by: \.retailerName)
            .compactMap { retailer, retailerRefunds -> RetailerRefundPerformance? in
                let days = retailerRefunds.compactMap { refund -> Int? in
                    guard let actualDate = refund.actualRefundDate else { return nil }
                    return max(
                        0,
                        calendar.dateComponents(
                            [.day],
                            from: calendar.startOfDay(for: refund.returnDate),
                            to: calendar.startOfDay(for: actualDate)
                        ).day ?? 0
                    )
                }
                guard !days.isEmpty else { return nil }
                return RetailerRefundPerformance(
                    retailerName: retailer,
                    averageDays: Double(days.reduce(0, +)) / Double(days.count),
                    completedRefundCount: days.count
                )
            }
            .sorted {
                if $0.averageDays == $1.averageDays {
                    return $0.retailerName < $1.retailerName
                }
                return $0.averageDays > $1.averageDays
            }

        let monthlyTotals = monthlyTotals(
            completed: completed,
            now: now,
            calendar: calendar,
            monthCount: monthCount
        )

        return InsightsMetrics(
            totalRefundsReceived: completed.reduce(0) { $0 + $1.refundAmount },
            totalRefundsPending: pending.reduce(0) { $0 + $1.refundAmount },
            completedRefundCount: completed.count,
            completedRetailerCount: Set(completed.map(\.retailerName)).count,
            averageRefundDays: averageDays,
            retailerPerformance: retailerPerformance,
            overdueRefundCount: overdue.count,
            overdueRefundValue: overdue.reduce(0) { $0 + $1.refundAmount },
            monthlyRefundTotals: monthlyTotals,
            currencyCode: normalizedCurrency
        )
    }

    private static func monthlyTotals(
        completed: [Refund],
        now: Date,
        calendar: Calendar,
        monthCount: Int
    ) -> [MonthlyRefundTotal] {
        let currentMonth = calendar.date(
            from: calendar.dateComponents([.year, .month], from: now)
        ) ?? calendar.startOfDay(for: now)

        return (0..<max(1, monthCount)).reversed().compactMap { offset in
            guard let month = calendar.date(
                byAdding: .month,
                value: -offset,
                to: currentMonth
            ),
            let nextMonth = calendar.date(byAdding: .month, value: 1, to: month) else {
                return nil
            }

            let records = completed.filter {
                let date = $0.actualRefundDate ?? $0.lastUpdatedDate
                return date >= month && date < nextMonth
            }
            return MonthlyRefundTotal(
                month: month,
                amount: records.reduce(0) { $0 + $1.refundAmount },
                refundCount: records.count
            )
        }
    }
}
