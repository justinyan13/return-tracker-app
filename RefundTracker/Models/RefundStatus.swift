import Foundation

enum RefundStatus: String, Codable, CaseIterable, Identifiable, Sendable {
    case preparingReturn
    case shipped
    case deliveredToRetailer
    case refundPending
    case refunded
    case overdue
    case disputed
    case cancelled

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .preparingReturn:
            "Preparing return"
        case .shipped:
            "Shipped"
        case .deliveredToRetailer:
            "Delivered to retailer"
        case .refundPending:
            "Refund pending"
        case .refunded:
            "Refunded"
        case .overdue:
            "Overdue"
        case .disputed:
            "Disputed"
        case .cancelled:
            "Cancelled"
        }
    }

    var iconName: String {
        switch self {
        case .preparingReturn:
            "shippingbox"
        case .shipped:
            "truck.box"
        case .deliveredToRetailer:
            "shippingbox.and.arrow.backward.fill"
        case .refundPending:
            "clock.arrow.circlepath"
        case .refunded:
            "checkmark.circle.fill"
        case .overdue:
            "exclamationmark.triangle.fill"
        case .disputed:
            "exclamationmark.bubble.fill"
        case .cancelled:
            "xmark.circle.fill"
        }
    }

    var isOpen: Bool {
        self != .refunded && self != .cancelled
    }

    var isManuallyOverridingAutomaticStatus: Bool {
        self == .disputed || self == .cancelled
    }

    var sortOrder: Int {
        switch self {
        case .overdue: 0
        case .disputed: 1
        case .refundPending: 2
        case .deliveredToRetailer: 3
        case .shipped: 4
        case .preparingReturn: 5
        case .refunded: 6
        case .cancelled: 7
        }
    }
}
