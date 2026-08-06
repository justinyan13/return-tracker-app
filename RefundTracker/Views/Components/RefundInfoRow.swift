import SwiftUI

struct RefundInfoRow<Content: View>: View {
    let label: String
    let symbol: String
    @ViewBuilder let content: Content

    init(
        _ label: String,
        symbol: String,
        @ViewBuilder content: () -> Content
    ) {
        self.label = label
        self.symbol = symbol
        self.content = content()
    }

    var body: some View {
        LabeledContent {
            content
                .multilineTextAlignment(.trailing)
        } label: {
            Label(label, systemImage: symbol)
                .foregroundStyle(.secondary)
        }
    }
}
