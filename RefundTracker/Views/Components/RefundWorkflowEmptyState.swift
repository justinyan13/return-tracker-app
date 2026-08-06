import SwiftUI

struct RefundWorkflowEmptyState: View {
    enum Kind {
        case firstRefund
        case noResults
    }

    let kind: Kind
    var addAction: (() -> Void)?

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: symbolName)
        } description: {
            Text(message)
        } actions: {
            if let addAction, kind == .firstRefund {
                Button("Track a refund", systemImage: "plus", action: addAction)
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("emptyStateAddRefundButton")
            }
        }
    }

    private var title: String {
        switch kind {
        case .firstRefund:
            "Never lose track of a refund"
        case .noResults:
            "No matching refunds"
        }
    }

    private var message: String {
        switch kind {
        case .firstRefund:
            "Add a return and Refund Tracker will keep its expected date, status, and follow-up details together."
        case .noResults:
            "Try changing your search, filters, or date range."
        }
    }

    private var symbolName: String {
        switch kind {
        case .firstRefund:
            "arrow.uturn.backward.circle"
        case .noResults:
            "line.3.horizontal.decrease.circle"
        }
    }
}
