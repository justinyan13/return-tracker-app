import XCTest
@testable import RefundTracker

final class NotificationPlannerTests: XCTestCase {
    private let calendar = DomainTestSupport.calendar
    private let now = DomainTestSupport.date(2026, 8, 1)

    func testPlanIncludesFourExpectedReminderDates() {
        let refund = makeRefund(
            expectedDate: DomainTestSupport.date(2026, 8, 15)
        )
        let preferences = RefundNotificationPreferences(
            isEnabled: true,
            daysBeforeExpectedDate: 3,
            remindOnExpectedDate: true,
            remindWhenOverdue: true,
            overdueFollowUpDays: 3
        )

        let plan = NotificationPlanner.plan(
            for: refund,
            preferences: preferences,
            now: now,
            calendar: calendar
        )

        XCTAssertEqual(
            plan.map(\.kind),
            [.beforeExpectedDate, .expectedDate, .overdue, .overdueFollowUp]
        )
        XCTAssertEqual(plan[0].fireDate, DomainTestSupport.date(2026, 8, 12, hour: 9))
        XCTAssertEqual(plan[1].fireDate, DomainTestSupport.date(2026, 8, 15, hour: 9))
        XCTAssertEqual(plan[2].fireDate, DomainTestSupport.date(2026, 8, 16, hour: 9))
        XCTAssertEqual(plan[3].fireDate, DomainTestSupport.date(2026, 8, 19, hour: 9))
        XCTAssertEqual(Set(plan.map(\.identifier)).count, 4)
    }

    func testPastReminderDatesAreNotScheduled() {
        let refund = makeRefund(
            expectedDate: DomainTestSupport.date(2026, 8, 15)
        )
        let preferences = RefundNotificationPreferences(
            isEnabled: true,
            daysBeforeExpectedDate: 3,
            remindOnExpectedDate: true,
            remindWhenOverdue: true,
            overdueFollowUpDays: 3
        )

        let plan = NotificationPlanner.plan(
            for: refund,
            preferences: preferences,
            now: DomainTestSupport.date(2026, 8, 15, hour: 12),
            calendar: calendar
        )

        XCTAssertEqual(plan.map(\.kind), [.overdue, .overdueFollowUp])
    }

    func testResolvedOrManuallyOverriddenRefundsHaveNoPlan() {
        let preferences = RefundNotificationPreferences(
            isEnabled: true,
            daysBeforeExpectedDate: 3,
            remindOnExpectedDate: true,
            remindWhenOverdue: true,
            overdueFollowUpDays: 3
        )

        for status in [RefundStatus.refunded, .cancelled, .disputed] {
            let refund = makeRefund(
                expectedDate: DomainTestSupport.date(2026, 8, 15),
                status: status
            )
            XCTAssertTrue(
                NotificationPlanner.plan(
                    for: refund,
                    preferences: preferences,
                    now: now,
                    calendar: calendar
                ).isEmpty
            )
        }
    }

    func testDisabledPreferencesHaveNoPlan() {
        let refund = makeRefund(
            expectedDate: DomainTestSupport.date(2026, 8, 15)
        )
        XCTAssertTrue(
            NotificationPlanner.plan(
                for: refund,
                preferences: .defaults,
                now: now,
                calendar: calendar
            ).isEmpty
        )
    }

    func testGlobalPlanOrdersAllRefundsChronologically() {
        let laterRefund = makeRefund(
            expectedDate: DomainTestSupport.date(2026, 8, 20)
        )
        let soonerRefund = makeRefund(
            expectedDate: DomainTestSupport.date(2026, 8, 10)
        )
        let preferences = enabledPreferences()

        let plan = NotificationPlanner.plan(
            for: [laterRefund, soonerRefund],
            preferences: preferences,
            now: now,
            calendar: calendar
        )

        XCTAssertEqual(plan.count, 8)
        XCTAssertEqual(
            plan.map(\.fireDate),
            plan.map(\.fireDate).sorted()
        )
        XCTAssertEqual(plan.first?.refundID, soonerRefund.id)
        XCTAssertEqual(plan.last?.refundID, laterRefund.id)
    }

    func testGlobalPlanCapKeepsNearestRemindersAndStableIdentifiers() {
        let soonerRefund = makeRefund(
            expectedDate: DomainTestSupport.date(2026, 8, 15)
        )
        let laterRefund = makeRefund(
            expectedDate: DomainTestSupport.date(2026, 8, 25)
        )
        let preferences = enabledPreferences()

        let plan = NotificationPlanner.plan(
            for: [laterRefund, soonerRefund],
            preferences: preferences,
            now: now,
            calendar: calendar,
            maximumCount: 3
        )

        XCTAssertEqual(
            plan.map(\.kind),
            [.beforeExpectedDate, .expectedDate, .overdue]
        )
        XCTAssertTrue(plan.allSatisfy { $0.refundID == soonerRefund.id })
        XCTAssertEqual(
            plan.map(\.identifier),
            plan.map {
                NotificationPlanner.identifier(
                    for: $0.refundID,
                    kind: $0.kind
                )
            }
        )
    }

    func testGlobalPlanWithNoCapacityIsEmpty() {
        let refund = makeRefund(
            expectedDate: DomainTestSupport.date(2026, 8, 15)
        )

        XCTAssertTrue(
            NotificationPlanner.plan(
                for: [refund],
                preferences: enabledPreferences(),
                now: now,
                calendar: calendar,
                maximumCount: 0
            ).isEmpty
        )
    }

    func testGlobalPlanDefaultCapReservesSystemCapacity() {
        let refunds = (10..<30).map { offset in
            makeRefund(
                expectedDate: DomainTestSupport.addingDays(offset, to: now)
            )
        }

        let plan = NotificationPlanner.plan(
            for: refunds,
            preferences: enabledPreferences(),
            now: now,
            calendar: calendar
        )

        XCTAssertEqual(
            NotificationPlanner.maximumScheduledRefundNotifications,
            NotificationPlanner.systemPendingRequestLimit -
                NotificationPlanner.reservedPendingRequestSlots
        )
        XCTAssertEqual(
            plan.count,
            NotificationPlanner.maximumScheduledRefundNotifications
        )
        XCTAssertEqual(
            plan.map(\.fireDate),
            plan.map(\.fireDate).sorted()
        )
    }

    private func enabledPreferences() -> RefundNotificationPreferences {
        RefundNotificationPreferences(
            isEnabled: true,
            daysBeforeExpectedDate: 3,
            remindOnExpectedDate: true,
            remindWhenOverdue: true,
            overdueFollowUpDays: 3
        )
    }

    private func makeRefund(
        expectedDate: Date,
        status: RefundStatus = .refundPending
    ) -> Refund {
        Refund(
            retailerName: "Store",
            itemName: "Jacket",
            refundAmount: 100,
            currencyCode: "USD",
            returnDate: DomainTestSupport.date(2026, 8, 1),
            expectedRefundDate: expectedDate,
            status: status
        )
    }
}
