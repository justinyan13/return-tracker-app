import SwiftUI

struct RefundAmountLabel: View {
    let amount: Decimal
    let currencyCode: String
    var size: CGFloat = 18
    var relativeTo: Font.TextStyle = .body
    var color: Color = RefundTheme.ink

    var body: some View {
        Text(amount, format: .currency(code: currencyCode))
            .serif(size, relativeTo: relativeTo)
            .foregroundStyle(color)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .accessibilityLabel(
                amount.formatted(.currency(code: currencyCode))
            )
    }
}
