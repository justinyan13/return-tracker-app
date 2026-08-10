import SwiftUI

/// Empty states are a headline, a line of explanation, and one action — set on
/// paper rather than around a gradient tile.
struct RefundWorkflowEmptyState: View {
    enum Kind {
        case firstRefund
        case noResults
    }

    let kind: Kind
    var addAction: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(eyebrow)
                .eyebrow()

            Text(title)
                .serif(32, relativeTo: .largeTitle)
                .foregroundStyle(RefundTheme.ink)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 14)

            Hairline()
                .padding(.top, 22)

            Text(message)
                .font(.system(.subheadline))
                .foregroundStyle(RefundTheme.inkSoft)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 18)

            if let addAction, kind == .firstRefund {
                Button("Track a refund", action: addAction)
                    .buttonStyle(RefundPrimaryButtonStyle())
                    .padding(.top, 30)
                    .accessibilityIdentifier("emptyStateAddRefundButton")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
        .padding(.top, 40)
    }

    private var eyebrow: String {
        switch kind {
        case .firstRefund:
            "Nothing tracked yet"
        case .noResults:
            "No matches"
        }
    }

    private var title: String {
        switch kind {
        case .firstRefund:
            "Every return, in one place."
        case .noResults:
            "Nothing here."
        }
    }

    private var message: String {
        switch kind {
        case .firstRefund:
            "Add a merchant and an amount. The dates take care of themselves."
        case .noResults:
            "Try another search, or loosen the filters."
        }
    }
}
