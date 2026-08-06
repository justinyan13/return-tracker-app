import Foundation

enum RefundMethod: String, Codable, CaseIterable, Identifiable, Sendable {
    case originalPaymentMethod
    case storeCredit
    case giftCard
    case other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .originalPaymentMethod:
            "Original payment method"
        case .storeCredit:
            "Store credit"
        case .giftCard:
            "Gift card"
        case .other:
            "Other"
        }
    }

    var iconName: String {
        switch self {
        case .originalPaymentMethod:
            "creditcard"
        case .storeCredit:
            "building.columns"
        case .giftCard:
            "giftcard"
        case .other:
            "ellipsis.circle"
        }
    }
}
