import Foundation
import UniformTypeIdentifiers

enum AttachmentStoreError: LocalizedError {
    case fileTooLarge(maximumBytes: Int64)
    case unreadableFile
    case attachmentNotFound

    var errorDescription: String? {
        switch self {
        case .fileTooLarge(let maximumBytes):
            "The attachment is larger than the \(maximumBytes / 1_048_576) MB limit."
        case .unreadableFile:
            "The selected file could not be read."
        case .attachmentNotFound:
            "The attachment file is no longer available."
        }
    }
}

/// Stores only file metadata in SwiftData. Attachment bytes live in Application
/// Support so screenshots and receipts do not inflate the model store.
@MainActor
final class AttachmentStore {
    static let shared = AttachmentStore()
    static let maximumFileSize: Int64 = 25 * 1_048_576

    let baseDirectory: URL
    private let fileManager: FileManager

    init(
        baseDirectory: URL? = nil,
        fileManager: FileManager = .default
    ) {
        self.fileManager = fileManager

        if let baseDirectory {
            self.baseDirectory = baseDirectory
        } else {
            let applicationSupport = fileManager.urls(
                for: .applicationSupportDirectory,
                in: .userDomainMask
            ).first ?? fileManager.temporaryDirectory
            self.baseDirectory = applicationSupport
                .appendingPathComponent("RefundTracker", isDirectory: true)
                .appendingPathComponent("Attachments", isDirectory: true)
        }
    }

    func importFile(
        from sourceURL: URL,
        kind: AttachmentKind = .other
    ) throws -> RefundAttachment {
        let accessed = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if accessed {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }

        guard fileManager.isReadableFile(atPath: sourceURL.path) else {
            throw AttachmentStoreError.unreadableFile
        }

        let values = try sourceURL.resourceValues(forKeys: [
            .fileSizeKey,
            .nameKey,
            .contentTypeKey
        ])
        let attributes = try? fileManager.attributesOfItem(
            atPath: sourceURL.path
        )
        let fallbackSize = (attributes?[.size] as? NSNumber)?.int64Value ?? 0
        let byteCount = values.fileSize.map(Int64.init) ?? fallbackSize
        guard byteCount <= Self.maximumFileSize else {
            throw AttachmentStoreError.fileTooLarge(
                maximumBytes: Self.maximumFileSize
            )
        }

        try ensureDirectoryExists()

        let originalFilename = values.name ?? sourceURL.lastPathComponent
        let pathExtension = sourceURL.pathExtension
        let storedFilename = pathExtension.isEmpty
            ? UUID().uuidString
            : "\(UUID().uuidString).\(pathExtension.lowercased())"
        let destination = baseDirectory.appendingPathComponent(storedFilename)

        try fileManager.copyItem(at: sourceURL, to: destination)

        return RefundAttachment(
            originalFilename: originalFilename,
            storedFilename: storedFilename,
            uniformTypeIdentifier: values.contentType?.identifier ??
                UTType(filenameExtension: pathExtension)?.identifier ??
                UTType.data.identifier,
            byteCount: byteCount,
            kind: kind
        )
    }

    func store(
        data: Data,
        originalFilename: String,
        uniformTypeIdentifier: String = UTType.data.identifier,
        kind: AttachmentKind = .other
    ) throws -> RefundAttachment {
        guard Int64(data.count) <= Self.maximumFileSize else {
            throw AttachmentStoreError.fileTooLarge(
                maximumBytes: Self.maximumFileSize
            )
        }

        try ensureDirectoryExists()

        let type = UTType(uniformTypeIdentifier)
        let suppliedExtension = URL(fileURLWithPath: originalFilename).pathExtension
        let pathExtension = suppliedExtension.isEmpty
            ? type?.preferredFilenameExtension ?? ""
            : suppliedExtension
        let storedFilename = pathExtension.isEmpty
            ? UUID().uuidString
            : "\(UUID().uuidString).\(pathExtension.lowercased())"
        let destination = baseDirectory.appendingPathComponent(storedFilename)

        try data.write(to: destination, options: [.atomic, .completeFileProtection])

        return RefundAttachment(
            originalFilename: originalFilename,
            storedFilename: storedFilename,
            uniformTypeIdentifier: uniformTypeIdentifier,
            byteCount: Int64(data.count),
            kind: kind
        )
    }

    func fileURL(for attachment: RefundAttachment) -> URL? {
        let url = baseDirectory.appendingPathComponent(attachment.storedFilename)
        return fileManager.fileExists(atPath: url.path) ? url : nil
    }

    func requireFileURL(for attachment: RefundAttachment) throws -> URL {
        guard let url = fileURL(for: attachment) else {
            throw AttachmentStoreError.attachmentNotFound
        }
        return url
    }

    func delete(_ attachment: RefundAttachment) throws {
        let url = baseDirectory.appendingPathComponent(attachment.storedFilename)
        guard fileManager.fileExists(atPath: url.path) else { return }
        try fileManager.removeItem(at: url)
    }

    func deleteFiles(for attachments: [RefundAttachment]) throws {
        try deleteFiles(named: attachments.map(\.storedFilename))
    }

    /// Deletes attachment bytes using value-type filenames captured before a
    /// SwiftData cascade invalidates the related model objects.
    func deleteFiles(named storedFilenames: [String]) throws {
        for storedFilename in storedFilenames {
            let url = baseDirectory.appendingPathComponent(storedFilename)
            guard fileManager.fileExists(atPath: url.path) else { continue }
            try fileManager.removeItem(at: url)
        }
    }

    private func ensureDirectoryExists() throws {
        try fileManager.createDirectory(
            at: baseDirectory,
            withIntermediateDirectories: true,
            attributes: [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication]
        )
    }
}
