import XCTest
@testable import RefundTracker

final class RefundListViewModelTests: XCTestCase {
    private let calendar = DomainTestSupport.calendar

    private func refund(expected: Date, retailer: String = "Merchant") -> Refund {
        Refund(
            retailerName: retailer,
            itemName: "Item",
            refundAmount: 25,
            currencyCode: "USD",
            returnDate: DomainTestSupport.date(2026, 8, 1),
            expectedRefundDate: expected,
            status: .shipped
        )
    }

    @MainActor
    func testInitialScopeIsOpenAndScopesUseRequestedOrder() {
        let viewModel = RefundListViewModel()

        XCTAssertEqual(viewModel.selectedScope, .active)
        XCTAssertEqual(viewModel.selectedScope.displayName, "Open")
        XCTAssertEqual(
            RefundFilterScope.allCases,
            [.active, .overdue, .refunded, .all]
        )
    }

    @MainActor
    func testScopeAndSearchNarrowTheResults() {
        let matching = refund(
            expected: DomainTestSupport.date(2026, 8, 10),
            retailer: "Everlane"
        )
        let other = refund(
            expected: DomainTestSupport.date(2026, 8, 12),
            retailer: "Wayfair"
        )

        let viewModel = RefundListViewModel()
        viewModel.selectedScope = .active
        viewModel.searchText = "everlane"

        let results = viewModel.results(
            from: [matching, other],
            now: DomainTestSupport.date(2026, 8, 5)
        )

        XCTAssertEqual(results.map(\.id), [matching.id])
    }

    @MainActor
    func testSortDirectionAppliesToTheResults() {
        let earlier = refund(expected: DomainTestSupport.date(2026, 8, 10))
        let later = refund(expected: DomainTestSupport.date(2026, 8, 20))

        let viewModel = RefundListViewModel()
        viewModel.selectedScope = .all
        viewModel.sortDirection = .descending

        let results = viewModel.results(
            from: [earlier, later],
            now: DomainTestSupport.date(2026, 8, 5)
        )

        XCTAssertEqual(results.map(\.id), [later.id, earlier.id])
    }
}
