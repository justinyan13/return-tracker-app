import XCTest
@testable import RefundTracker

final class DashboardCalculatorTests: XCTestCase {
    private let calendar = DomainTestSupport.calendar
    private let now = DomainTestSupport.date(2026, 8, 6)

    func testDashboardTotalsAndCollections() {
        let upcoming = refund(
            retailer: "Upcoming",
            amount: 100,
            expectedOffset: 3,
            status: .refundPending
        )
        let overdue = refund(
            retailer: "Overdue",
            amount: 50,
            expectedOffset: -2,
            status: .refundPending
        )
        let disputed = refund(
            retailer: "Disputed",
            amount: 40,
            expectedOffset: -4,
            status: .disputed
        )
        let completed = refund(
            retailer: "Completed",
            amount: 25,
            expectedOffset: -6,
            status: .refunded,
            actualDate: DomainTestSupport.date(2026, 8, 2)
        )
        let cancelled = refund(
            retailer: "Cancelled",
            amount: 30,
            expectedOffset: 4,
            status: .cancelled
        )
        let euroPending = Refund(
            retailerName: "Euro Shop",
            itemName: "Item",
            refundAmount: 70,
            currencyCode: "EUR",
            returnDate: DomainTestSupport.addingDays(-2, to: now),
            expectedRefundDate: DomainTestSupport.addingDays(5, to: now),
            status: .refundPending
        )

        let metrics = DashboardCalculator.calculate(
            refunds: [upcoming, overdue, disputed, completed, cancelled, euroPending],
            now: now,
            calendar: calendar,
            headlineCurrencyCode: "USD"
        )

        XCTAssertEqual(metrics.totalAwaitingRefund, 190)
        XCTAssertEqual(metrics.awaitingAmountsByCurrency["USD"], 190)
        XCTAssertEqual(metrics.awaitingAmountsByCurrency["EUR"], 70)
        XCTAssertEqual(metrics.openReturnCount, 4)
        XCTAssertEqual(metrics.overdueRefundCount, 1)
        XCTAssertEqual(metrics.completedThisMonthCount, 1)
        XCTAssertEqual(metrics.completedThisMonthAmount, 25)
        XCTAssertEqual(metrics.attentionRefunds.map(\.retailerName), ["Overdue", "Disputed"])
        XCTAssertEqual(
            metrics.upcomingRefunds.map(\.retailerName),
            ["Upcoming", "Euro Shop"]
        )
    }

    func testEmptyDashboard() {
        let metrics = DashboardCalculator.calculate(
            refunds: [],
            now: now,
            calendar: calendar,
            headlineCurrencyCode: "USD"
        )

        XCTAssertEqual(metrics.totalAwaitingRefund, 0)
        XCTAssertEqual(metrics.openReturnCount, 0)
        XCTAssertTrue(metrics.attentionRefunds.isEmpty)
        XCTAssertTrue(metrics.upcomingRefunds.isEmpty)
    }

    func testRefundedStatusWithoutActualDateUsesLastUpdatedMonth() {
        let completed = Refund(
            retailerName: "Completed",
            itemName: "Item",
            refundAmount: 35,
            currencyCode: "USD",
            returnDate: DomainTestSupport.addingDays(-10, to: now),
            expectedRefundDate: DomainTestSupport.addingDays(-2, to: now),
            status: .refunded,
            lastUpdatedDate: DomainTestSupport.date(2026, 8, 4)
        )

        let metrics = DashboardCalculator.calculate(
            refunds: [completed],
            now: now,
            calendar: calendar,
            headlineCurrencyCode: "USD"
        )

        XCTAssertEqual(metrics.completedThisMonthCount, 1)
        XCTAssertEqual(metrics.completedThisMonthAmount, 35)
    }

    private func refund(
        retailer: String,
        amount: Decimal,
        expectedOffset: Int,
        status: RefundStatus,
        actualDate: Date? = nil
    ) -> Refund {
        Refund(
            retailerName: retailer,
            itemName: "Item",
            refundAmount: amount,
            currencyCode: "USD",
            returnDate: DomainTestSupport.addingDays(-10, to: now),
            expectedRefundDate: DomainTestSupport.addingDays(expectedOffset, to: now),
            actualRefundDate: actualDate,
            status: status
        )
    }
}
