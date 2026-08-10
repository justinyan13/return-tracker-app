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
    func testInitialScopeIsOpenAndQuickScopesUseRequestedOrder() {
        let viewModel = RefundListViewModel()

        XCTAssertEqual(viewModel.selectedScope, .active)
        XCTAssertEqual(viewModel.selectedScope.displayName, "Open")
        XCTAssertEqual(
            RefundFilterScope.quickScopes,
            [.active, .overdue, .refunded, .all]
        )
    }

    @MainActor
    func testInvertedDateRangeStillMatchesRecords() {
        let inRange = refund(expected: DomainTestSupport.date(2026, 8, 10))
        let outOfRange = refund(expected: DomainTestSupport.date(2026, 9, 20))

        let viewModel = RefundListViewModel()
        viewModel.selectedDateField = .expectedRefundDate
        viewModel.usesExpectedDateRange = true
        // Dragging the filter sheet away skips `normalizeDateRange()`, so the
        // bounds can arrive reversed.
        viewModel.expectedDateStart = DomainTestSupport.date(2026, 8, 31)
        viewModel.expectedDateEnd = DomainTestSupport.date(2026, 8, 1)

        let results = viewModel.results(
            from: [inRange, outOfRange],
            now: DomainTestSupport.date(2026, 8, 5)
        )

        XCTAssertEqual(results.map(\.id), [inRange.id])
    }

    @MainActor
    func testNormalizeDateRangeOrdersTheBounds() {
        let viewModel = RefundListViewModel()
        let early = DomainTestSupport.date(2026, 8, 1)
        let late = DomainTestSupport.date(2026, 8, 31)
        viewModel.expectedDateStart = late
        viewModel.expectedDateEnd = early

        viewModel.normalizeDateRange()

        XCTAssertEqual(viewModel.expectedDateStart, early)
        XCTAssertEqual(viewModel.expectedDateEnd, late)
    }

    @MainActor
    func testDateRangeIsIgnoredWhenTheToggleIsOff() {
        let outOfRange = refund(expected: DomainTestSupport.date(2026, 12, 25))

        let viewModel = RefundListViewModel()
        viewModel.usesExpectedDateRange = false
        viewModel.expectedDateStart = DomainTestSupport.date(2026, 8, 1)
        viewModel.expectedDateEnd = DomainTestSupport.date(2026, 8, 2)

        let results = viewModel.results(
            from: [outOfRange],
            now: DomainTestSupport.date(2026, 8, 5)
        )

        XCTAssertEqual(results.count, 1)
    }

    @MainActor
    func testClearFiltersResetsEveryAdvancedFilter() {
        let viewModel = RefundListViewModel()
        viewModel.selectedScope = .overdue
        viewModel.selectedRetailer = "Everlane"
        viewModel.selectedMethod = .giftCard
        viewModel.usesExpectedDateRange = true

        XCTAssertEqual(viewModel.appliedFilterCount, 4)

        viewModel.clearFilters()

        XCTAssertEqual(viewModel.selectedScope, .all)
        XCTAssertNil(viewModel.selectedRetailer)
        XCTAssertNil(viewModel.selectedMethod)
        XCTAssertFalse(viewModel.usesExpectedDateRange)
        XCTAssertFalse(viewModel.hasAdvancedFilters)
        XCTAssertEqual(viewModel.appliedFilterCount, 0)
    }
}
