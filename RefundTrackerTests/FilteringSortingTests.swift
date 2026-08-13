import XCTest
@testable import RefundTracker

final class FilteringSortingTests: XCTestCase {
    private let calendar = DomainTestSupport.calendar
    private let now = DomainTestSupport.date(2026, 8, 6)

    func testScopeAndSearchFilters() {
        let overdue = makeRefund(
            retailer: "Acme",
            item: "Blue jacket",
            amount: 75,
            expectedOffset: -2,
            method: .originalPaymentMethod
        )
        let disputed = makeRefund(
            retailer: "Other",
            item: "Headphones",
            amount: 200,
            expectedOffset: -5,
            method: .giftCard,
            status: .disputed
        )
        let refunded = makeRefund(
            retailer: "Acme",
            item: "Running shoes",
            amount: 120,
            expectedOffset: -4,
            method: .giftCard,
            status: .refunded,
            actualDate: DomainTestSupport.addingDays(-1, to: now)
        )
        let refunds = [overdue, disputed, refunded]

        XCTAssertEqual(
            RefundQueryService.filter(
                refunds,
                using: RefundFilter(scope: .overdue),
                now: now,
                calendar: calendar
            ).map(\.id),
            [overdue.id]
        )
        XCTAssertEqual(
            RefundQueryService.filter(
                refunds,
                using: RefundFilter(scope: .refunded),
                now: now,
                calendar: calendar
            ).map(\.id),
            [refunded.id]
        )
        XCTAssertEqual(
            RefundQueryService.filter(
                refunds,
                using: RefundFilter(searchText: "jacket"),
                now: now,
                calendar: calendar
            ).map(\.id),
            [overdue.id]
        )
        XCTAssertEqual(
            Set(
                RefundQueryService.filter(
                    refunds,
                    using: .all,
                    now: now,
                    calendar: calendar
                ).map(\.id)
            ),
            Set([overdue.id, disputed.id, refunded.id])
        )
    }

    func testOpenScopeIncludesEveryUnresolvedStatusOnly() {
        let upcoming = makeRefund(
            retailer: "Upcoming",
            item: "Item",
            amount: 10,
            expectedOffset: 4,
            status: .refundPending
        )
        let overdue = makeRefund(
            retailer: "Overdue",
            item: "Item",
            amount: 20,
            expectedOffset: -2,
            status: .refundPending
        )
        let disputed = makeRefund(
            retailer: "Disputed",
            item: "Item",
            amount: 30,
            expectedOffset: -3,
            status: .disputed
        )
        let refunded = makeRefund(
            retailer: "Refunded",
            item: "Item",
            amount: 40,
            expectedOffset: -4,
            status: .refunded,
            actualDate: DomainTestSupport.addingDays(-1, to: now)
        )
        let cancelled = makeRefund(
            retailer: "Cancelled",
            item: "Item",
            amount: 50,
            expectedOffset: 5,
            status: .cancelled
        )

        let results = RefundQueryService.filter(
            [upcoming, overdue, disputed, refunded, cancelled],
            using: RefundFilter(scope: .active),
            now: now,
            calendar: calendar
        )

        XCTAssertEqual(
            Set(results.map(\.id)),
            Set([upcoming.id, overdue.id, disputed.id])
        )
    }

    func testSortingByAmountRetailerAndStatus() {
        let lower = makeRefund(
            retailer: "Zulu",
            item: "Item",
            amount: 10,
            expectedOffset: 4
        )
        let higher = makeRefund(
            retailer: "Alpha",
            item: "Item",
            amount: 100,
            expectedOffset: -2
        )

        XCTAssertEqual(
            RefundQueryService.sort(
                [lower, higher],
                by: .refundAmount,
                direction: .descending,
                now: now,
                calendar: calendar
            ).map(\.id),
            [higher.id, lower.id]
        )
        XCTAssertEqual(
            RefundQueryService.sort(
                [lower, higher],
                by: .retailer,
                now: now,
                calendar: calendar
            ).map(\.id),
            [higher.id, lower.id]
        )
        XCTAssertEqual(
            RefundQueryService.sort(
                [lower, higher],
                by: .status,
                now: now,
                calendar: calendar
            ).map(\.id),
            [higher.id, lower.id]
        )
    }

    private func makeRefund(
        retailer: String,
        item: String,
        amount: Decimal,
        expectedOffset: Int,
        returnOffset: Int = -7,
        method: RefundMethod = .originalPaymentMethod,
        status: RefundStatus = .refundPending,
        actualDate: Date? = nil
    ) -> Refund {
        Refund(
            retailerName: retailer,
            itemName: item,
            refundAmount: amount,
            currencyCode: "USD",
            returnDate: DomainTestSupport.addingDays(returnOffset, to: now),
            expectedRefundDate: DomainTestSupport.addingDays(expectedOffset, to: now),
            actualRefundDate: actualDate,
            refundMethod: method,
            status: status
        )
    }
}
