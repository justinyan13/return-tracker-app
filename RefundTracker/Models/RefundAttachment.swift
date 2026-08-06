import Foundation
import SwiftData

enum AttachmentKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case receipt
    case returnConfirmation
    case shippingReceipt
    case screenshot
    case other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .receipt:
            "Receipt"
        case .returnConfirmation:
            "Return confirmation"
        case .shippingReceipt:
            "Shipping receipt"
        case .screenshot:
            "Screenshot"
        case .other:
            "Attachment"
        }
    }
}

@Model
final class RefundAttachment {
    @Attribute(.unique) var id: UUID
    var originalFilename: String
    var storedFilename: String
    var uniformTypeIdentifier: String
    var byteCount: Int64
    var kindRawValue: String
    var createdDate: Date
    var refund: Refund?

    var kind: AttachmentKind {
        get { AttachmentKind(rawValue: kindRawValue) ?? .other }
        set { kindRawValue = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        originalFilename: String,
        storedFilename: String,
        uniformTypeIdentifier: String = "public.data",
        byteCount: Int64 = 0,
        kind: AttachmentKind = .other,
        createdDate: Date = .now,
        refund: Refund? = nil
    ) {
        self.id = id
        self.originalFilename = originalFilename
        self.storedFilename = storedFilename
        self.uniformTypeIdentifier = uniformTypeIdentifier
        self.byteCount = byteCount
        self.kindRawValue = kind.rawValue
        self.createdDate = createdDate
        self.refund = refund
    }
}
