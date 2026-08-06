import Foundation
import SwiftData

@Model
final class Refund {
    @Attribute(.unique) var id: UUID
    var retailerName: String
    var itemName: String
    var orderNumber: String
    var refundAmount: Decimal
    var currencyCode: String
    var purchaseDate: Date?
    var returnDate: Date
    var shippedDate: Date?
    var retailerReceivedDate: Date?
    var expectedRefundDate: Date
    var actualRefundDate: Date?
    var refundMethodRawValue: String
    var statusRawValue: String
    var trackingNumber: String
    var returnCarrier: String
    var notes: String
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
        retailerReceivedDate: Date? = nil,
        expectedRefundDate: Date = .now,
        actualRefundDate: Date? = nil,
        refundMethod: RefundMethod = .originalPaymentMethod,
        status: RefundStatus = .preparingReturn,
        trackingNumber: String = "",
        returnCarrier: String = "",
        notes: String = "",
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
        self.retailerReceivedDate = retailerReceivedDate
        self.expectedRefundDate = expectedRefundDate
        self.actualRefundDate = actualRefundDate
        self.refundMethodRawValue = refundMethod.rawValue
        self.statusRawValue = status.rawValue
        self.trackingNumber = trackingNumber
        self.returnCarrier = returnCarrier
        self.notes = notes
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
        guard !isResolved, status != .disputed else {
            return false
        }

        let expectedDay = calendar.startOfDay(for: expectedRefundDate)
        let comparisonDay = calendar.startOfDay(for: date)
        return comparisonDay > expectedDay
    }

    func markShipped(on date: Date = .now) {
        shippedDate = date
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
