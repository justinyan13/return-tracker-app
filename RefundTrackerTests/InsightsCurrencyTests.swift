import XCTest
@testable import RefundTracker

final class InsightsCurrencyTests: XCTestCase {
    private let now = DomainTestSupport.date(2026, 8, 5)

    private func refund(
        currencyCode: String,
        amount: Decimal,
        retailer: String = "Merchant",
        status: RefundStatus = .shipped,
        actualDate: Date? = nil
    ) -> Refund {
        Refund(
            retailerName: retailer,
            itemName: "Item",
            refundAmount: amount,
            currencyCode: currencyCode,
            returnDate: DomainTestSupport.date(2026, 8, 1),
            expectedRefundDate: DomainTestSupport.date(2026, 8, 20),
            actualRefundDate: actualDate,
            status: status
        )
    }

    @MainActor
    func testPreferredCurrencyIsUsedWhenCompletedRecordsExist() {
        let viewModel = InsightsViewModel()
        let refunds = [
            refund(currencyCode: "USD", amount: 10, status: .refunded),
            refund(currencyCode: "EUR", amount: 20, status: .refunded)
        ]

        XCTAssertEqual(
            viewModel.completedCurrencyCode(for: refunds, preferred: "eur"),
            "EUR"
        )
    }

    @MainActor
    func testUnrepresentedPreferredCurrencyFallsBackToAvailableRecords() {
        let viewModel = InsightsViewModel()
        let refunds = [
            refund(currencyCode: "usd", amount: 10, status: .refunded),
            refund(currencyCode: "USD", amount: 20, status: .refunded)
        ]

        XCTAssertEqual(
            viewModel.completedCurrencyCode(for: refunds, preferred: "GBP"),
            "USD"
        )
    }

    @MainActor
    func testCompletedCurrencyIgnoresOutstandingOnlyCurrencies() {
        let viewModel = InsightsViewModel()
        let refunds = [
            refund(currencyCode: "USD", amount: 10, status: .shipped),
            refund(currencyCode: "EUR", amount: 20, status: .refunded)
        ]

        XCTAssertEqual(
            viewModel.completedCurrencyCode(for: refunds, preferred: "USD"),
            "EUR"
        )
    }

    @MainActor
    func testEmptyRecordsKeepThePreferredCurrency() {
        let viewModel = InsightsViewModel()

        XCTAssertEqual(
            viewModel.completedCurrencyCode(for: [], preferred: "gbp"),
            "GBP"
        )
    }

    @MainActor
    func testOutstandingMetricsUseTheViewModelsReferenceDate() {
        let viewModel = InsightsViewModel()
        let refund = Refund(
            retailerName: "Merchant",
            itemName: "Item",
            refundAmount: 40,
            currencyCode: "USD",
            returnDate: DomainTestSupport.date(2026, 8, 1),
            expectedRefundDate: DomainTestSupport.date(2026, 8, 6),
            status: .shipped
        )

        viewModel.refresh(at: now)
        XCTAssertEqual(
            viewModel.outstandingMetrics(
                for: [refund],
                calendar: DomainTestSupport.calendar
            ).overdueRefundCount,
            0
        )

        viewModel.refresh(at: DomainTestSupport.date(2026, 8, 7))
        XCTAssertEqual(
            viewModel.outstandingMetrics(
                for: [refund],
                calendar: DomainTestSupport.calendar
            ).overdueRefundCount,
            1
        )
    }

    func testCalculatorMatchesCurrencyCodesCaseInsensitively() {
        let metrics = InsightsCalculator.calculate(
            refunds: [
                refund(currencyCode: "usd", amount: 10),
                refund(currencyCode: "USD", amount: 20),
                refund(currencyCode: "EUR", amount: 99)
            ],
            currencyCode: "USD",
            now: now,
            calendar: DomainTestSupport.calendar
        )

        XCTAssertEqual(metrics.totalRefundsPending, 30)
        XCTAssertEqual(metrics.completedRefundCount, 0)
        XCTAssertEqual(metrics.completedRetailerCount, 0)
        XCTAssertEqual(metrics.currencyCode, "USD")
    }

    func testCalculatorCountsCompletedRefundsAndMerchants() {
        let metrics = InsightsCalculator.calculate(
            refunds: [
                refund(
                    currencyCode: "USD",
                    amount: 10,
                    retailer: "Merchant A",
                    status: .refunded,
                    actualDate: DomainTestSupport.date(2026, 8, 4)
                ),
                refund(
                    currencyCode: "USD",
                    amount: 20,
                    retailer: "Merchant A",
                    status: .refunded,
                    actualDate: DomainTestSupport.date(2026, 8, 4)
                ),
                refund(
                    currencyCode: "USD",
                    amount: 30,
                    retailer: "Merchant B",
                    status: .refunded,
                    actualDate: DomainTestSupport.date(2026, 8, 4)
                )
            ],
            currencyCode: "USD",
            now: now,
            calendar: DomainTestSupport.calendar
        )

        XCTAssertEqual(metrics.totalRefundsReceived, 60)
        XCTAssertEqual(metrics.completedRefundCount, 3)
        XCTAssertEqual(metrics.completedRetailerCount, 2)
    }
}
