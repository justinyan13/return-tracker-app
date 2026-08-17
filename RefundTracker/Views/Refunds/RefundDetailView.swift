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
                LazyVStack(alignment: .leading, spacing: 0) {
                    header
                    amountBlock
                    keyDates

                    if effectiveStatus.isOpen {
                        actionsSection
                    }

                    timelineSection
                    moreDetailsSection
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 44)
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
                .presentationCornerRadius(6)
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

    private var header: some View {
        HStack(alignment: .top, spacing: 16) {
            RefundCoverMark(emoji: refund.displayCoverEmoji, size: 52)
                .accessibilityIdentifier("refundDetailCoverEmoji")

            VStack(alignment: .leading, spacing: 8) {
                Text(refund.retailerName)
                    .serif(26, relativeTo: .title)
                    .foregroundStyle(RefundTheme.ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)

                RefundStatusBadge(status: effectiveStatus)
            }

            Spacer(minLength: 0)
        }
        .padding(.top, 6)
    }

    private var amountBlock: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Refund amount")
                .eyebrow()

            RefundAmountLabel(
                amount: refund.refundAmount,
                currencyCode: refund.currencyCode,
                size: 44,
                relativeTo: .largeTitle
            )
            .padding(.top, 8)

            if let itemName = refund.userFacingItemName {
                Text(itemName)
                    .font(.system(.subheadline))
                    .foregroundStyle(RefundTheme.inkSoft)
                    .padding(.top, 6)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 34)
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private var keyDates: some View {
        let leading = leadingDateSignal

        VStack(alignment: .leading, spacing: 0) {
            Hairline()
                .padding(.top, 28)

            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 20) {
                    if let leading {
                        leading
                    }
                    expectedDateSignal
                }
                .padding(.vertical, 20)
            } else {
                HStack(alignment: .top, spacing: 20) {
                    if let leading {
                        leading
                        VerticalHairline(height: 56)
                    }
                    expectedDateSignal
                }
                .padding(.vertical, 20)
            }

            Hairline()
        }
    }

    private var leadingDateSignal: RefundDateSignal? {
        if let shipByDate = refund.shipByDate, refund.isAwaitingShipment {
            let isLate = refund.isShipmentOverdue()
            return RefundDateSignal(
                title: "Send by",
                date: shipByDate,
                caption: isLate ? "Past the deadline" : "Not sent yet",
                isLate: isLate
            )
        }

        if let shippedDate = refund.shippedDate {
            return RefundDateSignal(
                title: "Shipped",
                date: shippedDate,
                caption: "Return sent"
            )
        }

        return nil
    }

    private var expectedDateSignal: RefundDateSignal {
        RefundDateSignal(
            title: "Expected",
            date: refund.expectedRefundDate,
            caption: expectedDateCaption,
            isLate: effectiveStatus == .overdue
        )
    }

    private var timelineSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            RefundSectionHeading(title: "Timeline")

            RefundTimelineView(refund: refund)
        }
        .padding(.top, 40)
    }

    private var actionsSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            RefundSectionHeading(title: "Update")

            Button("Mark refund received") {
                persist { refund.markRefunded() }
            }
            .buttonStyle(RefundPrimaryButtonStyle())
            .accessibilityIdentifier("markRefundReceivedButton")

            // Two per row, so a lone secondary action still spans the width
            // instead of sitting as a half-width block beside empty paper.
            LazyVGrid(
                columns: Array(
                    repeating: GridItem(.flexible(), spacing: 10),
                    count: min(secondaryActionCount, 2)
                ),
                spacing: 10
            ) {
                if let workflowAction {
                    Button(workflowAction.title) {
                        workflowAction.perform()
                    }
                    .buttonStyle(RefundSecondaryButtonStyle())
                }

                if effectiveStatus != .disputed {
                    Button("Dispute") {
                        pendingConfirmation = .markDisputed
                    }
                    .buttonStyle(RefundSecondaryButtonStyle())
                    .accessibilityIdentifier("markRefundDisputedButton")
                }

                Button("Cancel return") {
                    pendingConfirmation = .cancel
                }
                .buttonStyle(
                    RefundSecondaryButtonStyle(tint: RefundTheme.alert)
                )
            }
        }
        .padding(.top, 40)
    }

    private var moreDetailsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Hairline()
                .padding(.top, 40)

            DisclosureGroup(isExpanded: $isShowingMoreDetails) {
                VStack(alignment: .leading, spacing: 0) {
                    detailsRows

                    Hairline()
                        .padding(.top, 12)

                    HStack(spacing: 10) {
                        Button(
                            refund.trackingNumber.isEmpty
                                ? "Add tracking"
                                : "Edit tracking"
                        ) {
                            isEditingTracking = true
                        }
                        .buttonStyle(RefundSecondaryButtonStyle())
                        .accessibilityIdentifier("editTrackingButton")

                        Button(refund.notes.isEmpty ? "Add notes" : "Edit notes") {
                            isEditingNotes = true
                        }
                        .buttonStyle(RefundSecondaryButtonStyle())
                        .accessibilityIdentifier("editRefundNotesButton")
                    }
                    .padding(.top, 22)

                    if !refund.notes.isEmpty {
                        VStack(alignment: .leading, spacing: 7) {
                            Text("Notes")
                                .eyebrow(size: 10)

                            Text(refund.notes)
                                .font(.system(.subheadline))
                                .foregroundStyle(RefundTheme.ink)
                                .textSelection(.enabled)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 24)
                    }

                    attachmentsDetails
                        .padding(.top, 30)

                    Text(
                        "Last updated \(refund.lastUpdatedDate.formatted(date: .abbreviated, time: .shortened))"
                    )
                    .eyebrow(size: 9)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 30)
                }
                .padding(.top, 14)
            } label: {
                VStack(alignment: .leading, spacing: 3) {
                    Text("More details")
                        .font(.system(.subheadline).weight(.medium))
                        .foregroundStyle(RefundTheme.ink)

                    Text("Tracking, notes, files, and history")
                        .font(.system(.caption))
                        .foregroundStyle(RefundTheme.inkSoft)
                }
            }
            .tint(RefundTheme.inkSoft)
            .padding(.vertical, 18)

            Hairline()
        }
    }

    @ViewBuilder
    private var detailsRows: some View {
        if let itemName = refund.userFacingItemName {
            RefundInfoRow("Item") {
                Text(itemName)
            }
        }

        if !refund.orderNumber.isEmpty {
            RefundInfoRow("Order number") {
                Text(refund.orderNumber)
                    .textSelection(.enabled)
            }
        }

        RefundInfoRow("Method") {
            Text(refund.refundMethod.displayName)
        }

        if let purchaseDate = refund.purchaseDate {
            RefundInfoRow("Purchased") {
                Text(purchaseDate, format: detailDateFormat)
            }
        }

        RefundInfoRow("Returned") {
            Text(refund.returnDate, format: detailDateFormat)
        }

        if let receivedDate = refund.retailerReceivedDate {
            RefundInfoRow("Delivered") {
                Text(receivedDate, format: detailDateFormat)
            }
        }

        if let actualDate = refund.actualRefundDate {
            RefundInfoRow("Refund received") {
                Text(actualDate, format: detailDateFormat)
                    .foregroundStyle(RefundTheme.success)
            }
        }

        if !refund.returnCarrier.isEmpty {
            RefundInfoRow("Carrier") {
                Text(refund.returnCarrier)
            }
        }

        if !refund.trackingNumber.isEmpty {
            RefundInfoRow("Tracking") {
                Text(refund.trackingNumber)
                    .font(.system(.footnote).monospaced())
                    .textSelection(.enabled)
            }
        }
    }

    private var attachmentsDetails: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Attachments")
                    .eyebrow(size: 10)

                Spacer()

                if !sortedAttachments.isEmpty {
                    Text(sortedAttachments.count, format: .number)
                        .serif(13, relativeTo: .footnote)
                        .foregroundStyle(RefundTheme.inkSoft)
                }
            }

            RefundAttachmentPicker(
                onPicked: addAttachment,
                onError: { errorMessage = $0.localizedDescription }
            )

            if sortedAttachments.isEmpty {
                Text("Add a receipt, return confirmation, or screenshot.")
                    .font(.system(.footnote))
                    .foregroundStyle(RefundTheme.inkSoft)
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
                                .font(.system(.footnote))
                                .foregroundStyle(RefundTheme.alert)
                                .frame(width: 38, height: 38)
                        }
                        .accessibilityLabel("Delete \(attachment.originalFilename)")
                    }
                }
            }

            Text("Attachments stay on this device.")
                .eyebrow(size: 9)
        }
    }

    private var detailDateFormat: Date.FormatStyle {
        .dateTime.day().month(.abbreviated).year()
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

    private var secondaryActionCount: Int {
        1 + (workflowAction == nil ? 0 : 1) + (effectiveStatus == .disputed ? 0 : 1)
    }

    private var workflowAction: (title: String, perform: () -> Void)? {
        switch refund.status {
        case .preparingReturn:
            return (
                "Mark shipped",
                {
                    // The expected refund date was projected off the ship-by
                    // deadline; now that it has actually gone out, re-anchor
                    // it to the real date.
                    let shippedOn = Date.now
                    persist {
                        refund.markShipped(
                            on: shippedOn,
                            expectedRefundDate: BusinessDayCalculator
                                .addingBusinessDays(
                                    settings.defaultExpectedRefundBusinessDays,
                                    to: Calendar.current.startOfDay(for: shippedOn)
                                )
                        )
                    }
                }
            )
        case .shipped:
            return (
                "Mark delivered",
                { persist { refund.markDelivered() } }
            )
        case .deliveredToRetailer:
            return (
                "Refund pending",
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

        // Captured before the delete: once the row is gone the model is
        // invalidated, and reading `storedFilename` off it traps.
        let storedFilename = attachment.storedFilename

        refund.removeAttachment(attachment)
        modelContext.delete(attachment)
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            errorMessage = error.localizedDescription
            return
        }

        // The row is already gone; a failed file removal leaves orphaned bytes
        // but nothing the user can act on, so it must not roll the delete back.
        try? attachmentStore.deleteFiles(named: [storedFilename])
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
    var isLate = false

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .eyebrow(size: 10)

            Text(date, format: .dateTime.day().month(.abbreviated).year())
                .serif(17, relativeTo: .body)
                .foregroundStyle(RefundTheme.ink)

            Text(caption)
                .font(.system(.caption))
                .foregroundStyle(isLate ? RefundTheme.alert : RefundTheme.inkSoft)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "\(title), \(date.formatted(date: .long, time: .omitted)), \(caption)"
        )
    }
}
