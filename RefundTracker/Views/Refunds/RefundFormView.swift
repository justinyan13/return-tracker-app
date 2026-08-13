import SwiftData
import SwiftUI

struct RefundFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AppSettings.self) private var settings
    @Query private var allRefunds: [Refund]

    private let refund: Refund?
    @State private var viewModel: RefundFormViewModel
    @State private var didAttemptSave = false
    @State private var didApplySettings = false
    @State private var isChoosingCoverEmoji = false
    @State private var isChoosingCurrency = false
    @State private var saveErrorMessage: String?
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case merchant
        case item
        case amount
    }

    init(refund: Refund? = nil) {
        self.refund = refund
        _viewModel = State(initialValue: RefundFormViewModel(refund: refund))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                RefundBackdrop()

                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            header

                            // Asked first: the answer decides whether the date
                            // below is a record of what happened or a deadline
                            // still to meet.
                            if viewModel.canChooseShipmentState {
                                shipmentStateField
                            }

                            merchantField
                            itemField
                            amountField
                            trackedDateField

                            if didAttemptSave && !viewModel.validationMessages.isEmpty {
                                validationNotice
                            }

                            saveButton
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 8)
                        // Slack to scroll into when a field near the bottom
                        // takes focus.
                        .padding(.bottom, focusedField == nil ? 32 : 200)
                    }
                    .scrollDismissesKeyboard(.interactively)
                    // Lifting the focused field up keeps the fields *below* it
                    // above the keyboard, so the next one stays tappable.
                    //
                    // The anchor is deliberately not `.top`: the scroll view
                    // runs underneath the navigation bar, so aligning to the
                    // very top slides the field up behind the title. This sits
                    // it just clear of that.
                    .onChange(of: focusedField) { _, newValue in
                        guard let newValue else { return }
                        withAnimation(.easeOut(duration: 0.25)) {
                            proxy.scrollTo(
                                newValue,
                                anchor: UnitPoint(x: 0.5, y: 0.14)
                            )
                        }
                    }
                }
            }
            .navigationTitle(refund == nil ? "Add refund" : "Edit refund")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        focusedField = nil
                    }
                }
            }
            .interactiveDismissDisabled(hasUnsavedContent)
            .sheet(isPresented: $isChoosingCoverEmoji) {
                RefundCoverEmojiPicker(selection: $viewModel.coverEmoji)
                    .presentationDragIndicator(.visible)
                    .presentationCornerRadius(6)
            }
            .sheet(isPresented: $isChoosingCurrency) {
                NavigationStack {
                    CurrencyPickerView(
                        selection: currencyBinding,
                        title: "Currency"
                    )
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") {
                                isChoosingCurrency = false
                            }
                        }
                    }
                }
                .tint(RefundTheme.ink)
                .presentationCornerRadius(6)
            }
            .onAppear {
                applySettingsIfNeeded()
            }
            .alert("Couldn’t save refund", isPresented: saveErrorBinding) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(saveErrorMessage ?? "Please try again.")
            }
        }
        .tint(RefundTheme.ink)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(refund == nil ? "New return" : "Editing")
                .eyebrow()

            Text(refund == nil ? "What went back?" : "Update the details")
                .serif(28, relativeTo: .title)
                .foregroundStyle(RefundTheme.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, 30)
    }

    /// The cover lives beside the item it covers rather than in a row of its
    /// own: the tile alone is the control, no label needed.
    private var coverEmojiButton: some View {
        Button {
            focusedField = nil
            isChoosingCoverEmoji = true
        } label: {
            RefundCoverMark(emoji: viewModel.coverEmoji, size: 40)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Return cover emoji")
        .accessibilityValue(viewModel.coverEmoji)
        .accessibilityHint("Opens the emoji picker")
        .accessibilityIdentifier("coverEmojiPickerButton")
    }

    private var shipmentStateField: some View {
        RefundFormField(label: "Return status") {
            HStack(spacing: 24) {
                RefundChoice(
                    title: "Already sent",
                    isSelected: viewModel.hasShipped
                ) {
                    viewModel.hasShipped = true
                }

                RefundChoice(
                    title: "Still to send",
                    isSelected: !viewModel.hasShipped
                ) {
                    viewModel.hasShipped = false
                }

                Spacer(minLength: 0)
            }
            .padding(.vertical, 4)
            .accessibilityIdentifier("shipmentStatePicker")
        }
    }

    private var merchantField: some View {
        RefundFormField(label: "Merchant") {
            TextField("Where it came from", text: $viewModel.retailerName)
                .textContentType(.organizationName)
                .textInputAutocapitalization(.words)
                .submitLabel(.next)
                .focused($focusedField, equals: .merchant)
                .onSubmit { focusedField = .item }
                .font(.system(.body))
                .accessibilityIdentifier("retailerField")
        }
        .id(Field.merchant)
    }

    private var itemField: some View {
        RefundFormField(label: "Item") {
            HStack(spacing: 12) {
                coverEmojiButton

                TextField(
                    "Optional — what you returned",
                    text: $viewModel.itemName
                )
                .textInputAutocapitalization(.sentences)
                .submitLabel(.next)
                .focused($focusedField, equals: .item)
                .onSubmit { focusedField = .amount }
                .font(.system(.body))
                .accessibilityIdentifier("itemField")
                .accessibilityLabel("Item name, optional")
            }
        }
        .id(Field.item)
    }

    private var amountField: some View {
        RefundFormField(label: "Amount") {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                // Per-refund only: picking here never rewrites the default in
                // Settings.
                Button {
                    focusedField = nil
                    isChoosingCurrency = true
                } label: {
                    HStack(spacing: 4) {
                        Text(viewModel.currencyCode)
                            .eyebrow(size: 12, color: RefundTheme.inkSoft)

                        Image(systemName: "chevron.down")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(RefundTheme.inkFaint)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Currency \(viewModel.currencyCode)")
                .accessibilityHint("Sets the currency for this refund only")
                .accessibilityIdentifier("currencyChip")

                TextField("0.00", text: $viewModel.amountText)
                    .keyboardType(.decimalPad)
                    .serif(30, relativeTo: .largeTitle)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .contentShape(Rectangle())
                    .focused($focusedField, equals: .amount)
                    .accessibilityLabel("Refund amount")
                    .accessibilityIdentifier("amountField")
            }
            .padding(.bottom, 2)
        }
        .id(Field.amount)
    }

    private var trackedDateField: some View {
        RefundFormField(label: viewModel.trackedDateTitle) {
            DatePicker(
                viewModel.trackedDateTitle,
                selection: Binding(
                    get: { viewModel.returnDate },
                    set: viewModel.setTrackedDate
                ),
                in: viewModel.trackedDateRange,
                displayedComponents: .date
            )
            .datePickerStyle(.compact)
            .labelsHidden()
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 2)
            .accessibilityIdentifier("returnDatePicker")
        }
    }

    private var validationNotice: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(viewModel.validationMessages, id: \.self) { message in
                Text(message)
                    .font(.system(.footnote))
                    .foregroundStyle(RefundTheme.alert)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 26)
        .accessibilityElement(children: .combine)
    }

    private var saveButton: some View {
        Button(refund == nil ? "Track refund" : "Save changes") {
            save()
        }
        .buttonStyle(RefundPrimaryButtonStyle())
        .padding(.top, 34)
        .accessibilityIdentifier("saveRefundButton")
    }

    private var currencyBinding: Binding<String> {
        Binding(
            get: { viewModel.currencyCode },
            set: { viewModel.setCurrencyCode($0) }
        )
    }

    private var saveErrorBinding: Binding<Bool> {
        Binding(
            get: { saveErrorMessage != nil },
            set: { if !$0 { saveErrorMessage = nil } }
        )
    }

    private var hasUnsavedContent: Bool {
        !viewModel.retailerName.isEmpty
            || !viewModel.itemName.isEmpty
            || !viewModel.amountText.isEmpty
            || refund != nil
    }

    private func save() {
        didAttemptSave = true
        guard viewModel.isValid else {
            focusedField = nil
            return
        }

        let isNew = refund == nil
        let isFirstTrackedRefund = isNew && allRefunds.isEmpty
        let target = refund ?? Refund()
        viewModel.apply(to: target)

        if isNew {
            modelContext.insert(target)
        }

        do {
            try modelContext.save()
            updateNotifications(
                for: target,
                requestPermission: isFirstTrackedRefund
            )
            dismiss()
        } catch {
            modelContext.rollback()
            saveErrorMessage = error.localizedDescription
        }
    }

    private func applySettingsIfNeeded() {
        guard !didApplySettings else { return }
        didApplySettings = true
        viewModel.applySettings(
            expectedBusinessDays: settings.defaultExpectedRefundBusinessDays,
            defaultCurrencyCode: settings.defaultCurrencyCode
        )
    }

    private func updateNotifications(
        for refund: Refund,
        requestPermission: Bool
    ) {
        Task { @MainActor in
            let isUITesting = ProcessInfo.processInfo.arguments.contains("--ui-testing")
            if requestPermission
                && !isUITesting
                && !settings.notificationsEnabled {
                do {
                    let granted = try await NotificationService.shared.requestAuthorization()
                    if granted {
                        settings.notificationsEnabled = true
                    }
                } catch {
                    reportReminderFailure(error)
                }
            }

            do {
                try await NotificationService.shared.scheduleNotifications(
                    for: refund,
                    preferences: settings.notificationPreferences
                )
            } catch {
                reportReminderFailure(error)
            }
        }
    }

    private func reportReminderFailure(_ error: Error) {
        NotificationCenter.default.post(
            name: .refundReminderSchedulingFailed,
            object: error.localizedDescription
        )
    }
}
