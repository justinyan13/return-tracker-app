import SwiftUI

/// The combined Refunds screen's headline figure and three at-a-glance counts.
struct RefundSummaryHeader: View {
    let amount: Decimal
    let currencyCode: String
    let otherAmounts: [String: Decimal]
    let openCount: Int
    let overdueCount: Int
    let refundedCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Outstanding")
                .eyebrow()

            Text(amount, format: .currency(code: currencyCode))
                .serif(46, relativeTo: .largeTitle)
                .foregroundStyle(RefundTheme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .padding(.top, 10)

            Text(summary)
                .font(.system(.subheadline))
                .foregroundStyle(RefundTheme.inkSoft)
                .padding(.top, 6)

            if !otherAmounts.isEmpty {
                Text(otherAmountsDescription)
                    .eyebrow(size: 10)
                    .padding(.top, 10)
            }

            Hairline()
                .padding(.top, 22)

            HStack(alignment: .top, spacing: 0) {
                RefundSummaryCount(value: openCount, label: "Open")

                VerticalHairline(height: 40)

                RefundSummaryCount(
                    value: overdueCount,
                    label: "Overdue",
                    tint: overdueCount == 0 ? RefundTheme.ink : RefundTheme.alert
                )

                VerticalHairline(height: 40)

                RefundSummaryCount(value: refundedCount, label: "Refunded")
            }
            .padding(.vertical, 18)

            Hairline()
        }
        .padding(.top, 6)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("refundSummary")
    }

    private var summary: String {
        if openCount == 0 {
            return "Everything has landed."
        }
        if overdueCount > 0 {
            return overdueCount == 1
                ? "One refund is running late."
                : "\(overdueCount) refunds are running late."
        }
        return openCount == 1
            ? "One refund on the way."
            : "\(openCount) refunds on the way."
    }

    private var otherAmountsDescription: String {
        let sorted = otherAmounts.sorted { $0.key < $1.key }
        let displayed = sorted.prefix(2).map { code, amount in
            amount.formatted(.currency(code: code))
        }
        let remainder = sorted.count - displayed.count
        let suffix = remainder > 0 ? " +\(remainder)" : ""
        return "Also due · \(displayed.joined(separator: " · "))\(suffix)"
    }
}

private struct RefundSummaryCount: View {
    let value: Int
    let label: String
    var tint: Color = RefundTheme.ink

    var body: some View {
        VStack(spacing: 7) {
            Text(value.formatted())
                .serif(26, relativeTo: .title)
                .foregroundStyle(tint)

            Text(label)
                .eyebrow(size: 9)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label): \(value)")
    }
}
