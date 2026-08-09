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
        NavigationStack {
            ZStack {
                RefundBackdrop()

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 18) {
                        SettingsDefaultsHero(
                            currencyCode: settings.defaultCurrencyCode,
                            expectedDays: settings.defaultExpectedRefundBusinessDays
                        )

                        defaultsCard
                        remindersCard
                        appearanceCard
                        dataCard
                        resetCard
                        aboutCard
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 4)
                    .padding(.bottom, 28)
                }
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

    private var defaultsCard: some View {
        @Bindable var settings = settings

        return SettingsCard(
            title: "Set it once",
            subtitle: "New refunds start with these.",
            symbol: "slider.horizontal.3",
            tint: RefundTheme.violet,
            footer: "Business days exclude Saturdays and Sundays."
        ) {
            SettingsStepperRow(
                title: "Expected refund window",
                symbol: "calendar.badge.clock",
                tint: RefundTheme.blue,
                valueLabel: "\(settings.defaultExpectedRefundBusinessDays) business \(settings.defaultExpectedRefundBusinessDays == 1 ? "day" : "days")",
                hint: "Sets the suggested expected date for new refunds",
                value: $settings.defaultExpectedRefundBusinessDays,
                range: 1 ... 60
            )

            NavigationLink {
                CurrencyPickerView(
                    selection: $settings.defaultCurrencyCode
                )
            } label: {
                SettingsRow {
                    SettingsRowLabel(
                        title: "Default currency",
                        symbol: "banknote",
                        tint: RefundTheme.mint,
                        value: settings.defaultCurrencyCode,
                        showsChevron: true
                    )
                }
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("settings.defaultCurrency")
        }
    }

    private var remindersCard: some View {
        @Bindable var settings = settings

        return SettingsCard(
            title: "Gentle nudges",
            subtitle: "Reminders while you wait.",
            symbol: "bell.badge.fill",
            tint: RefundTheme.blue,
            footer: settings.notificationsEnabled
                ? "Reminder timing updates automatically when a refund changes."
                : "Permission is requested only when you turn reminders on."
        ) {
            SettingsToggleRow(
                title: "Refund reminders",
                symbol: "bell.fill",
                tint: RefundTheme.mango,
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
                    symbol: "clock.arrow.circlepath",
                    tint: RefundTheme.blue,
                    valueLabel: earlyReminderLabel(settings.remindBeforeDays),
                    value: $settings.remindBeforeDays,
                    range: 0 ... 30
                )

                SettingsToggleRow(
                    title: "On expected date",
                    symbol: "calendar.badge.checkmark",
                    tint: RefundTheme.mint,
                    isOn: $settings.remindOnExpectedDate
                )

                SettingsToggleRow(
                    title: "When overdue",
                    symbol: "exclamationmark.circle.fill",
                    tint: RefundTheme.coral,
                    isOn: $settings.remindWhenOverdue
                )

                if settings.remindWhenOverdue {
                    SettingsStepperRow(
                        title: "Overdue follow-up",
                        symbol: "arrow.clockwise",
                        tint: RefundTheme.coral,
                        valueLabel: "\(settings.overdueFollowUpDays) \(settings.overdueFollowUpDays == 1 ? "day" : "days") later",
                        value: $settings.overdueFollowUpDays,
                        range: 1 ... 30
                    )
                }
            }
        }
    }

    private var appearanceCard: some View {
        @Bindable var settings = settings

        return SettingsCard(
            title: "Pick a mood",
            subtitle: "Match iOS, or lock it in.",
            symbol: "paintpalette.fill",
            tint: RefundTheme.pink
        ) {
            Picker("Theme", selection: $settings.appearance) {
                ForEach(AppAppearance.allCases) { appearance in
                    Text(appearance.displayName)
                        .tag(appearance)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .accessibilityLabel("App appearance")
        }
    }

    private var dataCard: some View {
        SettingsCard(
            title: "Your data",
            subtitle: "Take it with you, or explore with samples.",
            symbol: "tray.full.fill",
            tint: RefundTheme.mango,
            footer: "Sample records are never added automatically. Resetting samples does not affect refunds you created."
        ) {
            Button {
                exportCSV()
            } label: {
                SettingsRow {
                    SettingsRowLabel(
                        title: "Export refunds as CSV",
                        symbol: "square.and.arrow.up",
                        tint: RefundTheme.blue,
                        detail: refunds.isEmpty
                            ? "No records to export"
                            : "\(refunds.count) \(refunds.count == 1 ? "record" : "records")",
                        showsChevron: !refunds.isEmpty
                    )
                }
            }
            .buttonStyle(.plain)
            .disabled(refunds.isEmpty)
            .opacity(refunds.isEmpty ? 0.55 : 1)
            .accessibilityIdentifier("settings.exportCSV")

            Button {
                if refunds.contains(where: \.isSampleData) {
                    pendingConfirmation = .resetSampleData
                } else {
                    loadSampleData()
                }
            } label: {
                SettingsRow {
                    SettingsRowLabel(
                        title: refunds.contains(where: \.isSampleData)
                            ? "Reset sample data"
                            : "Load sample data",
                        symbol: "sparkles",
                        tint: RefundTheme.violet,
                        detail: "Five realistic refund scenarios",
                        showsChevron: true
                    )
                }
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("settings.sampleData")
        }
    }

    private var resetCard: some View {
        SettingsCard(
            title: "Start fresh",
            subtitle: "Send every preference back to its default.",
            symbol: "arrow.counterclockwise",
            tint: RefundTheme.coral
        ) {
            Button(role: .destructive) {
                pendingConfirmation = .resetSettings
            } label: {
                SettingsRow {
                    SettingsRowLabel(
                        title: "Restore default settings",
                        symbol: "arrow.counterclockwise",
                        tint: RefundTheme.coral,
                        titleColor: RefundTheme.coral
                    )
                }
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("settings.restoreDefaults")
        }
    }

    private var aboutCard: some View {
        SettingsCard(
            title: "About",
            subtitle: "Where things live.",
            symbol: "info.circle.fill",
            tint: RefundTheme.violet,
            footer: "Refund Tracker stores records and attachments locally on this device."
        ) {
            SettingsRow {
                SettingsRowLabel(
                    title: "Version",
                    symbol: "app.badge",
                    tint: RefundTheme.violet,
                    value: appVersion
                )
            }

            SettingsRow {
                SettingsRowLabel(
                    title: "Data storage",
                    symbol: "iphone",
                    tint: RefundTheme.mint,
                    value: "On device"
                )
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

/// A glass card carrying one group of preferences, so Settings reads with the
/// same section rhythm as the dashboard, insights, and refund screens.
private struct SettingsCard<Content: View>: View {
    let title: String
    var subtitle: String? = nil
    let symbol: String
    var tint: Color = RefundTheme.violet
    var footer: String? = nil
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            RefundSectionHeading(
                title: title,
                subtitle: subtitle,
                symbol: symbol
            )

            VStack(spacing: 10) {
                content
            }

            if let footer {
                Text(footer)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .refundGlassCard(tint: tint, padding: 18)
    }
}

/// Matches the field treatment used by the refund form, so a control looks the
/// same whether it is editing a refund or a preference.
private struct SettingsRow<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(.horizontal, 14)
            .frame(minHeight: 52)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                Color(uiColor: .secondarySystemGroupedBackground).opacity(0.82),
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
    }
}

/// A `Toggle` whose own label carries a trailing `Spacer` leaves no width for
/// the switch to lay out in, so the switch draws in place but never receives
/// the tap. Hiding the built-in label and placing the switch beside the label
/// keeps the control hit-testable.
private struct SettingsToggleRow: View {
    let title: String
    let symbol: String
    var tint: Color = RefundTheme.violet
    var identifier: String? = nil
    var isBusy = false
    @Binding var isOn: Bool

    var body: some View {
        SettingsRow {
            HStack(spacing: 12) {
                SettingsRowLabel(title: title, symbol: symbol, tint: tint)

                if isBusy {
                    ProgressView()
                        .controlSize(.small)
                        .accessibilityLabel(
                            "Requesting notification permission"
                        )
                }

                Toggle("", isOn: $isOn)
                    .labelsHidden()
                    .accessibilityLabel(title)
                    .accessibilityIdentifier(identifier ?? "")
            }
        }
    }
}

/// The stepper control needs about a quarter of the row, which leaves too
/// little for a title like "Expected refund window" beside it — inline, the
/// title wrapped to three lines and the value truncated. Giving the title its
/// own line and pairing the value with the control keeps both readable.
private struct SettingsStepperRow: View {
    let title: String
    let symbol: String
    var tint: Color = RefundTheme.violet
    let valueLabel: String
    var hint: String? = nil
    @Binding var value: Int
    let range: ClosedRange<Int>

    var body: some View {
        SettingsRow {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: symbol)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(tint)
                    .frame(width: 30, height: 30)
                    .background(
                        tint.opacity(0.13),
                        in: RoundedRectangle(cornerRadius: 9, style: .continuous)
                    )
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 8) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    HStack(spacing: 10) {
                        Text(valueLabel)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(tint)
                            .monospacedDigit()
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
            }
            .padding(.vertical, 12)
        }
    }
}

private struct SettingsRowLabel: View {
    let title: String
    let symbol: String
    var tint: Color = RefundTheme.violet
    var titleColor: Color? = nil
    var value: String? = nil
    var detail: String? = nil
    var showsChevron = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: 30, height: 30)
                .background(
                    tint.opacity(0.13),
                    in: RoundedRectangle(cornerRadius: 9, style: .continuous)
                )
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(titleColor ?? .primary)

                if let detail {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 8)

            if let value {
                Text(value)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(tint)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }

            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
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
