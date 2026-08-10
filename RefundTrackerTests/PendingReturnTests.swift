import XCTest
@testable import RefundTracker

/// Returns you still have to post: the tracked date is a deadline rather than
/// a record, and shipping it later re-anchors everything to the real date.
final class PendingReturnTests: XCTestCase {
    private let calendar = DomainTestSupport.calendar

    // MARK: - Model

    func testAwaitingShipmentUntilItActuallyShips() {
        let refund = pendingRefund(shipBy: DomainTestSupport.date(2026, 8, 20))

        XCTAssertTrue(refund.isAwaitingShipment)

        refund.markShipped(on: DomainTestSupport.date(2026, 8, 12))

        XCTAssertFalse(refund.isAwaitingShipment)
        XCTAssertEqual(refund.status, .shipped)
    }

    func testShippingClearsTheDeadlineAndReanchorsTheExpectedDate() {
        let refund = pendingRefund(shipBy: DomainTestSupport.date(2026, 8, 20))
        let shippedOn = DomainTestSupport.date(2026, 8, 12)
        let reanchored = BusinessDayCalculator.addingBusinessDays(
            5,
            to: shippedOn,
            calendar: calendar
        )

        refund.markShipped(on: shippedOn, expectedRefundDate: reanchored)

        XCTAssertEqual(refund.shippedDate, shippedOn)
        XCTAssertEqual(refund.expectedRefundDate, reanchored)
        XCTAssertNil(
            refund.shipByDate,
            "The deadline is spent once the parcel is gone"
        )
    }

    func testShipmentIsOverdueOnlyAfterTheDeadlinePasses() {
        let refund = pendingRefund(shipBy: DomainTestSupport.date(2026, 8, 20))

        XCTAssertFalse(
            refund.isShipmentOverdue(
                on: DomainTestSupport.date(2026, 8, 20),
                calendar: calendar
            ),
            "The deadline day itself is still on time"
        )
        XCTAssertTrue(
            refund.isShipmentOverdue(
                on: DomainTestSupport.date(2026, 8, 21),
                calendar: calendar
            )
        )
    }

    func testShippedReturnIsNeverShipmentOverdue() {
        let refund = pendingRefund(shipBy: DomainTestSupport.date(2026, 8, 20))
        refund.markShipped(on: DomainTestSupport.date(2026, 8, 12))

        XCTAssertFalse(
            refund.isShipmentOverdue(
                on: DomainTestSupport.date(2026, 9, 30),
                calendar: calendar
            )
        )
    }

    func testUnsentReturnIsNotCalledOverdueOnTheRefund() {
        // The retailer can't be late refunding something it hasn't received.
        // Surfacing this as `.overdue` would send the user chasing the shop
        // instead of the post office.
        let refund = pendingRefund(shipBy: DomainTestSupport.date(2026, 8, 20))
        refund.expectedRefundDate = DomainTestSupport.date(2026, 8, 25)

        let wellPastBothDates = DomainTestSupport.date(2026, 9, 30)
        XCTAssertFalse(
            refund.isOverdue(on: wellPastBothDates, calendar: calendar)
        )
        XCTAssertEqual(
            refund.effectiveStatus(on: wellPastBothDates, calendar: calendar),
            .preparingReturn
        )
        XCTAssertTrue(
            refund.isShipmentOverdue(on: wellPastBothDates, calendar: calendar),
            "It is the shipment that is late, and that must still show"
        )
    }

    func testShippedReturnStillGoesOverdueNormally() {
        let refund = pendingRefund(shipBy: DomainTestSupport.date(2026, 8, 20))
        refund.markShipped(
            on: DomainTestSupport.date(2026, 8, 12),
            expectedRefundDate: DomainTestSupport.date(2026, 8, 19)
        )

        XCTAssertTrue(
            refund.isOverdue(
                on: DomainTestSupport.date(2026, 8, 25),
                calendar: calendar
            )
        )
    }

    // MARK: - Creating one from the form

    @MainActor
    func testSavingAPendingReturnStoresADeadlineAndNoShipDate() {
        let now = DomainTestSupport.date(2026, 8, 7, hour: 15)
        let today = calendar.startOfDay(for: now)
        // The form normalises whatever the picker hands it to a whole day.
        let deadline = calendar.startOfDay(for: DomainTestSupport.date(2026, 8, 20))
        let viewModel = RefundFormViewModel(
            defaultExpectedBusinessDays: 5,
            defaultCurrencyCode: "USD",
            calendar: calendar,
            now: now
        )
        viewModel.retailerName = "Patagonia"
        viewModel.amountText = "120"
        viewModel.hasShipped = false
        viewModel.setTrackedDate(deadline)

        let refund = Refund()
        viewModel.apply(to: refund)

        XCTAssertEqual(refund.status, .preparingReturn)
        XCTAssertEqual(refund.shipByDate, deadline)
        XCTAssertNil(refund.shippedDate)
        XCTAssertEqual(
            refund.returnDate,
            today,
            "The return was started today; only the deadline is in the future"
        )
        XCTAssertEqual(
            refund.expectedRefundDate,
            BusinessDayCalculator.addingBusinessDays(
                5,
                to: deadline,
                calendar: calendar
            ),
            "The refund is projected from the deadline until it really ships"
        )
    }

    @MainActor
    func testPendingModeAcceptsFutureDatesAndShippedModeDoesNot() {
        let now = DomainTestSupport.date(2026, 8, 7)
        let viewModel = RefundFormViewModel(calendar: calendar, now: now)

        XCTAssertEqual(viewModel.trackedDateTitle, "Shipped date")
        XCTAssertFalse(viewModel.trackedDateRange.contains(
            DomainTestSupport.date(2026, 8, 20)
        ))

        viewModel.hasShipped = false

        XCTAssertEqual(viewModel.trackedDateTitle, "Send by")
        XCTAssertTrue(viewModel.trackedDateRange.contains(
            DomainTestSupport.date(2026, 8, 20)
        ))
    }

    @MainActor
    func testSwitchingBackToShippedPullsAFutureDeadlineIntoThePast() {
        let now = DomainTestSupport.date(2026, 8, 7)
        let viewModel = RefundFormViewModel(calendar: calendar, now: now)
        viewModel.hasShipped = false
        viewModel.setTrackedDate(DomainTestSupport.date(2026, 8, 20))

        viewModel.hasShipped = true

        XCTAssertLessThanOrEqual(
            viewModel.returnDate,
            now,
            "You cannot have shipped something on a future date"
        )
    }

    @MainActor
    func testEditingAPendingReturnKeepsItPending() {
        let refund = pendingRefund(shipBy: DomainTestSupport.date(2026, 8, 20))
        let viewModel = RefundFormViewModel(
            refund: refund,
            calendar: calendar,
            now: DomainTestSupport.date(2026, 8, 10)
        )

        XCTAssertEqual(viewModel.trackedDateKind, .shipBy)
        XCTAssertEqual(viewModel.trackedDateTitle, "Send by")

        let newDeadline = calendar.startOfDay(
            for: DomainTestSupport.date(2026, 8, 25)
        )
        viewModel.setTrackedDate(newDeadline)
        viewModel.apply(to: refund)

        XCTAssertEqual(refund.shipByDate, newDeadline)
        XCTAssertNil(refund.shippedDate)
        XCTAssertEqual(refund.status, .preparingReturn)
    }

    // MARK: - Helpers

    private func pendingRefund(shipBy: Date) -> Refund {
        Refund(
            retailerName: "Patagonia",
            itemName: "Down Sweater Hoody",
            refundAmount: 120,
            currencyCode: "USD",
            returnDate: DomainTestSupport.date(2026, 8, 7),
            shippedDate: nil,
            shipByDate: shipBy,
            expectedRefundDate: DomainTestSupport.date(2026, 8, 27),
            status: .preparingReturn
        )
    }
}
