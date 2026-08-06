import SwiftUI
import UniformTypeIdentifiers

struct RefundAttachmentRow: View {
    let attachment: RefundAttachment
    let fileURL: URL?

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbolName)
                .font(.title3)
                .foregroundStyle(.tint)
                .frame(width: 34, height: 34)
                .background(.tint.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                Text(attachment.originalFilename)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                Text(metadata)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if let fileURL {
                ShareLink(item: fileURL) {
                    Image(systemName: "square.and.arrow.up")
                        .frame(width: 32, height: 32)
                }
                .accessibilityLabel("Share \(attachment.originalFilename)")
            } else {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
                    .accessibilityLabel("File unavailable")
            }
        }
        .accessibilityElement(children: .contain)
    }

    private var symbolName: String {
        guard let type = UTType(attachment.uniformTypeIdentifier) else {
            return "doc"
        }
        if type.conforms(to: .image) {
            return "photo"
        }
        if type.conforms(to: .pdf) {
            return "doc.richtext"
        }
        return "doc"
    }

    private var metadata: String {
        let size = ByteCountFormatter.string(
            fromByteCount: attachment.byteCount,
            countStyle: .file
        )
        return "\(attachment.kind.displayName) · \(size)"
    }
}
