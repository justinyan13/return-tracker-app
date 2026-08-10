import SwiftUI

/// A compact quick look shown by the system context menu when a return row is
/// held. It keeps the most useful information visible without duplicating the
/// full detail screen.
struct RefundPreviewView: View {
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
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 14) {
                RefundCoverMark(emoji: refund.displayCoverEmoji, size: 48)

                VStack(alignment: .leading, spacing: 6) {
                    Text(refund.retailerName)
                        .serif(23, relativeTo: .title3)
                        .foregroundStyle(RefundTheme.ink)
                        .lineLimit(2)
                        .accessibilityIdentifier("refundPreview.retailer")

                    if let itemName = refund.userFacingItemName {
                        Text(itemName)
                            .font(.system(.subheadline))
                            .foregroundStyle(RefundTheme.inkSoft)
                            .lineLimit(2)
                            .accessibilityIdentifier("refundPreview.item")
                    }
                }

                Spacer(minLength: 0)
            }

            HStack(alignment: .bottom, spacing: 12) {
                VStack(alignment: .leading, spacing: 7) {
                    Text("Refund amount")
                        .eyebrow(size: 9)

                    RefundAmountLabel(
                        amount: refund.refundAmount,
                        currencyCode: refund.currencyCode,
                        size: 32,
                        relativeTo: .title
                    )
                    .accessibilityIdentifier("refundPreview.amount")
                }

                Spacer(minLength: 8)

                RefundStatusBadge(status: status)
                    .accessibilityIdentifier("refundPreview.status")
            }
            .padding(.top, 24)

            Hairline()
                .padding(.top, 20)

            VStack(spacing: 0) {
                RefundPreviewAttributeRow(
                    label: importantDate.label,
                    value: importantDate.value,
                    identifier: "refundPreview.date"
                )

                RefundPreviewAttributeRow(
                    label: "Refund to",
                    value: refund.refundMethod.displayName,
                    identifier: "refundPreview.method"
                )

                if let orderNumber {
                    RefundPreviewAttributeRow(
                        label: "Order",
                        value: orderNumber,
                        identifier: "refundPreview.order"
                    )
                }

                if let trackingSummary {
                    RefundPreviewAttributeRow(
                        label: "Tracking",
                        value: trackingSummary,
                        identifier: "refundPreview.tracking"
                    )
                }
            }
        }
        .padding(22)
        .frame(width: 330, alignment: .leading)
        .background(RefundTheme.surface)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("refundPreview")
    }

    private var importantDate: (label: String, value: String) {
        if status == .refunded, let actualRefundDate = refund.actualRefundDate {
            return ("Refunded", formatted(actualRefundDate))
        }

        if refund.isAwaitingShipment, let shipByDate = refund.shipByDate {
            return ("Send by", formatted(shipByDate))
        }

        return ("Expected refund", formatted(refund.expectedRefundDate))
    }

    private var orderNumber: String? {
        nonempty(refund.orderNumber)
    }

    private var trackingSummary: String? {
        let number = nonempty(refund.trackingNumber)
        let carrier = nonempty(refund.returnCarrier)

        switch (carrier, number) {
        case let (.some(carrier), .some(number)):
            return "\(carrier) · \(number)"
        case let (.some(carrier), .none):
            return carrier
        case let (.none, .some(number)):
            return number
        case (.none, .none):
            return nil
        }
    }

    private func formatted(_ date: Date) -> String {
        date.formatted(date: .abbreviated, time: .omitted)
    }

    private func nonempty(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

private struct RefundPreviewAttributeRow: View {
    let label: String
    let value: String
    let identifier: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 16) {
            Text(label)
                .eyebrow(size: 9)

            Spacer(minLength: 8)

            Text(value)
                .font(.system(.footnote).weight(.medium))
                .foregroundStyle(RefundTheme.ink)
                .multilineTextAlignment(.trailing)
                .lineLimit(2)
        }
        .padding(.vertical, 12)
        .overlay(alignment: .bottom) {
            Hairline()
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(identifier)
    }
}
