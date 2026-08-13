import Foundation

/// The scopes shown as tabs above the list, in the order they appear.
enum RefundFilterScope: String, CaseIterable, Identifiable, Sendable {
    case active
    case overdue
    case refunded
    case all

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .active: "Open"
        case .overdue: "Overdue"
        case .refunded: "Refunded"
        case .all: "All"
        }
    }
}

struct RefundFilter: Sendable {
    var scope: RefundFilterScope
    var searchText: String

    init(
        scope: RefundFilterScope = .all,
        searchText: String = ""
    ) {
        self.scope = scope
        self.searchText = searchText
    }

    static let all = RefundFilter()
}

enum RefundSortOption: String, CaseIterable, Identifiable, Sendable {
    case expectedRefundDate
    case refundAmount
    case returnDate
    case retailer
    case status

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .expectedRefundDate: "Expected refund date"
        case .refundAmount: "Refund amount"
        case .returnDate: "Return date"
        case .retailer: "Retailer"
        case .status: "Status"
        }
    }
}

enum RefundSortDirection: String, CaseIterable, Identifiable, Sendable {
    case ascending
    case descending

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .ascending: "Ascending"
        case .descending: "Descending"
        }
    }
}

enum RefundQueryService {
    static func filter(
        _ refunds: [Refund],
        using filter: RefundFilter,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> [Refund] {
        refunds.filter { refund in
            matchesScope(refund, scope: filter.scope, now: now, calendar: calendar) &&
                matchesSearch(refund, text: filter.searchText)
        }
    }

    static func sort(
        _ refunds: [Refund],
        by option: RefundSortOption,
        direction: RefundSortDirection = .ascending,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> [Refund] {
        refunds.sorted { lhs, rhs in
            let ordering = compare(
                lhs,
                rhs,
                by: option,
                now: now,
                calendar: calendar
            )

            if ordering == .orderedSame {
                return lhs.id.uuidString < rhs.id.uuidString
            }
            return direction == .ascending
                ? ordering == .orderedAscending
                : ordering == .orderedDescending
        }
    }

    static func filterAndSort(
        _ refunds: [Refund],
        filter: RefundFilter = .all,
        sort: RefundSortOption = .expectedRefundDate,
        direction: RefundSortDirection = .ascending,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> [Refund] {
        let filtered = self.filter(
            refunds,
            using: filter,
            now: now,
            calendar: calendar
        )
        return self.sort(
            filtered,
            by: sort,
            direction: direction,
            now: now,
            calendar: calendar
        )
    }

    private static func matchesScope(
        _ refund: Refund,
        scope: RefundFilterScope,
        now: Date,
        calendar: Calendar
    ) -> Bool {
        let status = refund.effectiveStatus(on: now, calendar: calendar)
        switch scope {
        case .all:
            return true
        case .active:
            return status.isOpen
        case .overdue:
            return status == .overdue
        case .refunded:
            return status == .refunded
        }
    }

    private static func matchesSearch(_ refund: Refund, text: String) -> Bool {
        let query = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return true }

        return [
            refund.retailerName,
            refund.itemName,
            refund.orderNumber,
            refund.trackingNumber,
            refund.returnCarrier,
            refund.notes
        ]
        .contains { $0.localizedCaseInsensitiveContains(query) }
    }

    private static func compare(
        _ lhs: Refund,
        _ rhs: Refund,
        by option: RefundSortOption,
        now: Date,
        calendar: Calendar
    ) -> ComparisonResult {
        switch option {
        case .expectedRefundDate:
            lhs.expectedRefundDate.compare(rhs.expectedRefundDate)
        case .refundAmount:
            NSDecimalNumber(decimal: lhs.refundAmount).compare(
                NSDecimalNumber(decimal: rhs.refundAmount)
            )
        case .returnDate:
            lhs.returnDate.compare(rhs.returnDate)
        case .retailer:
            lhs.retailerName.localizedCaseInsensitiveCompare(rhs.retailerName)
        case .status:
            {
                let left = lhs.effectiveStatus(on: now, calendar: calendar).sortOrder
                let right = rhs.effectiveStatus(on: now, calendar: calendar).sortOrder
                if left == right { return .orderedSame }
                return left < right ? .orderedAscending : .orderedDescending
            }()
        }
    }
}
