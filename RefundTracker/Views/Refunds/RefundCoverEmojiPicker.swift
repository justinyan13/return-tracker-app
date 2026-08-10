import SwiftUI

/// A compact, curated picker rather than a text field: every option is a
/// single useful cover and the user never has to find the emoji keyboard.
struct RefundCoverEmojiPicker: View {
    @Environment(\.dismiss) private var dismiss

    @Binding var selection: String

    private let columns = [
        GridItem(.adaptive(minimum: 48, maximum: 64), spacing: 10)
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                RefundBackdrop()

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 30) {
                        ForEach(RefundCoverEmoji.groups) { group in
                            emojiGroup(group)
                        }
                    }
                    .padding(.horizontal, 22)
                    .padding(.vertical, 24)
                }
                .scrollIndicators(.hidden)
                .accessibilityIdentifier("coverEmojiPicker")
            }
            .navigationTitle("Choose a cover")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    Button("Surprise me", systemImage: "shuffle") {
                        choose(RefundCoverEmoji.random(excluding: selection))
                    }
                    .accessibilityIdentifier("randomCoverEmojiButton")
                }
            }
        }
        .tint(RefundTheme.ink)
    }

    private func emojiGroup(_ group: RefundCoverEmoji.Group) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(group.name)
                .eyebrow(size: 10)

            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(group.emoji, id: \.self) { emoji in
                    emojiButton(emoji)
                }
            }
        }
    }

    private func emojiButton(_ emoji: String) -> some View {
        let isSelected = selection == emoji

        return Button {
            choose(emoji)
        } label: {
            Text(emoji)
                .font(.system(size: 29))
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(isSelected ? RefundTheme.sand : .clear)
                .overlay {
                    Rectangle()
                        .stroke(
                            isSelected ? RefundTheme.ink : RefundTheme.line,
                            lineWidth: isSelected ? 1.5 : RefundTheme.hairline
                        )
                }
                .overlay(alignment: .topTrailing) {
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 13))
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(RefundTheme.reverse, RefundTheme.ink)
                            .padding(4)
                            .accessibilityHidden(true)
                    }
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(emoji) cover emoji")
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier(optionIdentifier(for: emoji))
    }

    private func choose(_ emoji: String) {
        selection = emoji
        dismiss()
    }

    private func optionIdentifier(for emoji: String) -> String {
        let index = RefundCoverEmoji.all.firstIndex(of: emoji) ?? -1
        return "coverEmojiOption_\(index)"
    }
}
