import Foundation
import Observation

@MainActor
@Observable
final class RefundListViewModel {
    var searchText = ""
    var selectedScope: RefundFilterScope = .active
    var sortOption: RefundSortOption = .expectedRefundDate
    var sortDirection: RefundSortDirection = .ascending

    func results(from refunds: [Refund], now: Date = .now) -> [Refund] {
        let filter = RefundFilter(
            scope: selectedScope,
            searchText: searchText
        )
        return RefundQueryService.filterAndSort(
            refunds,
            filter: filter,
            sort: sortOption,
            direction: sortDirection,
            now: now
        )
    }
}
