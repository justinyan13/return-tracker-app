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

    // Values that need clamping or normalization are stored privately and
    // exposed through computed properties. Doing that work in a `didSet` would
    // recurse forever: the @Observable macro rewrites each stored property into
    // a computed setter and moves the `didSet` onto its private backing store,
    // so assigning to the property from its own `didSet` re-enters the setter.
    private var storedExpectedRefundBusinessDays: Int
    private var storedCurrencyCode: String
    private var storedRemindBeforeDays: Int
    private var storedOverdueFollowUpDays: Int

    var defaultExpectedRefundBusinessDays: Int {
        get { storedExpectedRefundBusinessDays }
        set {
            let clamped = Self.clamped(newValue, 1, 60)
            guard clamped != storedExpectedRefundBusinessDays else { return }
            storedExpectedRefundBusinessDays = clamped
            defaults.set(clamped, forKey: Keys.defaultExpectedRefundBusinessDays)
        }
    }

    var defaultCurrencyCode: String {
        get { storedCurrencyCode }
        set {
            let normalized = Self.normalizedCurrencyCode(newValue)
            guard normalized != storedCurrencyCode else { return }
            storedCurrencyCode = normalized
            defaults.set(normalized, forKey: Keys.defaultCurrencyCode)
        }
    }

    var notificationsEnabled: Bool {
        didSet { defaults.set(notificationsEnabled, forKey: Keys.notificationsEnabled) }
    }

    var remindBeforeDays: Int {
        get { storedRemindBeforeDays }
        set {
            let clamped = Self.clamped(newValue, 0, 30)
            guard clamped != storedRemindBeforeDays else { return }
            storedRemindBeforeDays = clamped
            defaults.set(clamped, forKey: Keys.remindBeforeDays)
        }
    }

    var remindOnExpectedDate: Bool {
        didSet { defaults.set(remindOnExpectedDate, forKey: Keys.remindOnExpectedDate) }
    }

    var remindWhenOverdue: Bool {
        didSet { defaults.set(remindWhenOverdue, forKey: Keys.remindWhenOverdue) }
    }

    var overdueFollowUpDays: Int {
        get { storedOverdueFollowUpDays }
        set {
            let clamped = Self.clamped(newValue, 1, 30)
            guard clamped != storedOverdueFollowUpDays else { return }
            storedOverdueFollowUpDays = clamped
            defaults.set(clamped, forKey: Keys.overdueFollowUpDays)
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
        storedExpectedRefundBusinessDays = Self.clamped(storedWindow ?? 10, 1, 60)

        let storedCurrency = userDefaults.string(forKey: Keys.defaultCurrencyCode)
        storedCurrencyCode = Self.normalizedCurrencyCode(
            storedCurrency ?? Locale.current.currency?.identifier ?? "USD"
        )

        notificationsEnabled = userDefaults.bool(forKey: Keys.notificationsEnabled)

        let storedBeforeDays = userDefaults.object(forKey: Keys.remindBeforeDays) as? Int
        storedRemindBeforeDays = Self.clamped(storedBeforeDays ?? 3, 0, 30)

        remindOnExpectedDate =
            userDefaults.object(forKey: Keys.remindOnExpectedDate) as? Bool ?? true
        remindWhenOverdue =
            userDefaults.object(forKey: Keys.remindWhenOverdue) as? Bool ?? true

        let storedFollowUpDays = userDefaults.object(forKey: Keys.overdueFollowUpDays) as? Int
        storedOverdueFollowUpDays = Self.clamped(storedFollowUpDays ?? 3, 1, 30)

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

    private static func clamped(_ value: Int, _ lowerBound: Int, _ upperBound: Int) -> Int {
        min(max(value, lowerBound), upperBound)
    }

    static func normalizedCurrencyCode(_ code: String) -> String {
        let normalized = code
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
        guard normalized.count == 3,
              normalized.rangeOfCharacter(from: .letters.inverted) == nil else {
            return "USD"
        }
        return normalized
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
