import Foundation
import Observation

@MainActor
@Observable
final class RefundListViewModel {
    var searchText = ""
    var selectedScope: RefundFilterScope = .active
    var sortOption: RefundSortOption = .expectedRefundDate
    var sortDirection: RefundSortDirection = .ascending
    var selectedRetailer: String?
    var selectedMethod: RefundMethod?
    var usesExpectedDateRange = false
    var selectedDateField: RefundDateField = .expectedRefundDate
    var expectedDateStart = Calendar.current.startOfDay(for: .now)
    var expectedDateEnd = Calendar.current.date(
        byAdding: .month,
        value: 1,
        to: Calendar.current.startOfDay(for: .now)
    ) ?? .now

    var hasAdvancedFilters: Bool {
        selectedRetailer != nil
            || selectedMethod != nil
            || usesExpectedDateRange
    }

    var appliedFilterCount: Int {
        (selectedScope == .all ? 0 : 1)
            + (selectedRetailer == nil ? 0 : 1)
            + (selectedMethod == nil ? 0 : 1)
            + (usesExpectedDateRange ? 1 : 0)
    }

    func results(from refunds: [Refund], now: Date = .now) -> [Refund] {
        // Ordering the bounds here keeps the range usable however the filter
        // sheet is closed. Swiping it away skips `normalizeDateRange()`, and an
        // inverted range would otherwise match nothing with no explanation.
        let filter = RefundFilter(
            scope: selectedScope,
            searchText: searchText,
            retailer: selectedRetailer,
            startDate: usesExpectedDateRange
                ? min(expectedDateStart, expectedDateEnd)
                : nil,
            endDate: usesExpectedDateRange
                ? max(expectedDateStart, expectedDateEnd)
                : nil,
            dateField: selectedDateField,
            refundMethod: selectedMethod
        )
        return RefundQueryService.filterAndSort(
            refunds,
            filter: filter,
            sort: sortOption,
            direction: sortDirection,
            now: now
        )
    }

    func clearFilters() {
        selectedScope = .all
        selectedRetailer = nil
        selectedMethod = nil
        usesExpectedDateRange = false
    }

    func normalizeDateRange() {
        if expectedDateStart > expectedDateEnd {
            let oldStart = expectedDateStart
            expectedDateStart = expectedDateEnd
            expectedDateEnd = oldStart
        }
    }
}
