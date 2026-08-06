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
    @State private var didApplySettingsDefaults = false
    @State private var saveErrorMessage: String?
    @FocusState private var focusedField: Field?

    private enum Field {
        case retailer
        case item
        case amount
        case order
        case tracking
        case carrier
        case notes
    }

    init(refund: Refund? = nil) {
        self.refund = refund
        _viewModel = State(initialValue: RefundFormViewModel(refund: refund))
    }

    var body: some View {
        NavigationStack {
            Form {
                requiredDetailsSection
                returnDatesSection
                refundDetailsSection
                trackingSection
                notesSection

                if didAttemptSave && !viewModel.validationMessages.isEmpty {
                    validationSection
                }
            }
            .navigationTitle(refund == nil ? "Track a refund" : "Edit refund")
            .navigationBarTitleDisplayMode(.inline)
            .scrollDismissesKeyboard(.interactively)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                    }
                    .fontWeight(.semibold)
                    .accessibilityIdentifier("saveRefundButton")
                }

                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        focusedField = nil
                    }
                }
            }
            .interactiveDismissDisabled(hasUnsavedContent)
            .onAppear {
                applySettingsDefaultsIfNeeded()
            }
            .alert("Couldn’t save refund", isPresented: saveErrorBinding) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(saveErrorMessage ?? "Please try again.")
            }
        }
    }

    private var requiredDetailsSection: some View {
        Section {
            TextField("Retailer", text: $viewModel.retailerName)
                .textContentType(.organizationName)
                .textInputAutocapitalization(.words)
                .submitLabel(.next)
                .focused($focusedField, equals: .retailer)
                .onSubmit { focusedField = .item }
                .accessibilityIdentifier("retailerField")

            TextField("Item name", text: $viewModel.itemName)
                .textInputAutocapitalization(.sentences)
                .submitLabel(.next)
                .focused($focusedField, equals: .item)
                .onSubmit { focusedField = .amount }
                .accessibilityIdentifier("itemField")

            HStack {
                Menu(viewModel.currencyCode) {
                    Picker("Currency", selection: $viewModel.currencyCode) {
                        ForEach(Self.currencyCodes, id: \.self) { code in
                            Text(code).tag(code)
                        }
                    }
                }
                .font(.body.monospaced())
                .accessibilityLabel("Currency")

                TextField("Refund amount", text: $viewModel.amountText)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .focused($focusedField, equals: .amount)
                    .accessibilityIdentifier("amountField")
            }

            TextField("Order number (optional)", text: $viewModel.orderNumber)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($focusedField, equals: .order)
                .accessibilityIdentifier("orderNumberField")
        } header: {
            Text("Refund")
        } footer: {
            Text("Retailer, item, and amount are required.")
        }
    }

    private var returnDatesSection: some View {
        Section("Dates") {
            Toggle("Include purchase date", isOn: $viewModel.includesPurchaseDate)
            if viewModel.includesPurchaseDate {
                DatePicker(
                    "Purchase date",
                    selection: $viewModel.purchaseDate,
                    in: ...viewModel.returnDate,
                    displayedComponents: .date
                )
            }

            DatePicker(
                "Return date",
                selection: Binding(
                    get: { viewModel.returnDate },
                    set: viewModel.setReturnDate
                ),
                displayedComponents: .date
            )
            .accessibilityIdentifier("returnDatePicker")

            Toggle(
                "Retailer received return",
                isOn: Binding(
                    get: { viewModel.includesReceivedDate },
                    set: viewModel.setRetailerReceived
                )
            )
            if viewModel.includesReceivedDate {
                DatePicker(
                    "Date received",
                    selection: Binding(
                        get: { viewModel.retailerReceivedDate },
                        set: viewModel.setRetailerReceivedDate
                    ),
                    in: viewModel.retailerReceivedDateMinimum...,
                    displayedComponents: .date
                )
            }

            DatePicker(
                "Refund expected",
                selection: Binding(
                    get: { viewModel.expectedRefundDate },
                    set: {
                        viewModel.expectedRefundDate = $0
                        viewModel.expectedDateChangedByUser()
                    }
                ),
                in: viewModel.returnDate...,
                displayedComponents: .date
            )
            .accessibilityIdentifier("expectedRefundDatePicker")

            Toggle(
                "Refund already received",
                isOn: Binding(
                    get: { viewModel.includesActualRefundDate },
                    set: viewModel.setActualRefundReceived
                )
            )
            if viewModel.includesActualRefundDate {
                DatePicker(
                    "Date received",
                    selection: $viewModel.actualRefundDate,
                    in: viewModel.actualRefundDateMinimum...,
                    displayedComponents: .date
                )
                .accessibilityIdentifier("actualRefundDatePicker")
            }
        }
    }

    private var refundDetailsSection: some View {
        Section {
            Picker("Refund method", selection: $viewModel.refundMethod) {
                ForEach(RefundMethod.allCases) { method in
                    Text(method.displayName).tag(method)
                }
            }

            Picker(
                "Status",
                selection: Binding(
                    get: { viewModel.status },
                    set: viewModel.setStatus
                )
            ) {
                ForEach(RefundFormViewModel.selectableStatuses) { status in
                    Label(status.title, systemImage: status.symbolName)
                        .tag(status)
                }
            }
            .disabled(viewModel.includesActualRefundDate)

            if viewModel.displayedStatus == .overdue {
                LabeledContent("Displayed status") {
                    Label("Overdue", systemImage: "exclamationmark.triangle.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.red)
                }
            }
        } header: {
            Text("Method and status")
        } footer: {
            Text("Overdue is calculated automatically from the expected refund date. Disputed and cancelled are manual overrides.")
        }
    }

    private var trackingSection: some View {
        Section {
            TextField("Tracking number", text: $viewModel.trackingNumber)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .focused($focusedField, equals: .tracking)
                .accessibilityIdentifier("trackingNumberField")

            TextField("Return carrier", text: $viewModel.returnCarrier)
                .textInputAutocapitalization(.words)
                .focused($focusedField, equals: .carrier)
                .accessibilityIdentifier("returnCarrierField")
        } header: {
            Text("Shipping")
        } footer: {
            Text("Optional. Add these details when the return is shipped.")
        }
    }

    private var notesSection: some View {
        Section("Notes") {
            TextField(
                "Confirmation details, contact history, or anything else",
                text: $viewModel.notes,
                axis: .vertical
            )
            .lineLimit(3...8)
            .focused($focusedField, equals: .notes)
            .accessibilityIdentifier("refundNotesField")
        }
    }

    private var validationSection: some View {
        Section {
            ForEach(viewModel.validationMessages, id: \.self) { message in
                Label(message, systemImage: "exclamationmark.circle.fill")
                    .foregroundStyle(.red)
            }
        } header: {
            Text("Check these details")
        }
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

    private func applySettingsDefaultsIfNeeded() {
        guard refund == nil, !didApplySettingsDefaults else { return }
        didApplySettingsDefaults = true
        viewModel.applyCreationDefaults(
            expectedBusinessDays: settings.defaultExpectedRefundBusinessDays,
            currencyCode: settings.defaultCurrencyCode
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

    private static var currencyCodes: [String] {
        let common = ["USD", "EUR", "GBP", "CAD", "AUD", "JPY", "CNY", "INR"]
        let current = Locale.current.currency?.identifier
        return Array(Set(common + [current].compactMap { $0 })).sorted()
    }
}
