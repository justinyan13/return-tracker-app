import SwiftData
import SwiftUI

@main
struct RefundTrackerApp: App {
    @State private var settings: AppSettings

    private let modelContainer: ModelContainer
    private let startupErrorMessage: String?
    private let isUITesting: Bool

    init() {
        RefundChrome.apply()

        let arguments = ProcessInfo.processInfo.arguments
        let isUITesting = arguments.contains("--ui-testing")
        self.isUITesting = isUITesting

        let userDefaults: UserDefaults
        if isUITesting,
           let testDefaults = UserDefaults(suiteName: "RefundTrackerUITests") {
            testDefaults.removePersistentDomain(forName: "RefundTrackerUITests")
            userDefaults = testDefaults
        } else {
            userDefaults = .standard
        }
        _settings = State(initialValue: AppSettings(userDefaults: userDefaults))

        let schema = Schema([Refund.self, RefundAttachment.self])
        let primaryConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: isUITesting
        )

        do {
            let container = try ModelContainer(
                for: schema,
                configurations: [primaryConfiguration]
            )
            modelContainer = container
            startupErrorMessage = nil
        } catch {
            let fallbackConfiguration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: true
            )
            do {
                modelContainer = try ModelContainer(
                    for: schema,
                    configurations: [fallbackConfiguration]
                )
                startupErrorMessage =
                    "Refund Tracker couldn’t open its saved data, so it started in a temporary recovery mode. Changes made in this session won’t be retained."
            } catch {
                fatalError("Unable to create the SwiftData container: \(error)")
            }
        }

        if arguments.contains("--ui-testing-seed") {
            Self.seedUITestData(in: modelContainer)
        }
    }

    var body: some Scene {
        WindowGroup {
            RootTabView(
                isUITesting: isUITesting,
                startupErrorMessage: startupErrorMessage
            )
            .environment(settings)
            .tint(RefundTheme.ink)
            .preferredColorScheme(settings.appearance.colorScheme)
        }
        .modelContainer(modelContainer)
    }

    private static func seedUITestData(in container: ModelContainer) {
        let context = ModelContext(container)
        let calendar = Calendar(identifier: .gregorian)
        let today = calendar.startOfDay(for: .now)

        let overdue = Refund(
            retailerName: "Wayfair",
            itemName: "Overdue floor lamp",
            orderNumber: "WF-10452",
            refundAmount: 146.75,
            currencyCode: "USD",
            returnDate: calendar.date(byAdding: .day, value: -18, to: today) ?? today,
            retailerReceivedDate: calendar.date(byAdding: .day, value: -14, to: today),
            expectedRefundDate: calendar.date(byAdding: .day, value: -4, to: today) ?? today,
            refundMethod: .originalPaymentMethod,
            status: .refundPending
        )

        let upcoming = Refund(
            retailerName: "Allbirds",
            itemName: "Expected next week",
            orderNumber: "AB-9921",
            refundAmount: 98,
            currencyCode: "USD",
            returnDate: calendar.date(byAdding: .day, value: -2, to: today) ?? today,
            expectedRefundDate: calendar.date(byAdding: .day, value: 7, to: today) ?? today,
            refundMethod: .originalPaymentMethod,
            status: .shipped
        )

        let completed = Refund(
            retailerName: "Patagonia",
            itemName: "Completed fleece return",
            orderNumber: "PAT-620491",
            refundAmount: 139,
            currencyCode: "USD",
            returnDate: calendar.date(
                byAdding: .day,
                value: -16,
                to: today
            ) ?? today,
            expectedRefundDate: calendar.date(
                byAdding: .day,
                value: -4,
                to: today
            ) ?? today,
            actualRefundDate: calendar.date(
                byAdding: .day,
                value: -2,
                to: today
            ),
            refundMethod: .originalPaymentMethod,
            status: .refunded
        )

        context.insert(overdue)
        context.insert(upcoming)
        context.insert(completed)
        try? context.save()
    }
}

private extension AppAppearance {
    var colorScheme: ColorScheme? {
        switch self {
        case .system:
            nil
        case .light:
            .light
        case .dark:
            .dark
        }
    }
}
