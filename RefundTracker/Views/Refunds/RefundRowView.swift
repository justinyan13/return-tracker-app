import SwiftUI

/// One line in a list: cover, merchant, what happens next, and the figure.
/// Rows are separated by a rule rather than floated as cards.
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
        HStack(alignment: .top, spacing: 14) {
            RefundCoverMark(emoji: refund.displayCoverEmoji, size: 42)

            VStack(alignment: .leading, spacing: 5) {
                Text(refund.retailerName)
                    .font(.system(.callout).weight(.medium))
                    .foregroundStyle(RefundTheme.ink)
                    .lineLimit(1)

                if let itemName = refund.userFacingItemName {
                    Text(itemName)
                        .font(.system(.footnote))
                        .foregroundStyle(RefundTheme.inkSoft)
                        .lineLimit(1)
                }

                Text(dateText)
                    .font(.system(.caption))
                    .foregroundStyle(dateColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .padding(.top, 1)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 7) {
                RefundAmountLabel(
                    amount: refund.refundAmount,
                    currencyCode: refund.currencyCode,
                    size: 19,
                    relativeTo: .title3
                )

                RefundStatusBadge(status: status)
            }
        }
        .padding(.vertical, 15)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary)
        .accessibilityHint("Tap for details. Touch and hold for a preview.")
    }

    private var isAwaitingShipment: Bool {
        refund.isAwaitingShipment
    }

    private var isShipmentOverdue: Bool {
        refund.isShipmentOverdue(on: referenceDate, calendar: .current)
    }

    private var dateText: String {
        if isAwaitingShipment, let shipByDate = refund.shipByDate {
            return isShipmentOverdue
                ? "Send it — was due \(shortDate(shipByDate))"
                : "Send by \(shortDate(shipByDate))"
        }

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

    private var dateColor: Color {
        if isAwaitingShipment {
            return isShipmentOverdue ? RefundTheme.alert : RefundTheme.inkSoft
        }

        switch status {
        case .overdue, .disputed:
            return RefundTheme.alert
        case .preparingReturn, .shipped, .deliveredToRetailer,
             .refundPending, .refunded, .cancelled:
            return RefundTheme.inkSoft
        }
    }

    private func shortDate(_ date: Date) -> String {
        date.formatted(.dateTime.day().month(.abbreviated))
    }

    private var accessibilitySummary: String {
        let amount = refund.refundAmount.formatted(
            .currency(code: refund.currencyCode)
        )
        return "\(refund.retailerName), \(refund.displayCoverEmoji) cover, \(amount), \(status.title), \(dateText)"
    }
}
