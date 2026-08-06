import SwiftUI

struct RefundFilterChip: View {
    let title: String
    var symbolName: String?
    var count = 0
    var isSelected = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                if let symbolName {
                    Image(systemName: symbolName)
                }
                Text(title)
                    .lineLimit(1)
                if count > 0 {
                    Text("\(count)")
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(.tint.opacity(0.16), in: Capsule())
                }
            }
            .font(.subheadline.weight(.medium))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .foregroundStyle(isSelected ? Color.accentColor : .primary)
            .background(
                isSelected ? Color.accentColor.opacity(0.11) : Color.secondary.opacity(0.09),
                in: Capsule()
            )
            .overlay {
                Capsule()
                    .stroke(
                        isSelected ? Color.accentColor.opacity(0.45) : .clear,
                        lineWidth: 1
                    )
            }
        }
        .buttonStyle(.plain)
    }
}
