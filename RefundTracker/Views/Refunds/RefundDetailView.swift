import SwiftData
import SwiftUI

struct RefundDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AppSettings.self) private var settings

    @Bindable var refund: Refund
    @State private var isEditing = false
    @State private var isEditingTracking = false
    @State private var isEditingNotes = false
    @State private var pendingConfirmation: Confirmation?
    @State private var isConfirmingDelete = false
    @State private var errorMessage: String?

    private let attachmentStore = AttachmentStore.shared
    private let deleteRecord: ((Refund) throws -> Void)?

    init(
        refund: Refund,
        deleteRecord: ((Refund) throws -> Void)? = nil
    ) {
        self.refund = refund
        self.deleteRecord = deleteRecord
    }

    private enum Confirmation: Identifiable {
        case markDisputed
        case cancel
        case deleteAttachment(UUID)

        var id: String {
            switch self {
            case .markDisputed: "markDisputed"
            case .cancel: "cancel"
            case .deleteAttachment(let id): "deleteAttachment-\(id)"
            }
        }
    }

    private var effectiveStatus: RefundStatus {
        refund.effectiveStatus(on: .now, calendar: .current)
    }

    private var sortedAttachments: [RefundAttachment] {
        refund.attachments.sorted { $0.createdDate > $1.createdDate }
    }

    var body: some View {
        List {
            heroSection

            if effectiveStatus.isOpen {
                actionsSection
            }

            detailsSection

            if hasShippingDetails {
                shippingSection
            }

            timelineSection
            notesSection
            attachmentsSection
            Section {
                Button("Delete refund", systemImage: "trash", role: .destructive) {
                    isConfirmingDelete = true
                }
            }

            Section {
                Text("Last updated \(refund.lastUpdatedDate.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .listRowBackground(Color.clear)
            }
        }
        .navigationTitle(refund.retailerName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Edit") {
                    isEditing = true
                }
                .accessibilityIdentifier("editRefundButton")
            }

            if effectiveStatus != .cancelled && effectiveStatus != .refunded {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("Cancel return", systemImage: "xmark.circle") {
                            pendingConfirmation = .cancel
                        }
                    } label: {
                        Label("More", systemImage: "ellipsis.circle")
                    }
                    .accessibilityIdentifier("refundDetailMoreButton")
                }
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button(role: .destructive) {
                    isConfirmingDelete = true
                } label: {
                    Label("Delete refund", systemImage: "trash")
                }
                .accessibilityIdentifier("deleteRefundButton")
            }
        }
        .sheet(isPresented: $isEditing) {
            RefundFormView(refund: refund)
                .environment(settings)
        }
        .sheet(isPresented: $isEditingTracking) {
            RefundTrackingEditor(
                trackingNumber: refund.trackingNumber,
                carrier: refund.returnCarrier
            ) { number, carrier in
                persist {
                    refund.updateTracking(number: number, carrier: carrier)
                }
            }
        }
        .sheet(isPresented: $isEditingNotes) {
            RefundNotesEditor(notes: refund.notes) { notes in
                persist {
                    refund.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
                    refund.touch()
                }
            }
        }
        .confirmationDialog(
            confirmationTitle,
            isPresented: Binding(
                get: { pendingConfirmation != nil },
                set: { if !$0 { pendingConfirmation = nil } }
            ),
            titleVisibility: .visible
        ) {
            confirmationButtons
        } message: {
            Text(confirmationMessage)
        }
        .alert("Delete this refund?", isPresented: $isConfirmingDelete) {
            Button("Delete", role: .destructive) {
                deleteRefund()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The record and its local attachments will be permanently removed.")
        }
        .alert("Something went wrong", isPresented: errorAlertBinding) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "Please try again.")
        }
    }

    private var heroSection: some View {
        Section {
            VStack(spacing: 10) {
                Text(refund.itemName)
                    .font(.title3.weight(.semibold))
                    .multilineTextAlignment(.center)

                RefundAmountLabel(
                    amount: refund.refundAmount,
                    currencyCode: refund.currencyCode,
                    style: .largeTitle.weight(.bold)
                )

                RefundStatusBadge(status: effectiveStatus)

                Text(expectedSummary)
                    .font(.subheadline)
                    .foregroundStyle(effectiveStatus == .overdue ? .red : .secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
        }
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets())
    }

    private var actionsSection: some View {
        Section("Actions") {
            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 10),
                    GridItem(.flexible(), spacing: 10)
                ],
                spacing: 10
            ) {
                if let workflowAction {
                    RefundDetailActionButton(
                        title: workflowAction.title,
                        symbolName: workflowAction.symbol
                    ) {
                        workflowAction.perform()
                    }
                }

                RefundDetailActionButton(
                    title: "Mark received",
                    symbolName: "checkmark.circle",
                    tint: .green
                ) {
                    persist { refund.markRefunded() }
                }
                .accessibilityIdentifier("markRefundReceivedButton")

                if effectiveStatus != .disputed {
                    RefundDetailActionButton(
                        title: "Dispute",
                        symbolName: "exclamationmark.bubble",
                        tint: .orange
                    ) {
                        pendingConfirmation = .markDisputed
                    }
                    .accessibilityIdentifier("markRefundDisputedButton")
                }

                RefundDetailActionButton(
                    title: refund.trackingNumber.isEmpty ? "Add tracking" : "Edit tracking",
                    symbolName: "number"
                ) {
                    isEditingTracking = true
                }
                .accessibilityIdentifier("editTrackingButton")
            }
            .padding(.vertical, 4)
        }
    }

    private var detailsSection: some View {
        Section("Refund details") {
            if !refund.orderNumber.isEmpty {
                RefundInfoRow("Order number", symbol: "number") {
                    Text(refund.orderNumber)
                        .textSelection(.enabled)
                }
            }

            RefundInfoRow("Method", symbol: refund.refundMethod.iconName) {
                Text(refund.refundMethod.displayName)
            }

            if let purchaseDate = refund.purchaseDate {
                RefundInfoRow("Purchased", symbol: "bag") {
                    Text(purchaseDate, format: .dateTime.month(.abbreviated).day().year())
                }
            }

            RefundInfoRow("Returned", symbol: "arrow.uturn.backward") {
                Text(refund.returnDate, format: .dateTime.month(.abbreviated).day().year())
            }

            RefundInfoRow("Expected", symbol: "calendar") {
                Text(
                    refund.expectedRefundDate,
                    format: .dateTime.month(.abbreviated).day().year()
                )
                .foregroundStyle(effectiveStatus == .overdue ? .red : .primary)
            }

            if let actualDate = refund.actualRefundDate {
                RefundInfoRow("Received", symbol: "checkmark.circle") {
                    Text(actualDate, format: .dateTime.month(.abbreviated).day().year())
                        .foregroundStyle(.green)
                }
            }
        }
    }

    private var shippingSection: some View {
        Section("Return shipping") {
            if !refund.returnCarrier.isEmpty {
                RefundInfoRow("Carrier", symbol: "truck.box") {
                    Text(refund.returnCarrier)
                }
            }
            if !refund.trackingNumber.isEmpty {
                RefundInfoRow("Tracking", symbol: "number") {
                    Text(refund.trackingNumber)
                        .font(.body.monospaced())
                        .textSelection(.enabled)
                }
            }
            if let shippedDate = refund.shippedDate {
                RefundInfoRow("Shipped", symbol: "shippingbox") {
                    Text(shippedDate, format: .dateTime.month(.abbreviated).day().year())
                }
            }
            if let receivedDate = refund.retailerReceivedDate {
                RefundInfoRow("Delivered", symbol: "building.2") {
                    Text(receivedDate, format: .dateTime.month(.abbreviated).day().year())
                }
            }

            Button(refund.trackingNumber.isEmpty ? "Add tracking details" : "Update tracking details") {
                isEditingTracking = true
            }
        }
    }

    private var timelineSection: some View {
        Section("Timeline") {
            RefundTimelineView(refund: refund)
                .padding(.vertical, 4)
        }
    }

    private var notesSection: some View {
        Section {
            if refund.notes.isEmpty {
                Text("Add confirmation details or a record of follow-up conversations.")
                    .foregroundStyle(.secondary)
                    .italic()
            } else {
                Text(refund.notes)
                    .textSelection(.enabled)
            }

            Button(refund.notes.isEmpty ? "Add notes" : "Edit notes") {
                isEditingNotes = true
            }
            .accessibilityIdentifier("editRefundNotesButton")
        } header: {
            Text("Notes")
        }
    }

    private var attachmentsSection: some View {
        Section {
            RefundAttachmentPicker(
                onPicked: addAttachment,
                onError: { errorMessage = $0.localizedDescription }
            )
            .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))

            ForEach(sortedAttachments) { attachment in
                RefundAttachmentRow(
                    attachment: attachment,
                    fileURL: attachmentStore.fileURL(for: attachment)
                )
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button("Delete", systemImage: "trash", role: .destructive) {
                        pendingConfirmation = .deleteAttachment(attachment.id)
                    }
                }
            }
        } header: {
            Text("Attachments")
        } footer: {
            Text("Receipts and screenshots stay on this device.")
        }
    }

    private var hasShippingDetails: Bool {
        !refund.trackingNumber.isEmpty
            || !refund.returnCarrier.isEmpty
            || refund.shippedDate != nil
            || refund.retailerReceivedDate != nil
    }

    private var expectedSummary: String {
        switch effectiveStatus {
        case .refunded:
            if let actualDate = refund.actualRefundDate {
                return "Received \(actualDate.formatted(date: .long, time: .omitted))"
            }
            return "Refund received"
        case .overdue:
            let days = max(
                Calendar.current.dateComponents(
                    [.day],
                    from: Calendar.current.startOfDay(for: refund.expectedRefundDate),
                    to: Calendar.current.startOfDay(for: .now)
                ).day ?? 0,
                1
            )
            return "\(days) \(days == 1 ? "day" : "days") overdue · expected \(refund.expectedRefundDate.formatted(date: .abbreviated, time: .omitted))"
        case .cancelled:
            return "This return is no longer being tracked"
        default:
            return "Expected \(refund.expectedRefundDate.formatted(date: .long, time: .omitted))"
        }
    }

    private var workflowAction: (title: String, symbol: String, perform: () -> Void)? {
        switch refund.status {
        case .preparingReturn:
            return (
                "Mark shipped",
                "truck.box",
                { persist { refund.markShipped() } }
            )
        case .shipped:
            return (
                "Mark delivered",
                "shippingbox.and.arrow.backward",
                { persist { refund.markDelivered() } }
            )
        case .deliveredToRetailer:
            return (
                "Refund pending",
                "clock.arrow.circlepath",
                { persist { refund.markRefundPending() } }
            )
        case .refundPending, .overdue, .disputed, .refunded, .cancelled:
            return nil
        }
    }

    @ViewBuilder
    private var confirmationButtons: some View {
        switch pendingConfirmation {
        case .markDisputed:
            Button("Mark as Disputed") {
                pendingConfirmation = nil
                persist { refund.markDisputed() }
            }
        case .cancel:
            Button("Cancel Return", role: .destructive) {
                pendingConfirmation = nil
                persist { refund.markCancelled() }
            }
        case .deleteAttachment:
            Button("Delete Attachment", role: .destructive) {
                deletePendingAttachment()
            }
        case nil:
            EmptyView()
        }

        Button("Keep", role: .cancel) {
            pendingConfirmation = nil
        }
    }

    private var confirmationTitle: String {
        switch pendingConfirmation {
        case .markDisputed: "Mark this refund as disputed?"
        case .cancel: "Cancel this return?"
        case .deleteAttachment: "Delete this attachment?"
        case nil: ""
        }
    }

    private var confirmationMessage: String {
        switch pendingConfirmation {
        case .markDisputed:
            "Use disputed when you have contacted the retailer or payment provider about a missing refund."
        case .cancel:
            "Cancelled returns are kept in your history and reminders stop."
        case .deleteAttachment:
            "The local file will be permanently removed."
        case nil:
            ""
        }
    }

    private var errorAlertBinding: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )
    }

    private func persist(_ mutation: () -> Void) {
        mutation()
        do {
            try modelContext.save()
            rescheduleNotifications()
        } catch {
            modelContext.rollback()
            errorMessage = error.localizedDescription
        }
    }

    private func addAttachment(_ payload: RefundAttachmentPayload) {
        do {
            let attachment = try attachmentStore.store(
                data: payload.data,
                originalFilename: payload.originalFilename,
                uniformTypeIdentifier: payload.contentType.identifier,
                kind: payload.kind
            )
            modelContext.insert(attachment)
            refund.addAttachment(attachment)

            do {
                try modelContext.save()
            } catch {
                try? attachmentStore.delete(attachment)
                modelContext.rollback()
                throw error
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func deletePendingAttachment() {
        guard case .deleteAttachment(let id) = pendingConfirmation,
              let attachment = refund.attachments.first(where: { $0.id == id })
        else {
            pendingConfirmation = nil
            return
        }
        pendingConfirmation = nil

        refund.removeAttachment(attachment)
        modelContext.delete(attachment)
        do {
            try modelContext.save()
            try attachmentStore.delete(attachment)
        } catch {
            modelContext.rollback()
            errorMessage = error.localizedDescription
        }
    }

    private func deleteRefund() {
        let storedFilenames = refund.attachments.map(\.storedFilename)
        let refundID = refund.id
        do {
            if let deleteRecord {
                try deleteRecord(refund)
            } else {
                modelContext.delete(refund)
                modelContext.processPendingChanges()
                try modelContext.save()
            }
            NotificationService.shared.cancelNotifications(for: refundID)
            try? attachmentStore.deleteFiles(named: storedFilenames)
            NotificationCenter.default.post(
                name: .refundDataDidChange,
                object: nil
            )
            dismiss()
        } catch {
            modelContext.rollback()
            errorMessage = error.localizedDescription
        }
    }

    private func rescheduleNotifications() {
        Task { @MainActor in
            do {
                try await NotificationService.shared.scheduleNotifications(
                    for: refund,
                    preferences: settings.notificationPreferences
                )
            } catch {
                errorMessage =
                    "The refund was saved, but reminders couldn’t be updated. \(error.localizedDescription)"
            }
        }
    }
}
