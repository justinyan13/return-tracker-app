import SwiftUI

struct RefundRowView: View {
    let refund: Refund
    var referenceDate: Date

    init(refund: Refund, referenceDate: Date = .now) {
        self.refund = refund
        self.referenceDate = referenceDate
    }

    private var status: RefundStatus {
        refund.effectiveStatus(on: referenceDate, calendar: .current)
    }

    var body: some View {
        HStack(alignment: .center, spacing: 13) {
            MerchantMark(name: refund.retailerName, size: 50)

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(refund.retailerName)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Spacer(minLength: 4)

                    RefundAmountLabel(
                        amount: refund.refundAmount,
                        currencyCode: refund.currencyCode,
                        style: .headline.weight(.heavy)
                    )
                }

                HStack(spacing: 8) {
                    Label(dateText, systemImage: dateSymbol)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(dateColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)

                    Spacer(minLength: 2)

                    RefundStatusBadge(status: status)
                        .layoutPriority(1)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .refundGlassCard(
            tint: RefundTheme.color(for: refund.retailerName),
            padding: 14
        )
        .contentShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary)
        .accessibilityHint("Opens refund details")
    }

    private var dateText: String {
        switch status {
        case .shipped:
            if let shippedDate = refund.shippedDate {
                return "Shipped \(shortDate(shippedDate)) · due \(shortDate(refund.expectedRefundDate))"
            }
            return "Expected \(shortDate(refund.expectedRefundDate))"
        case .deliveredToRetailer:
            if let receivedDate = refund.retailerReceivedDate {
                return "Delivered \(shortDate(receivedDate)) · due \(shortDate(refund.expectedRefundDate))"
            }
            return "Expected \(shortDate(refund.expectedRefundDate))"
        case .refunded:
            if let actualDate = refund.actualRefundDate {
                return "Refunded \(shortDate(actualDate))"
            }
            return "Refund received"
        case .overdue:
            return "Expected \(shortDate(refund.expectedRefundDate))"
        case .preparingReturn, .refundPending, .disputed, .cancelled:
            return "Expected \(shortDate(refund.expectedRefundDate))"
        }
    }

    private var dateSymbol: String {
        switch status {
        case .shipped:
            "shippingbox.fill"
        case .deliveredToRetailer:
            "checkmark.circle.fill"
        case .refunded:
            "arrow.down.circle.fill"
        case .overdue:
            "exclamationmark.circle.fill"
        case .preparingReturn, .refundPending, .disputed, .cancelled:
            "calendar"
        }
    }

    private var dateColor: Color {
        switch status {
        case .overdue:
            .red
        case .refunded:
            .green
        case .disputed:
            .orange
        case .preparingReturn, .shipped, .deliveredToRetailer,
             .refundPending, .cancelled:
            .secondary
        }
    }

    private func shortDate(_ date: Date) -> String {
        date.formatted(.dateTime.month(.abbreviated).day())
    }

    private var accessibilitySummary: String {
        let amount = refund.refundAmount.formatted(
            .currency(code: refund.currencyCode)
        )
        return "\(refund.retailerName), \(amount), \(status.title), \(dateText)"
    }
}
