import SwiftUI

struct RefundWorkflowEmptyState: View {
    enum Kind {
        case firstRefund
        case noResults
    }

    let kind: Kind
    var addAction: (() -> Void)?

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: symbolName)
                .font(.system(size: 42, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.white)
                .frame(width: 94, height: 94)
                .background(
                    LinearGradient(
                        colors: tintColors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: RoundedRectangle(cornerRadius: 28, style: .continuous)
                )
                .shadow(color: tintColors[0].opacity(0.25), radius: 18, y: 11)

            Text(title)
                .font(.title2.bold())
                .multilineTextAlignment(.center)

            Text(message)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            if let addAction, kind == .firstRefund {
                Button(action: addAction) {
                    Label("Track a refund", systemImage: "plus")
                }
                .buttonStyle(RefundPrimaryButtonStyle())
                .accessibilityIdentifier("emptyStateAddRefundButton")
            }
        }
        .refundGlassCard(tint: tintColors[0], padding: 24)
        .padding(20)
    }

    private var title: String {
        switch kind {
        case .firstRefund:
            "Your money radar is empty"
        case .noResults:
            "Nothing hiding here"
        }
    }

    private var message: String {
        switch kind {
        case .firstRefund:
            "Add a merchant and amount. We’ll take care of the dates and keep watch."
        case .noResults:
            "Try a different search or loosen the filters."
        }
    }

    private var symbolName: String {
        switch kind {
        case .firstRefund:
            "arrow.uturn.backward"
        case .noResults:
            "binoculars.fill"
        }
    }

    private var tintColors: [Color] {
        switch kind {
        case .firstRefund:
            [RefundTheme.violet, RefundTheme.blue]
        case .noResults:
            [RefundTheme.mango, RefundTheme.coral]
        }
    }
}
