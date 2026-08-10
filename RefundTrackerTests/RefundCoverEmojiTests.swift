import SwiftData
import XCTest
@testable import RefundTracker

final class RefundCoverEmojiTests: XCTestCase {
    func testCatalogContainsUniqueOptionsAndEveryGroupHasChoices() {
        XCTAssertFalse(RefundCoverEmoji.all.isEmpty)
        XCTAssertTrue(RefundCoverEmoji.groups.allSatisfy { !$0.emoji.isEmpty })
        XCTAssertEqual(
            Set(RefundCoverEmoji.all).count,
            RefundCoverEmoji.all.count,
            "Picker identifiers rely on each emoji appearing only once."
        )
    }

    func testNewRefundGetsAnAllowlistedRandomCover() {
        let refund = Refund()

        XCTAssertTrue(RefundCoverEmoji.all.contains(refund.coverEmoji))
    }

    @MainActor
    func testNewFormGetsAndPersistsAnAllowlistedRandomCover() {
        let viewModel = RefundFormViewModel(
            defaultCurrencyCode: "USD",
            calendar: DomainTestSupport.calendar,
            now: DomainTestSupport.date(2026, 8, 9)
        )
        let initialCover = viewModel.coverEmoji
        viewModel.retailerName = "Everlane"
        viewModel.amountText = "84.50"

        let refund = Refund(coverEmoji: "📦")
        viewModel.apply(to: refund)

        XCTAssertTrue(RefundCoverEmoji.all.contains(initialCover))
        XCTAssertEqual(refund.coverEmoji, initialCover)
    }

    @MainActor
    func testEditingSeedsAndUpdatesTheSavedCover() {
        let refund = makeRefund(coverEmoji: "👟")
        let viewModel = RefundFormViewModel(
            refund: refund,
            calendar: DomainTestSupport.calendar,
            now: DomainTestSupport.date(2026, 8, 9)
        )

        XCTAssertEqual(viewModel.coverEmoji, "👟")

        viewModel.coverEmoji = "🎧"
        viewModel.apply(to: refund)

        XCTAssertEqual(refund.coverEmoji, "🎧")
        XCTAssertEqual(refund.displayCoverEmoji, "🎧")
    }

    @MainActor
    func testEditingLegacyBlankCoverLocksItsStableFallback() {
        let refund = makeRefund(coverEmoji: "")
        let fallback = refund.displayCoverEmoji
        let viewModel = RefundFormViewModel(
            refund: refund,
            calendar: DomainTestSupport.calendar,
            now: DomainTestSupport.date(2026, 8, 9)
        )

        XCTAssertEqual(viewModel.coverEmoji, fallback)

        viewModel.apply(to: refund)

        XCTAssertEqual(refund.coverEmoji, fallback)
        XCTAssertEqual(refund.displayCoverEmoji, fallback)
    }

    func testDisplayCoverPreservesMultiScalarEmojiAndLegacyFallbackIsStable() {
        let chosen = makeRefund(coverEmoji: "❤️")
        XCTAssertEqual(chosen.displayCoverEmoji, "❤️")

        let firstLegacy = makeRefund(coverEmoji: "")
        let secondLegacy = makeRefund(coverEmoji: "")
        XCTAssertEqual(firstLegacy.displayCoverEmoji, secondLegacy.displayCoverEmoji)
        XCTAssertTrue(RefundCoverEmoji.all.contains(firstLegacy.displayCoverEmoji))
    }

    func testUpdatingCoverTrimsWhitespaceAndTouchesTheReturn() {
        let originalDate = DomainTestSupport.date(2026, 8, 1)
        let updateDate = DomainTestSupport.date(2026, 8, 9)
        let refund = makeRefund(coverEmoji: "👗", lastUpdatedDate: originalDate)

        refund.updateCoverEmoji("  👜  ", on: updateDate)

        XCTAssertEqual(refund.coverEmoji, "👜")
        XCTAssertEqual(refund.lastUpdatedDate, updateDate)
    }

    @MainActor
    func testCoverRoundTripsThroughSwiftData() throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Refund.self,
            RefundAttachment.self,
            configurations: configuration
        )
        let context = ModelContext(container)
        let refund = makeRefund(coverEmoji: "🔮")
        context.insert(refund)
        try context.save()

        let fetched = try XCTUnwrap(
            context.fetch(FetchDescriptor<Refund>()).first
        )
        XCTAssertEqual(fetched.coverEmoji, "🔮")
        XCTAssertEqual(fetched.displayCoverEmoji, "🔮")
    }

    private func makeRefund(
        coverEmoji: String,
        lastUpdatedDate: Date = DomainTestSupport.date(2026, 8, 1)
    ) -> Refund {
        Refund(
            retailerName: "Test Shop",
            itemName: "Test item",
            refundAmount: 42,
            currencyCode: "USD",
            returnDate: DomainTestSupport.date(2026, 8, 1),
            expectedRefundDate: DomainTestSupport.date(2026, 8, 20),
            status: .shipped,
            coverEmoji: coverEmoji,
            lastUpdatedDate: lastUpdatedDate
        )
    }
}
