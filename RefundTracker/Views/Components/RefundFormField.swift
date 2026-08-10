import SwiftUI

/// An eyebrow label over a control, closed by a rule. Boxed fields with a fill
/// and a corner radius were the most iOS-looking thing on these screens.
struct RefundFormField<Content: View>: View {
    let label: String
    var bottomPadding: CGFloat = 26
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(label)
                .eyebrow(size: 10)

            content
                .tint(RefundTheme.ink)
                .foregroundStyle(RefundTheme.ink)

            Hairline()
        }
        .padding(.bottom, bottomPadding)
    }
}

/// A word marked by a rule when chosen — the app's stand-in for a segmented
/// control.
struct RefundChoice: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Text(title)
                    .font(.system(.subheadline).weight(isSelected ? .medium : .regular))
                    .foregroundStyle(
                        isSelected ? RefundTheme.ink : RefundTheme.inkFaint
                    )

                Rectangle()
                    .fill(isSelected ? RefundTheme.ink : .clear)
                    .frame(height: 1.5)
            }
            .fixedSize()
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
    }
}

/// A tappable row that reports whether it is the current choice, for the lists
/// that stand in for inline pickers.
struct RefundSelectionRow: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Text(title)
                    .font(.system(.subheadline))
                    .foregroundStyle(RefundTheme.ink)

                Spacer(minLength: 8)

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(.footnote).weight(.medium))
                        .foregroundStyle(RefundTheme.ink)
                }
            }
            .padding(.vertical, 15)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
    }
}
