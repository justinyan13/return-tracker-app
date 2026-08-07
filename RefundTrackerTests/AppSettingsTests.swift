import XCTest
@testable import RefundTracker

/// Every mutation here previously crashed with unbounded recursion: the
/// @Observable macro rewrites a stored property into a computed setter and
/// moves its `didSet` onto the private backing store, so normalizing by
/// assigning to the property from inside its own `didSet` re-entered the
/// setter forever. These assertions only get a chance to run if that is fixed.
final class AppSettingsTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!

    override func setUpWithError() throws {
        suiteName = "AppSettingsTests-\(UUID().uuidString)"
        defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
    }

    override func tearDownWithError() throws {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
    }

    func testSelectingDefaultCurrencyNormalizesAndPersists() {
        let settings = AppSettings(userDefaults: defaults)

        settings.defaultCurrencyCode = "eur"

        XCTAssertEqual(settings.defaultCurrencyCode, "EUR")
        XCTAssertEqual(defaults.string(forKey: "defaultCurrencyCode"), "EUR")

        // A second, already-normalized selection must also settle.
        settings.defaultCurrencyCode = "GBP"

        XCTAssertEqual(settings.defaultCurrencyCode, "GBP")
        XCTAssertEqual(defaults.string(forKey: "defaultCurrencyCode"), "GBP")
    }

    func testSelectedCurrencyIsRestoredOnRelaunch() {
        AppSettings(userDefaults: defaults).defaultCurrencyCode = "  jpy  "

        let relaunched = AppSettings(userDefaults: defaults)

        XCTAssertEqual(relaunched.defaultCurrencyCode, "JPY")
    }

    func testUnusableCurrencyCodesFallBackToUSD() {
        let settings = AppSettings(userDefaults: defaults)
        settings.defaultCurrencyCode = "EUR"

        for unusable in ["", "E", "EURO", "12", "US1"] {
            settings.defaultCurrencyCode = unusable
            XCTAssertEqual(
                settings.defaultCurrencyCode,
                "USD",
                "Expected \"\(unusable)\" to fall back to USD"
            )
            settings.defaultCurrencyCode = "EUR"
        }
    }

    func testNumericPreferencesClampToTheirSupportedRange() {
        let settings = AppSettings(userDefaults: defaults)

        settings.defaultExpectedRefundBusinessDays = 500
        XCTAssertEqual(settings.defaultExpectedRefundBusinessDays, 60)
        settings.defaultExpectedRefundBusinessDays = 0
        XCTAssertEqual(settings.defaultExpectedRefundBusinessDays, 1)

        settings.remindBeforeDays = 99
        XCTAssertEqual(settings.remindBeforeDays, 30)
        settings.remindBeforeDays = -4
        XCTAssertEqual(settings.remindBeforeDays, 0)

        settings.overdueFollowUpDays = 99
        XCTAssertEqual(settings.overdueFollowUpDays, 30)
        settings.overdueFollowUpDays = 0
        XCTAssertEqual(settings.overdueFollowUpDays, 1)

        XCTAssertEqual(defaults.integer(forKey: "defaultExpectedRefundBusinessDays"), 1)
        XCTAssertEqual(defaults.integer(forKey: "remindBeforeDays"), 0)
        XCTAssertEqual(defaults.integer(forKey: "overdueFollowUpDays"), 1)
    }

    func testExpectedRefundWindowAliasWritesThroughToTheStoredValue() {
        let settings = AppSettings(userDefaults: defaults)

        settings.defaultExpectedRefundWindow = 14

        XCTAssertEqual(settings.defaultExpectedRefundBusinessDays, 14)
        XCTAssertEqual(settings.defaultExpectedRefundWindow, 14)
    }

    func testStoredValuesOutsideTheSupportedRangeAreClampedOnLoad() {
        defaults.set(9_999, forKey: "defaultExpectedRefundBusinessDays")
        defaults.set(-7, forKey: "remindBeforeDays")
        defaults.set(0, forKey: "overdueFollowUpDays")
        defaults.set("euro", forKey: "defaultCurrencyCode")

        let settings = AppSettings(userDefaults: defaults)

        XCTAssertEqual(settings.defaultExpectedRefundBusinessDays, 60)
        XCTAssertEqual(settings.remindBeforeDays, 0)
        XCTAssertEqual(settings.overdueFollowUpDays, 1)
        XCTAssertEqual(settings.defaultCurrencyCode, "USD")
    }

    func testResetToDefaultsRestoresEveryPreference() {
        let settings = AppSettings(userDefaults: defaults)
        settings.defaultCurrencyCode = "SEK"
        settings.defaultExpectedRefundBusinessDays = 42
        settings.notificationsEnabled = true
        settings.remindBeforeDays = 12
        settings.remindOnExpectedDate = false
        settings.remindWhenOverdue = false
        settings.overdueFollowUpDays = 21
        settings.appearance = .dark

        settings.resetToDefaults()

        XCTAssertEqual(settings.defaultExpectedRefundBusinessDays, 10)
        XCTAssertEqual(
            settings.defaultCurrencyCode,
            AppSettings.normalizedCurrencyCode(
                Locale.current.currency?.identifier ?? "USD"
            )
        )
        XCTAssertFalse(settings.notificationsEnabled)
        XCTAssertEqual(settings.remindBeforeDays, 3)
        XCTAssertTrue(settings.remindOnExpectedDate)
        XCTAssertTrue(settings.remindWhenOverdue)
        XCTAssertEqual(settings.overdueFollowUpDays, 3)
        XCTAssertEqual(settings.appearance, .system)
    }

    func testNotificationPreferencesMirrorTheStoredSettings() {
        let settings = AppSettings(userDefaults: defaults)
        settings.notificationsEnabled = true
        settings.remindBeforeDays = 5
        settings.remindOnExpectedDate = false
        settings.remindWhenOverdue = true
        settings.overdueFollowUpDays = 4

        XCTAssertEqual(
            settings.notificationPreferences,
            RefundNotificationPreferences(
                isEnabled: true,
                daysBeforeExpectedDate: 5,
                remindOnExpectedDate: false,
                remindWhenOverdue: true,
                overdueFollowUpDays: 4
            )
        )
    }
}
