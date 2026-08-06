import XCTest
import SwiftData
@testable import RefundTracker

final class DomainRefundStatusTests: XCTestCase {
    private let calendar = DomainTestSupport.calendar

    func testExpectedDateIsNotOverdueUntilFollowingCalendarDay() {
        let expectedDate = DomainTestSupport.date(2026, 8, 6, hour: 8)
        let refund = makeRefund(expectedDate: expectedDate)

        XCTAssertFalse(
            refund.isOverdue(
                on: DomainTestSupport.date(2026, 8, 6, hour: 23),
                calendar: calendar
            )
        )
        XCTAssertEqual(
            refund.effectiveStatus(
                on: DomainTestSupport.date(2026, 8, 6, hour: 23),
                calendar: calendar
            ),
            .refundPending
        )
    }

    func testOpenRefundBecomesOverdueOnNextDay() {
        let refund = makeRefund(
            expectedDate: DomainTestSupport.date(2026, 8, 6)
        )

        XCTAssertTrue(
            refund.isOverdue(
                on: DomainTestSupport.date(2026, 8, 7, hour: 0),
                calendar: calendar
            )
        )
        XCTAssertEqual(
            refund.effectiveStatus(
                on: DomainTestSupport.date(2026, 8, 7),
                calendar: calendar
            ),
            .overdue
        )
    }

    func testDisputedAndCancelledStatusesOverrideAutomaticOverdue() {
        let expectedDate = DomainTestSupport.date(2026, 7, 1)
        let comparisonDate = DomainTestSupport.date(2026, 8, 6)

        let disputed = makeRefund(expectedDate: expectedDate, status: .disputed)
        XCTAssertFalse(disputed.isOverdue(on: comparisonDate, calendar: calendar))
        XCTAssertEqual(
            disputed.effectiveStatus(on: comparisonDate, calendar: calendar),
            .disputed
        )

        let cancelled = makeRefund(expectedDate: expectedDate, status: .cancelled)
        XCTAssertFalse(cancelled.isOverdue(on: comparisonDate, calendar: calendar))
        XCTAssertEqual(
            cancelled.effectiveStatus(on: comparisonDate, calendar: calendar),
            .cancelled
        )
    }

    func testActualRefundDateMakesRecordRefunded() {
        let refund = makeRefund(
            expectedDate: DomainTestSupport.date(2026, 7, 1),
            actualDate: DomainTestSupport.date(2026, 7, 10)
        )

        XCTAssertEqual(
            refund.effectiveStatus(
                on: DomainTestSupport.date(2026, 8, 6),
                calendar: calendar
            ),
            .refunded
        )
        XCTAssertFalse(
            refund.isOverdue(
                on: DomainTestSupport.date(2026, 8, 6),
                calendar: calendar
            )
        )
    }

    func testWorkflowMethodsCaptureEventDates() {
        let refund = makeRefund(expectedDate: DomainTestSupport.date(2026, 8, 20))
        let shipped = DomainTestSupport.date(2026, 8, 7)
        let delivered = DomainTestSupport.date(2026, 8, 10)
        let received = DomainTestSupport.date(2026, 8, 15)

        refund.markShipped(on: shipped)
        XCTAssertEqual(refund.status, .shipped)
        XCTAssertEqual(refund.shippedDate, shipped)

        refund.markDelivered(on: delivered)
        XCTAssertEqual(refund.status, .deliveredToRetailer)
        XCTAssertEqual(refund.retailerReceivedDate, delivered)

        refund.markRefunded(on: received)
        XCTAssertEqual(refund.status, .refunded)
        XCTAssertEqual(refund.actualRefundDate, received)
        XCTAssertEqual(refund.lastUpdatedDate, received)
    }

    @MainActor
    func testStatusAndMethodRoundTripThroughSwiftData() throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Refund.self,
            RefundAttachment.self,
            configurations: configuration
        )
        let context = ModelContext(container)
        let refund = makeRefund(
            expectedDate: DomainTestSupport.date(2026, 8, 20),
            status: .disputed
        )
        refund.refundMethod = .storeCredit
        context.insert(refund)
        try context.save()

        let fetched = try XCTUnwrap(context.fetch(FetchDescriptor<Refund>()).first)
        XCTAssertEqual(fetched.status, .disputed)
        XCTAssertEqual(fetched.refundMethod, .storeCredit)
    }

    private func makeRefund(
        expectedDate: Date,
        status: RefundStatus = .refundPending,
        actualDate: Date? = nil
    ) -> Refund {
        Refund(
            retailerName: "Test Shop",
            itemName: "Test Item",
            refundAmount: 42,
            currencyCode: "USD",
            returnDate: DomainTestSupport.date(2026, 7, 20),
            expectedRefundDate: expectedDate,
            actualRefundDate: actualDate,
            status: status
        )
    }
}
