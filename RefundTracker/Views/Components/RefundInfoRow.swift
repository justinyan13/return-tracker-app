import SwiftUI

/// Label left, value right, on one line. The old version leaned on an icon per
/// row; the eyebrow label carries it now.
struct RefundInfoRow<Content: View>: View {
    let label: String
    @ViewBuilder let content: Content

    init(_ label: String, @ViewBuilder content: () -> Content) {
        self.label = label
        self.content = content()
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 16) {
            Text(label)
                .eyebrow(size: 10)

            Spacer(minLength: 12)

            content
                .font(.system(.subheadline))
                .foregroundStyle(RefundTheme.ink)
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, 10)
    }
}
