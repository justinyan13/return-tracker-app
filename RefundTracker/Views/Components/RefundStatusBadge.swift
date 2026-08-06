import SwiftUI

struct RefundStatusBadge: View {
    let status: RefundStatus

    var body: some View {
        Label {
            Text(compactTitle)
                .lineLimit(1)
        } icon: {
            Image(systemName: status.symbolName)
                .font(.caption2.weight(.heavy))
        }
        .font(.caption2.weight(.heavy))
        .foregroundStyle(status.foregroundColor)
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(status.backgroundColor, in: Capsule())
        .overlay {
            Capsule()
                .stroke(status.badgeTint.opacity(0.24), lineWidth: 1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Status: \(status.title)")
    }

    private var compactTitle: String {
        switch status {
        case .deliveredToRetailer:
            "Delivered"
        case .preparingReturn:
            "Preparing"
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

    var foregroundColor: Color {
        switch self {
        case .refunded:
            .green
        case .overdue:
            .red
        case .disputed:
            .orange
        case .cancelled:
            .secondary
        case .preparingReturn, .shipped, .deliveredToRetailer, .refundPending:
            RefundTheme.violet
        }
    }

    var backgroundColor: Color {
        badgeTint.opacity(0.13)
    }

    var badgeTint: Color {
        switch self {
        case .refunded:
            RefundTheme.mint
        case .overdue:
            RefundTheme.coral
        case .disputed:
            RefundTheme.mango
        case .cancelled:
            .secondary
        case .preparingReturn, .shipped, .deliveredToRetailer, .refundPending:
            RefundTheme.violet
        }
    }
}
