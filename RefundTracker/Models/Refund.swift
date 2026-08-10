import Foundation
import SwiftData

@Model
final class Refund {
    static let simplifiedItemPlaceholder = "Return"

    @Attribute(.unique) var id: UUID
    var retailerName: String
    var itemName: String
    var orderNumber: String
    var refundAmount: Decimal
    var currencyCode: String
    var purchaseDate: Date?
    var returnDate: Date
    var shippedDate: Date?
    /// Deadline for putting a not-yet-shipped return in the post. Set only
    /// while the return is still being prepared; the shipped date takes over
    /// once it actually goes out.
    var shipByDate: Date?
    var retailerReceivedDate: Date?
    var expectedRefundDate: Date
    var actualRefundDate: Date?
    var refundMethodRawValue: String
    var statusRawValue: String
    var trackingNumber: String
    var returnCarrier: String
    var notes: String
    /// The emoji shown on this return's tile. Empty means "never chosen", which
    /// is distinct from any particular emoji and lets the fallback stay stable.
    var coverEmoji: String = ""
    var createdDate: Date
    var lastUpdatedDate: Date
    var isSampleData: Bool

    @Relationship(deleteRule: .cascade, inverse: \RefundAttachment.refund)
    var attachments: [RefundAttachment]

    var refundMethod: RefundMethod {
        get { RefundMethod(rawValue: refundMethodRawValue) ?? .originalPaymentMethod }
        set {
            refundMethodRawValue = newValue.rawValue
            touch()
        }
    }

    /// The user-selected workflow state. Use `effectiveStatus(on:calendar:)` when
    /// presenting the record so an elapsed expected date can surface as overdue.
    var status: RefundStatus {
        get { RefundStatus(rawValue: statusRawValue) ?? .preparingReturn }
        set {
            statusRawValue = newValue.rawValue
            touch()
        }
    }

    var effectiveStatus: RefundStatus {
        effectiveStatus(on: .now)
    }

    var isOverdue: Bool {
        isOverdue(on: .now)
    }

    var isResolved: Bool {
        status == .refunded || status == .cancelled || actualRefundDate != nil
    }

    /// A return that has been logged but not yet put in the post.
    var isAwaitingShipment: Bool {
        status == .preparingReturn && shippedDate == nil
    }

    /// The ship-by deadline has passed and the return still hasn't gone out.
    ///
    /// Deliberately separate from `isOverdue`: that one means the retailer is
    /// late refunding, this one means the user is late posting. They call for
    /// opposite actions, so conflating them would send people chasing the
    /// wrong party.
    func isShipmentOverdue(
        on date: Date = .now,
        calendar: Calendar = .current
    ) -> Bool {
        guard isAwaitingShipment, let shipByDate else { return false }
        return calendar.startOfDay(for: date)
            > calendar.startOfDay(for: shipByDate)
    }

    /// What the tile actually shows. Returns saved before covers existed — and
    /// any left blank — fall back to an emoji derived from the merchant name,
    /// so old rows get a stable cover without having to be rewritten.
    var displayCoverEmoji: String {
        let chosen = coverEmoji.trimmingCharacters(in: .whitespacesAndNewlines)
        return chosen.isEmpty
            ? RefundCoverEmoji.derived(for: retailerName)
            : chosen
    }

    func updateCoverEmoji(_ emoji: String, on date: Date = .now) {
        coverEmoji = emoji.trimmingCharacters(in: .whitespacesAndNewlines)
        touch(on: date)
    }

    var userFacingItemName: String? {
        let trimmedName = itemName
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty,
              trimmedName.caseInsensitiveCompare(Self.simplifiedItemPlaceholder)
                != .orderedSame else {
            return nil
        }
        return trimmedName
    }

    init(
        id: UUID = UUID(),
        retailerName: String = "",
        itemName: String = "",
        orderNumber: String = "",
        refundAmount: Decimal = 0,
        currencyCode: String = Locale.current.currency?.identifier ?? "USD",
        purchaseDate: Date? = nil,
        returnDate: Date = .now,
        shippedDate: Date? = nil,
        shipByDate: Date? = nil,
        retailerReceivedDate: Date? = nil,
        expectedRefundDate: Date = .now,
        actualRefundDate: Date? = nil,
        refundMethod: RefundMethod = .originalPaymentMethod,
        status: RefundStatus = .preparingReturn,
        trackingNumber: String = "",
        returnCarrier: String = "",
        notes: String = "",
        coverEmoji: String = RefundCoverEmoji.random(),
        attachments: [RefundAttachment] = [],
        createdDate: Date = .now,
        lastUpdatedDate: Date = .now,
        isSampleData: Bool = false
    ) {
        self.id = id
        self.retailerName = retailerName
        self.itemName = itemName
        self.orderNumber = orderNumber
        self.refundAmount = refundAmount
        self.currencyCode = currencyCode
        self.purchaseDate = purchaseDate
        self.returnDate = returnDate
        self.shippedDate = shippedDate
        self.shipByDate = shipByDate
        self.retailerReceivedDate = retailerReceivedDate
        self.expectedRefundDate = expectedRefundDate
        self.actualRefundDate = actualRefundDate
        self.refundMethodRawValue = refundMethod.rawValue
        self.statusRawValue = status.rawValue
        self.trackingNumber = trackingNumber
        self.returnCarrier = returnCarrier
        self.notes = notes
        self.coverEmoji = coverEmoji
        self.attachments = attachments
        self.createdDate = createdDate
        self.lastUpdatedDate = lastUpdatedDate
        self.isSampleData = isSampleData

        for attachment in attachments {
            attachment.refund = self
        }
    }

    func effectiveStatus(
        on date: Date,
        calendar: Calendar = .current
    ) -> RefundStatus {
        if status == .disputed || status == .cancelled {
            return status
        }

        if status == .refunded || actualRefundDate != nil {
            return .refunded
        }

        if isOverdue(on: date, calendar: calendar) {
            return .overdue
        }

        // An explicitly persisted overdue state should not remain stale if the
        // expected date is subsequently moved into the future.
        return status == .overdue ? .refundPending : status
    }

    func isOverdue(
        on date: Date,
        calendar: Calendar = .current
    ) -> Bool {
        // A return still sitting on the hallway table can't have a late
        // refund — nothing has been sent back for the retailer to act on.
        guard !isResolved, status != .disputed, !isAwaitingShipment else {
            return false
        }

        let expectedDay = calendar.startOfDay(for: expectedRefundDate)
        let comparisonDay = calendar.startOfDay(for: date)
        return comparisonDay > expectedDay
    }

    /// Records that the return actually went out.
    ///
    /// A pending return's expected refund date was only ever a projection off
    /// its ship-by deadline, so pass the recomputed date to re-anchor it to
    /// the day it really shipped.
    func markShipped(
        on date: Date = .now,
        expectedRefundDate newExpectedRefundDate: Date? = nil
    ) {
        shippedDate = date
        shipByDate = nil
        if let newExpectedRefundDate {
            expectedRefundDate = newExpectedRefundDate
        }
        statusRawValue = RefundStatus.shipped.rawValue
        touch(on: date)
    }

    func markDelivered(on date: Date = .now) {
        if shippedDate == nil {
            shippedDate = date
        }
        retailerReceivedDate = date
        statusRawValue = RefundStatus.deliveredToRetailer.rawValue
        touch(on: date)
    }

    func markRefundPending(on date: Date = .now) {
        statusRawValue = RefundStatus.refundPending.rawValue
        touch(on: date)
    }

    func markRefunded(on date: Date = .now) {
        actualRefundDate = date
        statusRawValue = RefundStatus.refunded.rawValue
        touch(on: date)
    }

    func markDisputed(on date: Date = .now) {
        statusRawValue = RefundStatus.disputed.rawValue
        touch(on: date)
    }

    func markCancelled(on date: Date = .now) {
        statusRawValue = RefundStatus.cancelled.rawValue
        touch(on: date)
    }

    func updateTracking(
        number: String,
        carrier: String? = nil,
        on date: Date = .now
    ) {
        trackingNumber = number.trimmingCharacters(in: .whitespacesAndNewlines)
        if let carrier {
            returnCarrier = carrier.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        touch(on: date)
    }

    func addAttachment(_ attachment: RefundAttachment, on date: Date = .now) {
        attachment.refund = self
        attachments.append(attachment)
        touch(on: date)
    }

    func removeAttachment(_ attachment: RefundAttachment, on date: Date = .now) {
        attachments.removeAll { $0.id == attachment.id }
        touch(on: date)
    }

    func touch(on date: Date = .now) {
        lastUpdatedDate = date
    }
}
