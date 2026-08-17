import SwiftData
import SwiftUI

struct SettingsView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var refunds: [Refund]

    @State private var exportItem: SettingsExportItem?
    @State private var exportCleanupDirectory: URL?
    @State private var pendingConfirmation: SettingsConfirmation?
    @State private var presentedAlert: SettingsAlert?
    @State private var isRequestingNotifications = false
    @State private var isShowingCurrencyPicker = false
    /// Rescheduling suspends on several notification-centre calls, so two runs
    /// interleave freely. Each computes its stale list up front and then removes
    /// it wholesale, which lets an older run delete requests a newer one just
    /// added. Chaining onto this task serializes them instead.
    @State private var rescheduleTask: Task<Void, Never>?

    private var currencyBinding: Binding<String> {
        Binding(
            get: { settings.defaultCurrencyCode },
            set: { settings.defaultCurrencyCode = $0 }
        )
    }

    var body: some View {
        NavigationStack {
            ZStack {
                RefundBackdrop()

                ScrollView {
                    // A plain VStack, not lazy: the whole screen is a handful
                    // of sections, and a lazy container rebuilds rows as the
                    // selection changes, which is what broke the pushed
                    // currency picker.
                    VStack(alignment: .leading, spacing: 40) {
                        defaultsSection
                        remindersSection
                        appearanceSection
                        dataSection
                        resetSection
                        aboutSection
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, 8)
                    .padding(.bottom, 44)
                }
                .tint(RefundTheme.ink)
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .accessibilityIdentifier("settings.done")
                }
            }
            // Owned by the stack rather than by a row inside the scroll view.
            // As a `NavigationLink` destination, picking a currency rewrote
            // the row that owned the link, detaching the screen already on
            // screen: it stopped dismissing and ignored every later tap.
            .navigationDestination(isPresented: $isShowingCurrencyPicker) {
                CurrencyPickerView(selection: currencyBinding)
            }
            .confirmationDialog(
                confirmationTitle,
                isPresented: Binding(
                    get: { pendingConfirmation != nil },
                    set: { if !$0 { pendingConfirmation = nil } }
                ),
                titleVisibility: .visible
            ) {
                confirmationActions
            } message: {
                Text(confirmationMessage)
            }
            .alert(item: $presentedAlert) { alert in
                Alert(
                    title: Text(alert.title),
                    message: Text(alert.message),
                    dismissButton: .default(Text("OK"))
                )
            }
            .sheet(item: $exportItem, onDismiss: removeExportFile) { item in
                ActivityShareSheet(items: [item.url])
                    .presentationDetents([.medium, .large])
            }
            .onChange(of: settings.notificationPreferences) { _, preferences in
                guard preferences.isEnabled else { return }
                reschedule(with: preferences, for: refunds)
            }
        }
    }

    private var defaultsSection: some View {
        @Bindable var settings = settings

        return SettingsSection(
            title: "Defaults",
            footer: "Business days exclude Saturdays and Sundays."
        ) {
            SettingsStepperRow(
                title: "Expected refund window",
                valueLabel: "\(settings.defaultExpectedRefundBusinessDays) business \(settings.defaultExpectedRefundBusinessDays == 1 ? "day" : "days")",
                hint: "Sets the suggested expected date for new refunds",
                value: $settings.defaultExpectedRefundBusinessDays,
                range: 1 ... 60
            )

            Button {
                isShowingCurrencyPicker = true
            } label: {
                SettingsRowLabel(
                    title: "Default currency",
                    value: settings.defaultCurrencyCode,
                    showsChevron: true
                )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("settings.defaultCurrency")
        }
    }

    private var remindersSection: some View {
        @Bindable var settings = settings

        return SettingsSection(
            title: "Reminders",
            footer: settings.notificationsEnabled
                ? "Reminder timing updates automatically when a refund changes."
                : "Permission is requested only when you turn reminders on."
        ) {
            SettingsToggleRow(
                title: "Refund reminders",
                identifier: "settings.notifications",
                isBusy: isRequestingNotifications,
                isOn: Binding(
                    get: { settings.notificationsEnabled },
                    set: { requestedValue in
                        changeNotifications(to: requestedValue)
                    }
                )
            )
            .disabled(isRequestingNotifications)

            if settings.notificationsEnabled {
                SettingsStepperRow(
                    title: "Early reminder",
                    valueLabel: earlyReminderLabel(settings.remindBeforeDays),
                    value: $settings.remindBeforeDays,
                    range: 0 ... 30
                )

                SettingsToggleRow(
                    title: "On expected date",
                    isOn: $settings.remindOnExpectedDate
                )

                SettingsToggleRow(
                    title: "When overdue",
                    isOn: $settings.remindWhenOverdue
                )

                if settings.remindWhenOverdue {
                    SettingsStepperRow(
                        title: "Overdue follow-up",
                        valueLabel: "\(settings.overdueFollowUpDays) \(settings.overdueFollowUpDays == 1 ? "day" : "days") later",
                        value: $settings.overdueFollowUpDays,
                        range: 1 ... 30
                    )
                }
            }
        }
    }

    private var appearanceSection: some View {
        @Bindable var settings = settings

        return SettingsSection(title: "Appearance") {
            HStack(spacing: 26) {
                ForEach(AppAppearance.allCases) { appearance in
                    RefundChoice(
                        title: appearance.displayName,
                        isSelected: settings.appearance == appearance
                    ) {
                        settings.appearance = appearance
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(.vertical, 16)
            .accessibilityLabel("App appearance")
        }
    }

    private var dataSection: some View {
        SettingsSection(
            title: "Your data",
            footer: "Sample records are never added automatically. Resetting samples does not affect refunds you created."
        ) {
            Button {
                exportCSV()
            } label: {
                SettingsRowLabel(
                    title: "Export refunds as CSV",
                    detail: refunds.isEmpty
                        ? "No records to export"
                        : "\(refunds.count) \(refunds.count == 1 ? "record" : "records")",
                    showsChevron: !refunds.isEmpty
                )
            }
            .buttonStyle(.plain)
            .disabled(refunds.isEmpty)
            .opacity(refunds.isEmpty ? 0.5 : 1)
            .accessibilityIdentifier("settings.exportCSV")

            Button {
                if refunds.contains(where: \.isSampleData) {
                    pendingConfirmation = .resetSampleData
                } else {
                    loadSampleData()
                }
            } label: {
                SettingsRowLabel(
                    title: refunds.contains(where: \.isSampleData)
                        ? "Reset sample data"
                        : "Load sample data",
                    detail: "Five realistic refund scenarios",
                    showsChevron: true
                )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("settings.sampleData")
        }
    }

    private var resetSection: some View {
        SettingsSection(title: "Start fresh") {
            Button(role: .destructive) {
                pendingConfirmation = .resetSettings
            } label: {
                SettingsRowLabel(
                    title: "Restore default settings",
                    titleColor: RefundTheme.alert,
                    showsChevron: true
                )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("settings.restoreDefaults")
        }
    }

    private var aboutSection: some View {
        SettingsSection(
            title: "About",
            footer: "Refund Tracker stores records and attachments locally on this device."
        ) {
            SettingsRowLabel(title: "Version", value: appVersion)
            SettingsRowLabel(title: "Data storage", value: "On device")
        }
    }

    @ViewBuilder
    private var confirmationActions: some View {
        switch pendingConfirmation {
        case .resetSampleData:
            Button("Reset Sample Data", role: .destructive) {
                resetSampleData()
            }
            Button("Cancel", role: .cancel) {}
        case .resetSettings:
            Button("Restore Defaults", role: .destructive) {
                settings.resetToDefaults()
                Task {
                    await NotificationService.shared.removeAllRefundReminders()
                }
            }
            Button("Cancel", role: .cancel) {}
        case nil:
            EmptyView()
        }
    }

    private var confirmationTitle: String {
        switch pendingConfirmation {
        case .resetSampleData:
            "Reset sample data?"
        case .resetSettings:
            "Restore default settings?"
        case nil:
            ""
        }
    }

    private var confirmationMessage: String {
        switch pendingConfirmation {
        case .resetSampleData:
            "Existing sample records will be replaced with fresh examples. Your own refunds will stay untouched."
        case .resetSettings:
            "Reminder timing, default currency, refund window, and appearance will return to their defaults."
        case nil:
            ""
        }
    }

    private var appVersion: String {
        Bundle.main.object(
            forInfoDictionaryKey: "CFBundleShortVersionString"
        ) as? String ?? "1.0.0"
    }

    private func earlyReminderLabel(_ days: Int) -> String {
        switch days {
        case 0:
            "Off"
        case 1:
            "1 day before"
        default:
            "\(days) days before"
        }
    }

    private func changeNotifications(to requestedValue: Bool) {
        guard requestedValue else {
            settings.notificationsEnabled = false
            Task {
                await NotificationService.shared.removeAllRefundReminders()
            }
            return
        }

        isRequestingNotifications = true
        Task {
            do {
                let granted = try await NotificationService.shared
                    .requestAuthorization()
                await MainActor.run {
                    settings.notificationsEnabled = granted
                    isRequestingNotifications = false
                    if !granted {
                        presentedAlert = .notificationsDenied
                    }
                }
            } catch {
                await MainActor.run {
                    settings.notificationsEnabled = false
                    isRequestingNotifications = false
                    presentedAlert = .error(error.localizedDescription)
                }
            }
        }
    }

    private func exportCSV() {
        do {
            let url = try CSVExportService.exportFile(from: refunds)
            exportCleanupDirectory = url.deletingLastPathComponent()
            exportItem = SettingsExportItem(url: url)
        } catch {
            presentedAlert = .error(
                error.localizedDescription.isEmpty
                    ? "The CSV file could not be created."
                    : error.localizedDescription
            )
        }
    }

    private func removeExportFile() {
        guard let exportCleanupDirectory else { return }
        try? FileManager.default.removeItem(at: exportCleanupDirectory)
        self.exportCleanupDirectory = nil
        exportItem = nil
    }

    private func loadSampleData() {
        do {
            try SampleDataService.insert(into: modelContext)
            presentedAlert = .sampleDataLoaded
            rescheduleNotificationsAfterDataChange()
        } catch {
            presentedAlert = .error(error.localizedDescription)
        }
    }

    private func resetSampleData() {
        do {
            try SampleDataService.reset(in: modelContext)
            presentedAlert = .sampleDataReset
            rescheduleNotificationsAfterDataChange()
        } catch {
            presentedAlert = .error(error.localizedDescription)
        }
    }

    private func rescheduleNotificationsAfterDataChange() {
        guard settings.notificationsEnabled else { return }
        do {
            let currentRefunds = try modelContext.fetch(
                FetchDescriptor<Refund>()
            )
            reschedule(
                with: settings.notificationPreferences,
                for: currentRefunds
            )
        } catch {
            presentedAlert = .error(error.localizedDescription)
        }
    }

    /// Queues behind any reschedule still in flight, so the newest preferences
    /// are the ones that land last. Cancellation is deliberately not used: the
    /// reconcile has no cancellation points, so dropping a queued run would
    /// just lose the change the user made.
    private func reschedule(
        with preferences: RefundNotificationPreferences,
        for refunds: [Refund]
    ) {
        let previousTask = rescheduleTask
        rescheduleTask = Task { @MainActor in
            await previousTask?.value

            do {
                try await NotificationService.shared.rescheduleAll(
                    for: refunds,
                    preferences: preferences
                )
            } catch {
                presentedAlert = .error(error.localizedDescription)
            }
        }
    }
}

/// One group of preferences: an eyebrow, a rule, and rows divided by hairlines.
/// The card-per-group treatment made a settings screen look like a dashboard.
private struct SettingsSection<Content: View>: View {
    let title: String
    var footer: String? = nil
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            RefundSectionHeading(title: title)

            VStack(alignment: .leading, spacing: 0) {
                content
            }

            if let footer {
                Text(footer)
                    .font(.system(.caption))
                    .foregroundStyle(RefundTheme.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 14)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct SettingsRowLabel: View {
    let title: String
    var titleColor: Color? = nil
    var value: String? = nil
    var detail: String? = nil
    var showsChevron = false

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(.subheadline))
                    .foregroundStyle(titleColor ?? RefundTheme.ink)

                if let detail {
                    Text(detail)
                        .font(.system(.caption))
                        .foregroundStyle(RefundTheme.inkSoft)
                }
            }

            Spacer(minLength: 8)

            if let value {
                Text(value)
                    .serif(16, relativeTo: .body)
                    .foregroundStyle(RefundTheme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }

            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.system(.caption2).weight(.medium))
                    .foregroundStyle(RefundTheme.inkFaint)
                    .accessibilityHidden(true)
            }
        }
        .padding(.vertical, 17)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .settingsRowRule()
    }
}

/// A `Toggle` whose own label carries a trailing `Spacer` leaves no width for
/// the switch to lay out in, so the switch draws in place but never receives
/// the tap. Hiding the built-in label and placing the switch beside the label
/// keeps the control hit-testable.
private struct SettingsToggleRow: View {
    let title: String
    var identifier: String? = nil
    var isBusy = false
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.system(.subheadline))
                .foregroundStyle(RefundTheme.ink)

            Spacer(minLength: 8)

            if isBusy {
                ProgressView()
                    .controlSize(.small)
                    .accessibilityLabel("Requesting notification permission")
            }

            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(RefundTheme.ink)
                .accessibilityLabel(title)
                .accessibilityIdentifier(identifier ?? "")
        }
        .padding(.vertical, 12)
        .settingsRowRule()
    }
}

/// The stepper control needs about a quarter of the row, which leaves too
/// little for a title like "Expected refund window" beside it — inline, the
/// title wrapped to three lines and the value truncated. Giving the title its
/// own line and pairing the value with the control keeps both readable.
private struct SettingsStepperRow: View {
    let title: String
    let valueLabel: String
    var hint: String? = nil
    @Binding var value: Int
    let range: ClosedRange<Int>

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(.subheadline))
                .foregroundStyle(RefundTheme.ink)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 10) {
                Text(valueLabel)
                    .serif(16, relativeTo: .body)
                    .foregroundStyle(RefundTheme.inkSoft)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                Spacer(minLength: 8)

                Stepper(value: $value, in: range) {
                    EmptyView()
                }
                .labelsHidden()
                .accessibilityLabel(title)
                .accessibilityValue(valueLabel)
                .accessibilityHint(hint ?? "")
            }
        }
        .padding(.vertical, 16)
        .settingsRowRule()
    }
}

private extension View {
    /// Closes a settings row with a hairline, so a section reads as a ruled
    /// list rather than a stack of separate controls.
    func settingsRowRule() -> some View {
        overlay(alignment: .bottom) {
            Rectangle()
                .fill(RefundTheme.line)
                .frame(height: RefundTheme.hairline)
        }
    }
}

private struct SettingsExportItem: Identifiable {
    let id = UUID()
    let url: URL
}

private enum SettingsConfirmation {
    case resetSampleData
    case resetSettings
}

private enum SettingsAlert: Identifiable {
    case notificationsDenied
    case sampleDataLoaded
    case sampleDataReset
    case error(String)

    var id: String {
        switch self {
        case .notificationsDenied:
            "notificationsDenied"
        case .sampleDataLoaded:
            "sampleDataLoaded"
        case .sampleDataReset:
            "sampleDataReset"
        case .error(let message):
            "error-\(message)"
        }
    }

    var title: String {
        switch self {
        case .notificationsDenied:
            "Notifications are off"
        case .sampleDataLoaded:
            "Sample data added"
        case .sampleDataReset:
            "Sample data reset"
        case .error:
            "Something went wrong"
        }
    }

    var message: String {
        switch self {
        case .notificationsDenied:
            "You can allow notifications later in the iOS Settings app."
        case .sampleDataLoaded:
            "Explore the app with five realistic refund scenarios."
        case .sampleDataReset:
            "The sample scenarios are fresh again. Your own refunds were not changed."
        case .error(let message):
            message
        }
    }
}
