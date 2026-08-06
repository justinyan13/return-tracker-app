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
    @State private var saveErrorMessage: String?
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case merchant
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

                ScrollView {
                    VStack(spacing: 22) {
                        if focusedField == nil {
                            introduction
                        }

                        refundCard

                        if didAttemptSave && !viewModel.validationMessages.isEmpty {
                            validationCard
                        }

                        saveButton
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 18)
                    .padding(.bottom, 28)
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
            .onAppear {
                applySettingsIfNeeded()
            }
            .alert("Couldn’t save refund", isPresented: saveErrorBinding) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(saveErrorMessage ?? "Please try again.")
            }
        }
    }

    private var introduction: some View {
        VStack(spacing: 10) {
            MerchantMark(
                name: viewModel.retailerName.isEmpty
                    ? "Refund"
                    : viewModel.retailerName,
                size: 58
            )

            Text(refund == nil ? "Track money coming back" : "Update this refund")
                .font(.title2.bold())
                .multilineTextAlignment(.center)

            Text("Just the essentials. We’ll calculate when the refund should arrive.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .contain)
    }

    private var refundCard: some View {
        VStack(alignment: .leading, spacing: 20) {
            RefundSectionHeading(
                title: "Refund details",
                subtitle: "You can update these details anytime.",
                symbol: "arrow.uturn.backward.circle.fill"
            )

            VStack(alignment: .leading, spacing: 8) {
                fieldLabel("Merchant name", symbol: "storefront")
                TextField("Merchant name", text: $viewModel.retailerName)
                    .textContentType(.organizationName)
                    .textInputAutocapitalization(.words)
                    .submitLabel(.next)
                    .focused($focusedField, equals: .merchant)
                    .onSubmit { focusedField = .amount }
                    .padding(.horizontal, 14)
                    .frame(minHeight: 52)
                    .background(
                        fieldBackground,
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                    )
                    .accessibilityIdentifier("retailerField")
            }
            .id(Field.merchant)

            VStack(alignment: .leading, spacing: 8) {
                fieldLabel("Refund amount", symbol: "banknote")

                HStack(spacing: 12) {
                    Text(viewModel.currencyCode)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 11)
                        .padding(.vertical, 7)
                        .background(
                            LinearGradient(
                                colors: [RefundTheme.violet, RefundTheme.blue],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            in: Capsule()
                        )
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("Currency \(viewModel.currencyCode)")
                        .accessibilityIdentifier("currencyChip")

                    TextField("0.00", text: $viewModel.amountText)
                        .keyboardType(.decimalPad)
                        .font(.title2.monospacedDigit())
                        .multilineTextAlignment(.trailing)
                        .frame(
                            maxWidth: .infinity,
                            minHeight: 52,
                            alignment: .trailing
                        )
                        .contentShape(Rectangle())
                        .focused($focusedField, equals: .amount)
                        .accessibilityLabel("Refund amount")
                        .accessibilityIdentifier("amountField")
                }
                .padding(.horizontal, 14)
                .frame(minHeight: 58)
                .background(
                    fieldBackground,
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                )
            }
            .id(Field.amount)

            VStack(alignment: .leading, spacing: 8) {
                fieldLabel(
                    viewModel.trackedDateTitle,
                    symbol: viewModel.trackedDateSymbol
                )
                DatePicker(
                    viewModel.trackedDateTitle,
                    selection: Binding(
                        get: { viewModel.returnDate },
                        set: viewModel.setTrackedDate
                    ),
                    in: ...viewModel.shippedDateUpperBound,
                    displayedComponents: .date
                )
                .datePickerStyle(.compact)
                .labelsHidden()
                .padding(.horizontal, 14)
                .frame(minHeight: 52)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    fieldBackground,
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                )
                .accessibilityIdentifier("returnDatePicker")
            }
        }
        .refundGlassCard(
            tint: RefundTheme.color(for: viewModel.retailerName),
            padding: 18
        )
    }

    private var validationCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(viewModel.validationMessages, id: \.self) { message in
                Label(message, systemImage: "exclamationmark.circle.fill")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(RefundTheme.coral)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .refundGlassCard(tint: RefundTheme.coral, padding: 16)
        .accessibilityElement(children: .combine)
    }

    private var saveButton: some View {
        Button {
            save()
        } label: {
            Label(
                refund == nil ? "Track refund" : "Save changes",
                systemImage: "checkmark.circle.fill"
            )
        }
        .buttonStyle(RefundPrimaryButtonStyle())
        .accessibilityIdentifier("saveRefundButton")
    }

    private var fieldBackground: some ShapeStyle {
        Color(uiColor: .secondarySystemGroupedBackground).opacity(0.82)
    }

    private func fieldLabel(_ title: String, symbol: String) -> some View {
        Label(title, systemImage: symbol)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.secondary)
    }

    private var saveErrorBinding: Binding<Bool> {
        Binding(
            get: { saveErrorMessage != nil },
            set: { if !$0 { saveErrorMessage = nil } }
        )
    }

    private var hasUnsavedContent: Bool {
        !viewModel.retailerName.isEmpty
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
