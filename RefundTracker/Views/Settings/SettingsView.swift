import SwiftData
import SwiftUI

struct SettingsView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.modelContext) private var modelContext
    @Query private var refunds: [Refund]

    @State private var exportItem: SettingsExportItem?
    @State private var exportCleanupDirectory: URL?
    @State private var pendingConfirmation: SettingsConfirmation?
    @State private var presentedAlert: SettingsAlert?
    @State private var isRequestingNotifications = false

    var body: some View {
        @Bindable var settings = settings

        NavigationStack {
            ZStack {
                RefundBackdrop()

                Form {
                    Section {
                        SettingsDefaultsHero(
                            currencyCode: settings.defaultCurrencyCode,
                            expectedDays: settings.defaultExpectedRefundBusinessDays
                        )
                    }
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)

                Section {
                    Stepper(
                        value: $settings.defaultExpectedRefundBusinessDays,
                        in: 1 ... 60
                    ) {
                        LabeledContent(
                            "Expected refund window",
                            value: "\(settings.defaultExpectedRefundBusinessDays) business \(settings.defaultExpectedRefundBusinessDays == 1 ? "day" : "days")"
                        )
                    }
                    .accessibilityHint(
                        "Sets the suggested expected date for new refunds"
                    )

                    NavigationLink {
                        CurrencyPickerView(
                            selection: $settings.defaultCurrencyCode
                        )
                    } label: {
                        LabeledContent(
                            "Default currency",
                            value: settings.defaultCurrencyCode
                        )
                    }
                } header: {
                    Text("Set it once")
                } footer: {
                    Text(
                        "New refunds use these defaults automatically. Business days exclude Saturdays and Sundays."
                    )
                }

                Section {
                    Toggle(
                        isOn: Binding(
                            get: { settings.notificationsEnabled },
                            set: { requestedValue in
                                changeNotifications(to: requestedValue)
                            }
                        )
                    ) {
                        HStack {
                            Text("Refund reminders")
                            if isRequestingNotifications {
                                ProgressView()
                                    .controlSize(.small)
                                    .accessibilityLabel(
                                        "Requesting notification permission"
                                    )
                            }
                        }
                    }
                    .disabled(isRequestingNotifications)
                    .accessibilityIdentifier("settings.notifications")

                    if settings.notificationsEnabled {
                        Stepper(
                            value: $settings.remindBeforeDays,
                            in: 0 ... 30
                        ) {
                            LabeledContent(
                                "Early reminder",
                                value: earlyReminderLabel(settings.remindBeforeDays)
                            )
                        }

                        Toggle(
                            "On expected date",
                            isOn: $settings.remindOnExpectedDate
                        )
                        Toggle(
                            "When overdue",
                            isOn: $settings.remindWhenOverdue
                        )

                        if settings.remindWhenOverdue {
                            Stepper(
                                value: $settings.overdueFollowUpDays,
                                in: 1 ... 30
                            ) {
                                LabeledContent(
                                    "Overdue follow-up",
                                    value: "\(settings.overdueFollowUpDays) \(settings.overdueFollowUpDays == 1 ? "day" : "days") later"
                                )
                            }
                        }
                    }
                } header: {
                    Text("Gentle nudges")
                } footer: {
                    Text(
                        settings.notificationsEnabled
                            ? "Reminder timing updates automatically when a refund changes."
                            : "Permission is requested only when you turn reminders on."
                    )
                }

                Section("Pick a mood") {
                    Picker("Theme", selection: $settings.appearance) {
                        ForEach(AppAppearance.allCases) { appearance in
                            Text(appearance.displayName)
                                .tag(appearance)
                        }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityLabel("App appearance")
                }

                Section {
                    Button {
                        exportCSV()
                    } label: {
                        SettingsActionLabel(
                            title: "Export refunds as CSV",
                            detail: refunds.isEmpty
                                ? "No records to export"
                                : "\(refunds.count) \(refunds.count == 1 ? "record" : "records")",
                            systemImage: "square.and.arrow.up"
                        )
                    }
                    .disabled(refunds.isEmpty)
                    .accessibilityIdentifier("settings.exportCSV")

                    Button {
                        if refunds.contains(where: \.isSampleData) {
                            pendingConfirmation = .resetSampleData
                        } else {
                            loadSampleData()
                        }
                    } label: {
                        SettingsActionLabel(
                            title: refunds.contains(where: \.isSampleData)
                                ? "Reset sample data"
                                : "Load sample data",
                            detail: "Five realistic refund scenarios",
                            systemImage: "sparkles"
                        )
                    }
                    .accessibilityIdentifier("settings.sampleData")
                } header: {
                    Text("Your data")
                } footer: {
                    Text(
                        "Sample records are never added automatically. Resetting samples does not affect refunds you created."
                    )
                }

                Section {
                    Button("Restore default settings", role: .destructive) {
                        pendingConfirmation = .resetSettings
                    }
                } footer: {
                    Text(
                        "Refund Tracker stores records and attachments locally on this device."
                    )
                }

                Section("About") {
                    LabeledContent("Version", value: appVersion)
                    LabeledContent("Data storage", value: "On device")
                }
                }
                .scrollContentBackground(.hidden)
                .listSectionSpacing(18)
                .tint(RefundTheme.violet)
            }
            .navigationTitle("Make it yours")
            .toolbarBackground(.hidden, for: .navigationBar)
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
                Task {
                    do {
                        try await NotificationService.shared.rescheduleAll(
                            for: refunds,
                            preferences: preferences
                        )
                    } catch {
                        await MainActor.run {
                            presentedAlert = .error(error.localizedDescription)
                        }
                    }
                }
            }
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
        let shortVersion = Bundle.main.object(
            forInfoDictionaryKey: "CFBundleShortVersionString"
        ) as? String ?? "1.0"
        let build = Bundle.main.object(
            forInfoDictionaryKey: "CFBundleVersion"
        ) as? String
        guard let build, build != shortVersion else { return shortVersion }
        return "\(shortVersion) (\(build))"
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
            Task {
                do {
                    try await NotificationService.shared.rescheduleAll(
                        for: currentRefunds,
                        preferences: settings.notificationPreferences
                    )
                } catch {
                    presentedAlert = .error(error.localizedDescription)
                }
            }
        } catch {
            presentedAlert = .error(error.localizedDescription)
        }
    }
}

private struct SettingsDefaultsHero: View {
    let currencyCode: String
    let expectedDays: Int

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: "wand.and.stars")
                .font(.title.bold())
                .foregroundStyle(.white)
                .frame(width: 62, height: 62)
                .background(
                    LinearGradient(
                        colors: [RefundTheme.violet, RefundTheme.pink],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: RoundedRectangle(cornerRadius: 20, style: .continuous)
                )
                .shadow(color: RefundTheme.violet.opacity(0.28), radius: 12, y: 7)

            VStack(alignment: .leading, spacing: 5) {
                Text("Your shortcut")
                    .font(.title3.bold())

                Text(
                    "\(currencyCode) · \(expectedDays) business \(expectedDays == 1 ? "day" : "days")"
                )
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(RefundTheme.violet)

                Text("Used automatically every time you add a refund.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .refundGlassCard(tint: RefundTheme.violet, padding: 18)
        .padding(.vertical, 4)
    }
}

private struct SettingsActionLabel: View {
    let title: String
    let detail: String
    let systemImage: String

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .foregroundStyle(.primary)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } icon: {
            Image(systemName: systemImage)
                .foregroundStyle(.tint)
                .frame(width: 24)
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
