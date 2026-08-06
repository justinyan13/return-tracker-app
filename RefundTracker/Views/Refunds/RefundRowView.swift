import SwiftUI

struct RefundRowView: View {
    let refund: Refund

    private var status: RefundStatus {
        refund.effectiveStatus(on: .now, calendar: .current)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(refund.retailerName)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(refund.itemName)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer(minLength: 8)

                RefundAmountLabel(
                    amount: refund.refundAmount,
                    currencyCode: refund.currencyCode
                )
            }

            HStack(spacing: 8) {
                RefundStatusBadge(status: status)

                Spacer(minLength: 4)

                Label(expectedDateText, systemImage: expectedDateSymbol)
                    .font(.caption)
                    .foregroundStyle(status == .overdue ? .red : .secondary)
                    .fontWeight(status == .overdue ? .semibold : .regular)
            }
        }
        .padding(.vertical, 5)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilitySummary)
    }

    private var expectedDateText: String {
        if status == .refunded, let date = refund.actualRefundDate {
            return "Received \(date.formatted(date: .abbreviated, time: .omitted))"
        }
        if status == .overdue {
            return "Due \(refund.expectedRefundDate.formatted(date: .abbreviated, time: .omitted))"
        }
        return "Expected \(refund.expectedRefundDate.formatted(date: .abbreviated, time: .omitted))"
    }

    private var expectedDateSymbol: String {
        switch status {
        case .overdue:
            "exclamationmark.circle.fill"
        case .refunded:
            "checkmark.circle"
        default:
            "calendar"
        }
    }

    private var accessibilitySummary: String {
        let amount = refund.refundAmount.formatted(.currency(code: refund.currencyCode))
        return "\(refund.retailerName), \(refund.itemName), \(amount), \(status.title), \(expectedDateText)"
    }
}
