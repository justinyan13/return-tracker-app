import SwiftUI
import UniformTypeIdentifiers

struct RefundAttachmentRow: View {
    let attachment: RefundAttachment
    let fileURL: URL?

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbolName)
                .font(.system(.footnote))
                .foregroundStyle(RefundTheme.ink)
                .frame(width: 34, height: 34)
                .background(RefundTheme.sand)

            VStack(alignment: .leading, spacing: 3) {
                Text(attachment.originalFilename)
                    .font(.system(.footnote))
                    .foregroundStyle(RefundTheme.ink)
                    .lineLimit(1)
                Text(metadata)
                    .eyebrow(size: 9)
            }

            Spacer()

            if let fileURL {
                ShareLink(item: fileURL) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(.footnote))
                        .foregroundStyle(RefundTheme.inkSoft)
                        .frame(width: 32, height: 32)
                }
                .accessibilityLabel("Share \(attachment.originalFilename)")
            } else {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(.footnote))
                    .foregroundStyle(RefundTheme.alert)
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
