import XCTest
@testable import RefundTracker

final class InsightsCurrencyTests: XCTestCase {
    private func refund(currencyCode: String, amount: Decimal) -> Refund {
        Refund(
            retailerName: "Merchant",
            itemName: "Item",
            refundAmount: amount,
            currencyCode: currencyCode,
            returnDate: DomainTestSupport.date(2026, 8, 1),
            expectedRefundDate: DomainTestSupport.date(2026, 8, 20),
            status: .shipped
        )
    }

    @MainActor
    func testPreferredCurrencyIsUsedWhenRecordsExist() {
        let viewModel = InsightsViewModel()
        let refunds = [
            refund(currencyCode: "USD", amount: 10),
            refund(currencyCode: "EUR", amount: 20)
        ]

        XCTAssertEqual(
            viewModel.displayCurrencyCode(for: refunds, preferred: "eur"),
            "EUR"
        )
    }

    @MainActor
    func testUnrepresentedPreferredCurrencyFallsBackToAvailableRecords() {
        let viewModel = InsightsViewModel()
        let refunds = [
            refund(currencyCode: "usd", amount: 10),
            refund(currencyCode: "USD", amount: 20)
        ]

        // Without the fallback this renders an all-zero screen.
        XCTAssertEqual(
            viewModel.displayCurrencyCode(for: refunds, preferred: "GBP"),
            "USD"
        )
    }

    @MainActor
    func testEmptyRecordsKeepThePreferredCurrency() {
        let viewModel = InsightsViewModel()

        XCTAssertEqual(
            viewModel.displayCurrencyCode(for: [], preferred: "gbp"),
            "GBP"
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
            now: DomainTestSupport.date(2026, 8, 5),
            calendar: DomainTestSupport.calendar
        )

        XCTAssertEqual(metrics.totalRefundsPending, 30)
        XCTAssertEqual(metrics.currencyCode, "USD")
    }
}
