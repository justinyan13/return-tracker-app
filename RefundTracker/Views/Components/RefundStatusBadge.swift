import SwiftUI

struct RefundStatusBadge: View {
    let status: RefundStatus

    var body: some View {
        Label(status.title, systemImage: status.symbolName)
            .font(.caption.weight(.semibold))
            .foregroundStyle(status.foregroundColor)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(status.backgroundColor, in: Capsule())
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Status: \(status.title)")
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
            .blue
        }
    }

    var backgroundColor: Color {
        foregroundColor.opacity(0.13)
    }
}
