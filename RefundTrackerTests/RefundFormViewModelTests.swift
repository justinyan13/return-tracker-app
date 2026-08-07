import XCTest
@testable import RefundTracker

final class RefundFormViewModelTests: XCTestCase {
    private let calendar = DomainTestSupport.calendar

    @MainActor
    func testMerchantAndAmountAreSufficientWithoutItemInput() {
        let viewModel = RefundFormViewModel(
            defaultCurrencyCode: "USD",
            calendar: calendar,
            now: DomainTestSupport.date(2026, 8, 6)
        )

        XCTAssertFalse(viewModel.isValid)

        viewModel.retailerName = "  Everlane  "
        viewModel.amountText = "84.50"

        XCTAssertTrue(viewModel.isValid)
        XCTAssertTrue(viewModel.validationMessages.isEmpty)
        XCTAssertEqual(viewModel.amount, Decimal(string: "84.50"))
    }

    @MainActor
    func testNewRecordUsesSettingsAndDerivedShipmentDefaults() {
        let now = DomainTestSupport.date(2026, 8, 7, hour: 15)
        let shippedDay = calendar.startOfDay(for: now)
        let viewModel = RefundFormViewModel(
            defaultExpectedBusinessDays: 10,
            defaultCurrencyCode: "USD",
            calendar: calendar,
            now: now
        )
        viewModel.applySettings(
            expectedBusinessDays: 3,
            defaultCurrencyCode: "cad"
        )
        viewModel.retailerName = "Outdoor Voices"
        viewModel.amountText = "125.25"

        let refund = Refund()
        viewModel.apply(to: refund)

        let expectedDate = BusinessDayCalculator.addingBusinessDays(
            3,
            to: shippedDay,
            calendar: calendar
        )
        XCTAssertEqual(refund.retailerName, "Outdoor Voices")
        XCTAssertEqual(refund.itemName, "Return")
        XCTAssertEqual(refund.refundAmount, Decimal(string: "125.25"))
        XCTAssertEqual(refund.currencyCode, "CAD")
        XCTAssertEqual(refund.status, .shipped)
        XCTAssertEqual(refund.returnDate, shippedDay)
        XCTAssertEqual(refund.shippedDate, shippedDay)
        XCTAssertEqual(refund.expectedRefundDate, expectedDate)
    }

    @MainActor
    func testEditingPreservesHiddenLegacyFieldsAndSavedCurrency() {
        let purchaseDate = DomainTestSupport.date(2026, 7, 20)
        let returnDate = DomainTestSupport.date(2026, 8, 1)
        let shippedDate = DomainTestSupport.date(2026, 8, 2)
        let deliveredDate = DomainTestSupport.date(2026, 8, 5)
        let expectedDate = DomainTestSupport.date(2026, 8, 20)
        let actualDate = DomainTestSupport.date(2026, 8, 12)
        let refund = Refund(
            retailerName: "Legacy Shop",
            itemName: "Legacy jacket",
            orderNumber: "ORDER-42",
            refundAmount: 90,
            currencyCode: "EUR",
            purchaseDate: purchaseDate,
            returnDate: returnDate,
            shippedDate: shippedDate,
            retailerReceivedDate: deliveredDate,
            expectedRefundDate: expectedDate,
            actualRefundDate: actualDate,
            refundMethod: .giftCard,
            status: .refunded,
            trackingNumber: "TRACK-42",
            returnCarrier: "UPS",
            notes: "Keep this history",
            isSampleData: true
        )
        let viewModel = RefundFormViewModel(
            refund: refund,
            calendar: calendar,
            now: DomainTestSupport.date(2026, 8, 25)
        )

        viewModel.applySettings(
            expectedBusinessDays: 5,
            defaultCurrencyCode: "USD"
        )
        viewModel.retailerName = "Legacy Shop Updated"
        viewModel.amountText = "95"
        viewModel.apply(to: refund)

        XCTAssertEqual(viewModel.currencyCode, "EUR")
        XCTAssertEqual(refund.currencyCode, "EUR")
        XCTAssertEqual(refund.retailerName, "Legacy Shop Updated")
        XCTAssertEqual(refund.refundAmount, 95)
        XCTAssertEqual(refund.itemName, "Legacy jacket")
        XCTAssertEqual(refund.orderNumber, "ORDER-42")
        XCTAssertEqual(refund.purchaseDate, purchaseDate)
        XCTAssertEqual(refund.returnDate, returnDate)
        XCTAssertEqual(refund.shippedDate, shippedDate)
        XCTAssertEqual(refund.retailerReceivedDate, deliveredDate)
        XCTAssertEqual(refund.expectedRefundDate, expectedDate)
        XCTAssertEqual(refund.actualRefundDate, actualDate)
        XCTAssertEqual(refund.refundMethod, .giftCard)
        XCTAssertEqual(refund.status, .refunded)
        XCTAssertEqual(refund.trackingNumber, "TRACK-42")
        XCTAssertEqual(refund.returnCarrier, "UPS")
        XCTAssertEqual(refund.notes, "Keep this history")
        XCTAssertTrue(refund.isSampleData)
    }

    @MainActor
    func testItemNameIsCapturedAndTrimmedOnCreate() {
        let viewModel = RefundFormViewModel(
            defaultCurrencyCode: "USD",
            calendar: calendar,
            now: DomainTestSupport.date(2026, 8, 7)
        )
        viewModel.retailerName = "Everlane"
        viewModel.itemName = "  ReNew Transit Backpack  "
        viewModel.amountText = "95.00"

        // Item name stays optional, so it must not block saving.
        XCTAssertTrue(viewModel.isValid)

        let refund = Refund()
        viewModel.apply(to: refund)

        XCTAssertEqual(refund.retailerName, "Everlane")
        XCTAssertEqual(refund.itemName, "ReNew Transit Backpack")
        XCTAssertEqual(refund.userFacingItemName, "ReNew Transit Backpack")
    }

    @MainActor
    func testBlankItemNameFallsBackToThePlaceholder() {
        let viewModel = RefundFormViewModel(
            defaultCurrencyCode: "USD",
            calendar: calendar,
            now: DomainTestSupport.date(2026, 8, 7)
        )
        viewModel.retailerName = "Everlane"
        viewModel.itemName = "   "
        viewModel.amountText = "95.00"

        let refund = Refund()
        viewModel.apply(to: refund)

        XCTAssertEqual(refund.itemName, Refund.simplifiedItemPlaceholder)
        XCTAssertNil(refund.userFacingItemName)
    }

    @MainActor
    func testEditingSeedsTheSavedItemNameAndCanClearIt() {
        let refund = Refund(
            retailerName: "Nordstrom",
            itemName: "Leather ankle boots",
            refundAmount: 189.95,
            currencyCode: "USD",
            returnDate: DomainTestSupport.date(2026, 8, 1),
            expectedRefundDate: DomainTestSupport.date(2026, 8, 18),
            status: .shipped
        )
        let viewModel = RefundFormViewModel(
            refund: refund,
            calendar: calendar,
            now: DomainTestSupport.date(2026, 8, 6)
        )

        XCTAssertEqual(viewModel.itemName, "Leather ankle boots")

        viewModel.itemName = "Suede ankle boots"
        viewModel.apply(to: refund)
        XCTAssertEqual(refund.itemName, "Suede ankle boots")

        viewModel.itemName = ""
        viewModel.apply(to: refund)
        XCTAssertEqual(refund.itemName, Refund.simplifiedItemPlaceholder)
    }

    @MainActor
    func testEditingARecordSavedWithoutAnItemShowsAnEmptyField() {
        let refund = Refund(
            retailerName: "Everlane",
            itemName: Refund.simplifiedItemPlaceholder,
            refundAmount: 95,
            currencyCode: "USD",
            returnDate: DomainTestSupport.date(2026, 8, 1),
            expectedRefundDate: DomainTestSupport.date(2026, 8, 18),
            status: .shipped
        )
        let viewModel = RefundFormViewModel(
            refund: refund,
            calendar: calendar,
            now: DomainTestSupport.date(2026, 8, 6)
        )

        // The placeholder is storage, not something the user typed.
        XCTAssertEqual(viewModel.itemName, "")
    }

    @MainActor
    func testEditingUnshippedLegacyReturnDoesNotInventShipment() {
        let originalReturnDate = DomainTestSupport.date(2026, 8, 1)
        let updatedReturnDate = DomainTestSupport.date(2026, 8, 3)
        let refund = Refund(
            retailerName: "Legacy Shop",
            itemName: "Jacket",
            refundAmount: 75,
            currencyCode: "USD",
            returnDate: originalReturnDate,
            expectedRefundDate: DomainTestSupport.date(2026, 8, 18),
            status: .preparingReturn
        )
        let viewModel = RefundFormViewModel(
            refund: refund,
            calendar: calendar,
            now: DomainTestSupport.date(2026, 8, 6)
        )

        XCTAssertFalse(viewModel.tracksShipmentDate)
        XCTAssertEqual(viewModel.trackedDateTitle, "Return date")

        viewModel.setTrackedDate(updatedReturnDate)
        viewModel.apply(to: refund)

        XCTAssertTrue(
            calendar.isDate(
                refund.returnDate,
                inSameDayAs: updatedReturnDate
            )
        )
        XCTAssertNil(refund.shippedDate)
        XCTAssertEqual(refund.status, .preparingReturn)
    }
}
