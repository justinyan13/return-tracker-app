import Foundation
import Observation

enum AppAppearance: String, Codable, CaseIterable, Identifiable, Sendable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }
}

struct RefundNotificationPreferences: Equatable, Sendable {
    var isEnabled: Bool
    var daysBeforeExpectedDate: Int
    var remindOnExpectedDate: Bool
    var remindWhenOverdue: Bool
    var overdueFollowUpDays: Int

    static let defaults = RefundNotificationPreferences(
        isEnabled: false,
        daysBeforeExpectedDate: 3,
        remindOnExpectedDate: true,
        remindWhenOverdue: true,
        overdueFollowUpDays: 3
    )
}

@Observable
final class AppSettings {
    @ObservationIgnored private let defaults: UserDefaults

    var defaultExpectedRefundBusinessDays: Int {
        didSet {
            defaultExpectedRefundBusinessDays = min(max(defaultExpectedRefundBusinessDays, 1), 60)
            defaults.set(defaultExpectedRefundBusinessDays, forKey: Keys.defaultExpectedRefundBusinessDays)
        }
    }

    var defaultCurrencyCode: String {
        didSet {
            defaultCurrencyCode = Self.normalizedCurrencyCode(defaultCurrencyCode)
            defaults.set(defaultCurrencyCode, forKey: Keys.defaultCurrencyCode)
        }
    }

    var notificationsEnabled: Bool {
        didSet { defaults.set(notificationsEnabled, forKey: Keys.notificationsEnabled) }
    }

    var remindBeforeDays: Int {
        didSet {
            remindBeforeDays = min(max(remindBeforeDays, 0), 30)
            defaults.set(remindBeforeDays, forKey: Keys.remindBeforeDays)
        }
    }

    var remindOnExpectedDate: Bool {
        didSet { defaults.set(remindOnExpectedDate, forKey: Keys.remindOnExpectedDate) }
    }

    var remindWhenOverdue: Bool {
        didSet { defaults.set(remindWhenOverdue, forKey: Keys.remindWhenOverdue) }
    }

    var overdueFollowUpDays: Int {
        didSet {
            overdueFollowUpDays = min(max(overdueFollowUpDays, 1), 30)
            defaults.set(overdueFollowUpDays, forKey: Keys.overdueFollowUpDays)
        }
    }

    var appearance: AppAppearance {
        didSet { defaults.set(appearance.rawValue, forKey: Keys.appearance) }
    }

    var defaultExpectedRefundWindow: Int {
        get { defaultExpectedRefundBusinessDays }
        set { defaultExpectedRefundBusinessDays = newValue }
    }

    var notificationPreferences: RefundNotificationPreferences {
        RefundNotificationPreferences(
            isEnabled: notificationsEnabled,
            daysBeforeExpectedDate: remindBeforeDays,
            remindOnExpectedDate: remindOnExpectedDate,
            remindWhenOverdue: remindWhenOverdue,
            overdueFollowUpDays: overdueFollowUpDays
        )
    }

    init(userDefaults: UserDefaults = .standard) {
        defaults = userDefaults

        let storedWindow = userDefaults.object(forKey: Keys.defaultExpectedRefundBusinessDays) as? Int
        defaultExpectedRefundBusinessDays = min(max(storedWindow ?? 10, 1), 60)

        let storedCurrency = userDefaults.string(forKey: Keys.defaultCurrencyCode)
        defaultCurrencyCode = Self.normalizedCurrencyCode(
            storedCurrency ?? Locale.current.currency?.identifier ?? "USD"
        )

        notificationsEnabled = userDefaults.bool(forKey: Keys.notificationsEnabled)

        let storedBeforeDays = userDefaults.object(forKey: Keys.remindBeforeDays) as? Int
        remindBeforeDays = min(max(storedBeforeDays ?? 3, 0), 30)

        remindOnExpectedDate =
            userDefaults.object(forKey: Keys.remindOnExpectedDate) as? Bool ?? true
        remindWhenOverdue =
            userDefaults.object(forKey: Keys.remindWhenOverdue) as? Bool ?? true

        let storedFollowUpDays = userDefaults.object(forKey: Keys.overdueFollowUpDays) as? Int
        overdueFollowUpDays = min(max(storedFollowUpDays ?? 3, 1), 30)

        appearance = AppAppearance(
            rawValue: userDefaults.string(forKey: Keys.appearance) ?? ""
        ) ?? .system
    }

    func resetToDefaults() {
        defaultExpectedRefundBusinessDays = 10
        defaultCurrencyCode = Locale.current.currency?.identifier ?? "USD"
        notificationsEnabled = false
        remindBeforeDays = 3
        remindOnExpectedDate = true
        remindWhenOverdue = true
        overdueFollowUpDays = 3
        appearance = .system
    }

    private static func normalizedCurrencyCode(_ code: String) -> String {
        let normalized = code
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
        return normalized.count == 3 ? normalized : "USD"
    }

    private enum Keys {
        static let defaultExpectedRefundBusinessDays = "defaultExpectedRefundBusinessDays"
        static let defaultCurrencyCode = "defaultCurrencyCode"
        static let notificationsEnabled = "notificationsEnabled"
        static let remindBeforeDays = "remindBeforeDays"
        static let remindOnExpectedDate = "remindOnExpectedDate"
        static let remindWhenOverdue = "remindWhenOverdue"
        static let overdueFollowUpDays = "overdueFollowUpDays"
        static let appearance = "appearance"
    }
}
