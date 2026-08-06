import SwiftUI

struct RefundAmountLabel: View {
    let amount: Decimal
    let currencyCode: String
    var style: Font = .headline

    var body: some View {
        Text(amount, format: .currency(code: currencyCode))
            .font(style)
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .accessibilityLabel(
                amount.formatted(.currency(code: currencyCode))
            )
    }
}
