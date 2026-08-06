import Foundation
import Observation

@MainActor
@Observable
final class RefundListViewModel {
    var searchText = ""
    var selectedScope: RefundFilterScope = .all
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
        let filter = RefundFilter(
            scope: selectedScope,
            searchText: searchText,
            retailer: selectedRetailer,
            startDate: usesExpectedDateRange ? expectedDateStart : nil,
            endDate: usesExpectedDateRange ? expectedDateEnd : nil,
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
