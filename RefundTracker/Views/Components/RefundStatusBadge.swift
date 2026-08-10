import SwiftUI

/// A dot and a letterspaced word. Status used to be a tinted capsule per state,
/// which put five competing colours in a single list.
struct RefundStatusBadge: View {
    let status: RefundStatus

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(status.markColor)
                .frame(width: 5, height: 5)

            Text(compactTitle)
                .eyebrow(size: 10, color: status.labelColor)
                .lineLimit(1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(status.title)
    }

    private var compactTitle: String {
        switch status {
        case .deliveredToRetailer:
            "Delivered"
        case .preparingReturn:
            "To send"
        case .refundPending:
            "Pending"
        default:
            status.title
        }
    }
}

extension RefundStatus {
    var title: String {
        displayName
    }

    var symbolName: String {
        iconName
    }

    /// The dot. Only lateness and arrival earn a colour.
    var markColor: Color {
        switch self {
        case .refunded:
            RefundTheme.success
        case .overdue, .disputed:
            RefundTheme.alert
        case .cancelled:
            RefundTheme.inkFaint
        case .preparingReturn, .shipped, .deliveredToRetailer, .refundPending:
            RefundTheme.ink
        }
    }

    var labelColor: Color {
        switch self {
        case .refunded:
            RefundTheme.success
        case .overdue, .disputed:
            RefundTheme.alert
        case .cancelled:
            RefundTheme.inkFaint
        case .preparingReturn, .shipped, .deliveredToRetailer, .refundPending:
            RefundTheme.inkSoft
        }
    }
}
