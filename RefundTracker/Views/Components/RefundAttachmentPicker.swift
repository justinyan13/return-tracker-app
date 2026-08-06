import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

struct RefundAttachmentPayload {
    let data: Data
    let originalFilename: String
    let contentType: UTType
    let kind: AttachmentKind
}

struct RefundAttachmentPicker: View {
    let onPicked: (RefundAttachmentPayload) -> Void
    let onError: (Error) -> Void

    @State private var selectedPhoto: PhotosPickerItem?
    @State private var isImportingFile = false
    @State private var isLoading = false

    var body: some View {
        HStack(spacing: 12) {
            PhotosPicker(selection: $selectedPhoto, matching: .images) {
                Label("Photo", systemImage: "photo")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(isLoading)
            .accessibilityIdentifier("addPhotoAttachmentButton")

            Button {
                isImportingFile = true
            } label: {
                Label("File", systemImage: "doc")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(isLoading)
            .accessibilityIdentifier("addFileAttachmentButton")
        }
        .overlay {
            if isLoading {
                ProgressView()
                    .padding(8)
                    .background(.regularMaterial, in: Circle())
                    .accessibilityLabel("Adding attachment")
            }
        }
        .fileImporter(
            isPresented: $isImportingFile,
            allowedContentTypes: [.image, .pdf, .plainText, .data],
            allowsMultipleSelection: false,
            onCompletion: handleFileImport
        )
        .onChange(of: selectedPhoto) { _, newItem in
            guard let newItem else { return }
            Task { await handlePhotoImport(newItem) }
        }
    }

    private func handleFileImport(_ result: Result<[URL], Error>) {
        do {
            guard let url = try result.get().first else { return }
            let didAccess = url.startAccessingSecurityScopedResource()
            defer {
                if didAccess {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            let resourceValues = try url.resourceValues(
                forKeys: [.contentTypeKey, .fileSizeKey]
            )
            if let fileSize = resourceValues.fileSize, fileSize > Self.maximumByteCount {
                throw RefundAttachmentPickerError.fileTooLarge
            }

            let data = try Data(contentsOf: url, options: .mappedIfSafe)
            let type = resourceValues.contentType
                ?? UTType(filenameExtension: url.pathExtension)
                ?? .data
            onPicked(
                RefundAttachmentPayload(
                    data: data,
                    originalFilename: url.lastPathComponent,
                    contentType: type,
                    kind: inferredKind(for: type)
                )
            )
        } catch {
            onError(error)
        }
    }

    @MainActor
    private func handlePhotoImport(_ item: PhotosPickerItem) async {
        isLoading = true
        defer {
            isLoading = false
            selectedPhoto = nil
        }

        do {
            guard let data = try await item.loadTransferable(type: Data.self) else {
                throw RefundAttachmentPickerError.unreadablePhoto
            }
            guard data.count <= Self.maximumByteCount else {
                throw RefundAttachmentPickerError.fileTooLarge
            }

            let type = item.supportedContentTypes.first ?? .image
            let fileExtension = type.preferredFilenameExtension ?? "jpg"
            let timestamp = Date.now.formatted(
                .iso8601.year().month().day().time(includingFractionalSeconds: false)
            )
            onPicked(
                RefundAttachmentPayload(
                    data: data,
                    originalFilename: "Screenshot \(timestamp).\(fileExtension)",
                    contentType: type,
                    kind: .screenshot
                )
            )
        } catch {
            onError(error)
        }
    }

    private func inferredKind(for type: UTType) -> AttachmentKind {
        if type.conforms(to: .image) {
            return .screenshot
        }
        return .other
    }

    private static let maximumByteCount = 25 * 1_024 * 1_024
}

private enum RefundAttachmentPickerError: LocalizedError {
    case fileTooLarge
    case unreadablePhoto

    var errorDescription: String? {
        switch self {
        case .fileTooLarge:
            "Choose a file smaller than 25 MB."
        case .unreadablePhoto:
            "The selected photo could not be read."
        }
    }
}
