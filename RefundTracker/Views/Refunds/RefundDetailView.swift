import SwiftData
import SwiftUI

struct RefundDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(AppSettings.self) private var settings

    @Bindable var refund: Refund
    @State private var isEditing = false
    @State private var isEditingTracking = false
    @State private var isEditingNotes = false
    @State private var isShowingMoreDetails = false
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
        ZStack {
            RefundBackdrop()

            ScrollView {
                LazyVStack(spacing: 18) {
                    heroCard
                    keyDatesCard

                    if effectiveStatus.isOpen {
                        actionsCard
                    }

                    timelineCard
                    moreDetailsCard
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 36)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle("Refund")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button("Edit") {
                    isEditing = true
                }
                .accessibilityIdentifier("editRefundButton")

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
                .presentationCornerRadius(32)
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

    private var heroCard: some View {
        VStack(spacing: 20) {
            HStack(spacing: 14) {
                MerchantMark(name: refund.retailerName, size: 62)

                Text(refund.retailerName)
                    .font(.title2.weight(.bold))
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)

                Spacer(minLength: 8)
            }

            VStack(spacing: 9) {
                Text("Refund amount")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.7)

                RefundAmountLabel(
                    amount: refund.refundAmount,
                    currencyCode: refund.currencyCode,
                    style: .system(.largeTitle, design: .rounded, weight: .bold)
                )

                RefundStatusBadge(status: effectiveStatus)
            }
            .frame(maxWidth: .infinity)
        }
        .refundGlassCard(
            tint: RefundTheme.color(for: refund.retailerName),
            padding: 22
        )
        .accessibilityElement(children: .contain)
    }

    private var keyDatesCard: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 16) {
                    if let shippedDate = refund.shippedDate {
                        shippedDateSignal(shippedDate)
                        Divider()
                    }

                    expectedDateSignal
                }
            } else {
                HStack(alignment: .top, spacing: 16) {
                    if let shippedDate = refund.shippedDate {
                        shippedDateSignal(shippedDate)

                        Divider()
                            .frame(height: 72)
                    }

                    expectedDateSignal
                }
            }
        }
        .refundGlassCard(tint: statusTint)
    }

    private func shippedDateSignal(_ date: Date) -> some View {
        RefundDateSignal(
            title: "Shipped",
            date: date,
            caption: "Return sent",
            symbolName: "truck.box.fill",
            tint: RefundTheme.blue
        )
    }

    private var expectedDateSignal: some View {
        RefundDateSignal(
            title: "Expected",
            date: refund.expectedRefundDate,
            caption: expectedDateCaption,
            symbolName: effectiveStatus == .overdue
                ? "exclamationmark.calendar.fill"
                : "calendar.badge.clock",
            tint: statusTint
        )
    }

    private var timelineCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            RefundSectionHeading(
                title: "Timeline",
                subtitle: "The milestones that matter",
                symbol: "clock"
            )

            RefundTimelineView(refund: refund)
        }
        .refundGlassCard(tint: RefundTheme.blue)
    }

    private var actionsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            RefundSectionHeading(
                title: "Update refund",
                subtitle: "Keep this record current",
                symbol: "checkmark.circle"
            )

            Button {
                persist { refund.markRefunded() }
            } label: {
                Label("Mark refund received", systemImage: "checkmark.seal.fill")
            }
            .buttonStyle(RefundPrimaryButtonStyle())
            .accessibilityIdentifier("markRefundReceivedButton")

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 130), spacing: 10)],
                spacing: 10
            ) {
                if let workflowAction {
                    Button {
                        workflowAction.perform()
                    } label: {
                        RefundCompactActionLabel(
                            title: workflowAction.title,
                            symbolName: workflowAction.symbol
                        )
                    }
                    .buttonStyle(.bordered)
                    .tint(RefundTheme.blue)
                }

                if effectiveStatus != .disputed {
                    Button {
                        pendingConfirmation = .markDisputed
                    } label: {
                        RefundCompactActionLabel(
                            title: "Dispute",
                            symbolName: "exclamationmark.bubble"
                        )
                    }
                    .buttonStyle(.bordered)
                    .tint(RefundTheme.mango)
                    .accessibilityIdentifier("markRefundDisputedButton")
                }

                Button(role: .destructive) {
                    pendingConfirmation = .cancel
                } label: {
                    RefundCompactActionLabel(
                        title: "Cancel return",
                        symbolName: "xmark.circle"
                    )
                }
                .buttonStyle(.bordered)
                .tint(RefundTheme.coral)
            }
        }
        .refundGlassCard(tint: statusTint)
    }

    private var moreDetailsCard: some View {
        DisclosureGroup(isExpanded: $isShowingMoreDetails) {
            VStack(alignment: .leading, spacing: 18) {
                Divider()

                detailsRows

                Divider()

                HStack(spacing: 10) {
                    Button {
                        isEditingTracking = true
                    } label: {
                        Label(
                            refund.trackingNumber.isEmpty
                                ? "Add tracking"
                                : "Edit tracking",
                            systemImage: "number"
                        )
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("editTrackingButton")

                    Button {
                        isEditingNotes = true
                    } label: {
                        Label(
                            refund.notes.isEmpty ? "Add notes" : "Edit notes",
                            systemImage: "note.text"
                        )
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("editRefundNotesButton")
                }

                if !refund.notes.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Label("Notes", systemImage: "text.quote")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)

                        Text(refund.notes)
                            .font(.subheadline)
                            .textSelection(.enabled)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                Divider()
                attachmentsDetails

                Text(
                    "Last updated \(refund.lastUpdatedDate.formatted(date: .abbreviated, time: .shortened))"
                )
                .font(.caption)
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity, alignment: .center)
            }
            .padding(.top, 8)
        } label: {
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text("More details")
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Text("Tracking, notes, files, and history")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } icon: {
                Image(systemName: "info.circle")
                    .foregroundStyle(RefundTheme.violet)
            }
        }
        .tint(RefundTheme.violet)
        .refundGlassCard(tint: RefundTheme.violet)
    }

    @ViewBuilder
    private var detailsRows: some View {
        if let itemName = refund.userFacingItemName {
            RefundInfoRow("Item", symbol: "bag") {
                Text(itemName)
            }
        }

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
            RefundInfoRow("Purchased", symbol: "cart") {
                Text(purchaseDate, format: detailDateFormat)
            }
        }

        RefundInfoRow("Returned", symbol: "arrow.uturn.backward") {
            Text(refund.returnDate, format: detailDateFormat)
        }

        if let receivedDate = refund.retailerReceivedDate {
            RefundInfoRow("Delivered", symbol: "building.2") {
                Text(receivedDate, format: detailDateFormat)
            }
        }

        if let actualDate = refund.actualRefundDate {
            RefundInfoRow("Refund received", symbol: "checkmark.circle") {
                Text(actualDate, format: detailDateFormat)
                    .foregroundStyle(RefundTheme.mint)
            }
        }

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
    }

    private var attachmentsDetails: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Attachments", systemImage: "paperclip")
                    .font(.subheadline.weight(.semibold))

                Spacer()

                if !sortedAttachments.isEmpty {
                    Text(sortedAttachments.count, format: .number)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.secondary.opacity(0.1), in: Capsule())
                }
            }

            RefundAttachmentPicker(
                onPicked: addAttachment,
                onError: { errorMessage = $0.localizedDescription }
            )

            if sortedAttachments.isEmpty {
                Text("Add a receipt, return confirmation, or screenshot.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(sortedAttachments) { attachment in
                    HStack(spacing: 6) {
                        RefundAttachmentRow(
                            attachment: attachment,
                            fileURL: attachmentStore.fileURL(for: attachment)
                        )
                        .frame(maxWidth: .infinity)

                        Button(role: .destructive) {
                            pendingConfirmation = .deleteAttachment(attachment.id)
                        } label: {
                            Image(systemName: "trash")
                                .frame(width: 38, height: 38)
                        }
                        .accessibilityLabel("Delete \(attachment.originalFilename)")
                    }
                }
            }

            Text("Attachments stay on this device.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    private var detailDateFormat: Date.FormatStyle {
        .dateTime.month(.abbreviated).day().year()
    }

    private var statusTint: Color {
        switch effectiveStatus {
        case .refunded:
            RefundTheme.mint
        case .overdue:
            RefundTheme.coral
        case .disputed:
            RefundTheme.mango
        case .cancelled:
            .gray
        case .preparingReturn, .shipped, .deliveredToRetailer, .refundPending:
            RefundTheme.blue
        }
    }

    private var expectedDateCaption: String {
        switch effectiveStatus {
        case .overdue:
            let days = max(
                Calendar.current.dateComponents(
                    [.day],
                    from: Calendar.current.startOfDay(for: refund.expectedRefundDate),
                    to: Calendar.current.startOfDay(for: .now)
                ).day ?? 0,
                1
            )
            return "\(days) \(days == 1 ? "day" : "days") overdue"
        case .refunded:
            return "Refund completed"
        case .cancelled:
            return "Tracking ended"
        case .disputed:
            return "Follow-up in progress"
        case .preparingReturn, .shipped, .deliveredToRetailer, .refundPending:
            return "Expected refund date"
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

private struct RefundDateSignal: View {
    let title: String
    let date: Date
    let caption: String
    let symbolName: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: symbolName)
                .font(.caption.weight(.semibold))
                .foregroundStyle(tint)

            Text(date, format: .dateTime.month(.abbreviated).day().year())
                .font(.headline)
                .monospacedDigit()

            Text(caption)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "\(title), \(date.formatted(date: .long, time: .omitted)), \(caption)"
        )
    }
}

private struct RefundCompactActionLabel: View {
    let title: String
    let symbolName: String

    var body: some View {
        VStack(spacing: 5) {
            Image(systemName: symbolName)
                .font(.body.weight(.semibold))
                .accessibilityHidden(true)

            Text(title)
                .font(.caption.weight(.semibold))
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, minHeight: 48)
    }
}
