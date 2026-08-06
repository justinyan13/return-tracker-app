import Foundation
import UserNotifications

enum RefundReminderKind: String, CaseIterable, Identifiable, Sendable {
    case beforeExpectedDate
    case expectedDate
    case overdue
    case overdueFollowUp

    var id: String { rawValue }
}

struct PlannedRefundNotification: Equatable, Identifiable, Sendable {
    let identifier: String
    let refundID: UUID
    let kind: RefundReminderKind
    let fireDate: Date
    let title: String
    let body: String

    var id: String { identifier }
}

enum NotificationPlanner {
    static let identifierPrefix = "refund."
    static let deliveryHour = 9
    static let systemPendingRequestLimit = 64
    static let reservedPendingRequestSlots = 4
    static let maximumScheduledRefundNotifications =
        systemPendingRequestLimit - reservedPendingRequestSlots

    static func plan(
        for refund: Refund,
        preferences: RefundNotificationPreferences,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> [PlannedRefundNotification] {
        guard preferences.isEnabled,
              refund.status != .cancelled,
              refund.status != .disputed,
              refund.status != .refunded,
              refund.actualRefundDate == nil else {
            return []
        }

        let expectedDay = calendar.startOfDay(for: refund.expectedRefundDate)
        let expectedDelivery = deliveryTime(on: expectedDay, calendar: calendar)
        let overdueDay = calendar.date(byAdding: .day, value: 1, to: expectedDay) ??
            expectedDay
        let overdueDelivery = deliveryTime(on: overdueDay, calendar: calendar)
        let itemName = notificationItemName(for: refund)

        var candidates: [(RefundReminderKind, Date, String, String)] = []

        if preferences.daysBeforeExpectedDate > 0,
           let reminderDay = calendar.date(
               byAdding: .day,
               value: -preferences.daysBeforeExpectedDate,
               to: expectedDay
           ) {
            candidates.append((
                .beforeExpectedDate,
                deliveryTime(on: reminderDay, calendar: calendar),
                "Refund expected soon",
                beforeExpectedBody(
                    retailerName: refund.retailerName,
                    itemName: itemName,
                    days: preferences.daysBeforeExpectedDate
                )
            ))
        }

        if preferences.remindOnExpectedDate {
            candidates.append((
                .expectedDate,
                expectedDelivery,
                "Refund expected today",
                expectedTodayBody(
                    retailerName: refund.retailerName,
                    itemName: itemName
                )
            ))
        }

        if preferences.remindWhenOverdue {
            candidates.append((
                .overdue,
                overdueDelivery,
                "Refund may be overdue",
                overdueBody(
                    retailerName: refund.retailerName,
                    itemName: itemName
                )
            ))

            if let followUpDay = calendar.date(
                byAdding: .day,
                value: max(1, preferences.overdueFollowUpDays),
                to: overdueDay
            ) {
                candidates.append((
                    .overdueFollowUp,
                    deliveryTime(on: followUpDay, calendar: calendar),
                    "Time to follow up",
                    "The refund from \(refund.retailerName) is still unresolved. Consider contacting the retailer."
                ))
            }
        }

        return candidates
            .filter { $0.1 > now }
            .map { kind, fireDate, title, body in
                PlannedRefundNotification(
                    identifier: identifier(for: refund.id, kind: kind),
                    refundID: refund.id,
                    kind: kind,
                    fireDate: fireDate,
                    title: title,
                    body: body
                )
            }
            .sorted { $0.fireDate < $1.fireDate }
    }

    /// Produces one deterministic plan across all refunds so the nearest
    /// reminders win when the system pending-request limit is approached.
    static func plan(
        for refunds: [Refund],
        preferences: RefundNotificationPreferences,
        now: Date = .now,
        calendar: Calendar = .current,
        maximumCount: Int = maximumScheduledRefundNotifications
    ) -> [PlannedRefundNotification] {
        guard maximumCount > 0 else { return [] }

        var notificationsByIdentifier: [String: PlannedRefundNotification] = [:]
        for refund in refunds {
            for notification in plan(
                for: refund,
                preferences: preferences,
                now: now,
                calendar: calendar
            ) {
                if let existing = notificationsByIdentifier[notification.identifier] {
                    if isOrderedBefore(notification, existing) {
                        notificationsByIdentifier[notification.identifier] = notification
                    }
                } else {
                    notificationsByIdentifier[notification.identifier] = notification
                }
            }
        }

        return Array(notificationsByIdentifier.values)
            .sorted(by: isOrderedBefore)
            .prefix(maximumCount)
            .map { $0 }
    }

    static func identifier(
        for refundID: UUID,
        kind: RefundReminderKind
    ) -> String {
        "\(identifierPrefix)\(refundID.uuidString).\(kind.rawValue)"
    }

    static func identifiers(for refundID: UUID) -> [String] {
        RefundReminderKind.allCases.map {
            identifier(for: refundID, kind: $0)
        }
    }

    private static func deliveryTime(
        on date: Date,
        calendar: Calendar
    ) -> Date {
        calendar.date(
            bySettingHour: deliveryHour,
            minute: 0,
            second: 0,
            of: date
        ) ?? date
    }

    private static func notificationItemName(for refund: Refund) -> String? {
        refund.userFacingItemName
    }

    private static func beforeExpectedBody(
        retailerName: String,
        itemName: String?,
        days: Int
    ) -> String {
        if let itemName {
            return "\(retailerName) is expected to refund \(itemName) in \(days) days."
        }
        return "A refund from \(retailerName) is expected in \(days) days."
    }

    private static func expectedTodayBody(
        retailerName: String,
        itemName: String?
    ) -> String {
        if let itemName {
            return "Check whether your \(retailerName) refund for \(itemName) has arrived."
        }
        return "Check whether your refund from \(retailerName) has arrived."
    }

    private static func overdueBody(
        retailerName: String,
        itemName: String?
    ) -> String {
        if let itemName {
            return "Your \(retailerName) refund for \(itemName) was expected yesterday."
        }
        return "Your refund from \(retailerName) was expected yesterday."
    }

    private static func isOrderedBefore(
        _ lhs: PlannedRefundNotification,
        _ rhs: PlannedRefundNotification
    ) -> Bool {
        if lhs.fireDate != rhs.fireDate {
            return lhs.fireDate < rhs.fireDate
        }
        return lhs.identifier < rhs.identifier
    }
}

enum NotificationServiceError: LocalizedError {
    case pendingRequestCapacityUnavailable

    var errorDescription: String? {
        switch self {
        case .pendingRequestCapacityUnavailable:
            "Refund reminders could not be scheduled because the system notification limit was reached."
        }
    }
}

@MainActor
final class NotificationService {
    static let shared = NotificationService()

    private let center: UNUserNotificationCenter

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    func requestAuthorization() async throws -> Bool {
        try await center.requestAuthorization(options: [.alert, .badge, .sound])
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
    }

    func scheduleNotifications(
        for refund: Refund,
        preferences: RefundNotificationPreferences,
        now: Date = .now,
        calendar: Calendar = .current
    ) async throws {
        let pendingRequests = await center.pendingNotificationRequests()
        let managedIdentifiers = Set(
            NotificationPlanner.identifiers(for: refund.id)
        )
        let existingManagedRequests = pendingRequests.filter {
            managedIdentifiers.contains($0.identifier)
        }
        let nonManagedRequestCount =
            pendingRequests.count - existingManagedRequests.count
        let maximumCount = max(
            0,
            NotificationPlanner.maximumScheduledRefundNotifications -
                nonManagedRequestCount
        )
        let plan = NotificationPlanner.plan(
            for: refund,
            preferences: preferences,
            now: now,
            calendar: calendar
        )
        .prefix(maximumCount)
        .map { $0 }

        try await reconcilePendingRequests(
            with: plan,
            replacing: existingManagedRequests,
            totalPendingRequestCount: pendingRequests.count,
            calendar: calendar
        )
        center.removeDeliveredNotifications(
            withIdentifiers: Array(managedIdentifiers)
        )
    }

    func rescheduleAll(
        for refunds: [Refund],
        preferences: RefundNotificationPreferences,
        now: Date = .now,
        calendar: Calendar = .current
    ) async throws {
        let pendingRequests = await center.pendingNotificationRequests()
        let existingRefundRequests = pendingRequests.filter {
            $0.identifier.hasPrefix(NotificationPlanner.identifierPrefix)
        }

        guard preferences.isEnabled else {
            center.removePendingNotificationRequests(
                withIdentifiers: existingRefundRequests.map(\.identifier)
            )
            await removeDeliveredRefundReminders()
            return
        }

        let nonRefundRequestCount =
            pendingRequests.count - existingRefundRequests.count
        let maximumRefundCount = max(
            0,
            NotificationPlanner.maximumScheduledRefundNotifications -
                nonRefundRequestCount
        )
        let plan = NotificationPlanner.plan(
            for: refunds,
            preferences: preferences,
            now: now,
            calendar: calendar,
            maximumCount: maximumRefundCount
        )

        try await reconcilePendingRequests(
            with: plan,
            replacing: existingRefundRequests,
            totalPendingRequestCount: pendingRequests.count,
            calendar: calendar
        )
        await removeDeliveredRefundReminders()
    }

    func cancelNotifications(for refundID: UUID) {
        let identifiers = NotificationPlanner.identifiers(for: refundID)
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
        center.removeDeliveredNotifications(withIdentifiers: identifiers)
    }

    func removeAllRefundReminders() async {
        let pending = await center.pendingNotificationRequests()
        let identifiers = pending
            .map(\.identifier)
            .filter { $0.hasPrefix(NotificationPlanner.identifierPrefix) }
        center.removePendingNotificationRequests(withIdentifiers: identifiers)

        await removeDeliveredRefundReminders()
    }

    private func removeDeliveredRefundReminders() async {
        let delivered = await center.deliveredNotifications()
        let deliveredIdentifiers = delivered
            .map(\.request.identifier)
            .filter { $0.hasPrefix(NotificationPlanner.identifierPrefix) }
        center.removeDeliveredNotifications(withIdentifiers: deliveredIdentifiers)
    }

    private func notificationRequest(
        for item: PlannedRefundNotification,
        calendar: Calendar
    ) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = item.title
        content.body = item.body
        content.sound = .default
        content.userInfo = [
            "refundID": item.refundID.uuidString,
            "reminderKind": item.kind.rawValue
        ]

        let components = calendar.dateComponents(
            [.calendar, .timeZone, .year, .month, .day, .hour, .minute],
            from: item.fireDate
        )
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: components,
            repeats: false
        )
        return UNNotificationRequest(
            identifier: item.identifier,
            content: content,
            trigger: trigger
        )
    }

    private func reconcilePendingRequests(
        with plan: [PlannedRefundNotification],
        replacing existingManagedRequests: [UNNotificationRequest],
        totalPendingRequestCount: Int,
        calendar: Calendar
    ) async throws {
        let existingIdentifiers = Set(
            existingManagedRequests.map(\.identifier)
        )
        let desiredIdentifiers = Set(plan.map(\.identifier))
        let replacementPlan = plan.filter {
            existingIdentifiers.contains($0.identifier)
        }
        let additionPlan = plan.filter {
            !existingIdentifiers.contains($0.identifier)
        }

        // Replacing a stable identifier does not consume another pending slot,
        // so update those requests before removing any prior coverage.
        for notification in replacementPlan {
            try await center.add(
                notificationRequest(for: notification, calendar: calendar)
            )
        }

        var staleRequests = existingManagedRequests
            .filter { !desiredIdentifiers.contains($0.identifier) }
            .sorted(by: leastUrgentFirst)
        var availableSlots = max(
            0,
            NotificationPlanner.maximumScheduledRefundNotifications -
                totalPendingRequestCount
        )

        // Free at most one stale slot for each new request. If adding that
        // request fails, restore the request that made room for it.
        for notification in additionPlan {
            var displacedRequest: UNNotificationRequest?
            if availableSlots == 0 {
                guard !staleRequests.isEmpty else {
                    throw NotificationServiceError.pendingRequestCapacityUnavailable
                }
                let staleRequest = staleRequests.removeFirst()
                displacedRequest = staleRequest
                center.removePendingNotificationRequests(
                    withIdentifiers: [staleRequest.identifier]
                )
                availableSlots += 1
            }

            do {
                try await center.add(
                    notificationRequest(for: notification, calendar: calendar)
                )
                availableSlots -= 1
            } catch {
                if let displacedRequest {
                    try? await center.add(displacedRequest)
                }
                throw error
            }
        }

        center.removePendingNotificationRequests(
            withIdentifiers: staleRequests.map(\.identifier)
        )
    }

    private func leastUrgentFirst(
        _ lhs: UNNotificationRequest,
        _ rhs: UNNotificationRequest
    ) -> Bool {
        let lhsDate = nextTriggerDate(for: lhs)
        let rhsDate = nextTriggerDate(for: rhs)
        if lhsDate != rhsDate {
            return lhsDate > rhsDate
        }
        return lhs.identifier > rhs.identifier
    }

    private func nextTriggerDate(
        for request: UNNotificationRequest
    ) -> Date {
        if let trigger = request.trigger as? UNCalendarNotificationTrigger {
            return trigger.nextTriggerDate() ?? .distantFuture
        }
        if let trigger = request.trigger as? UNTimeIntervalNotificationTrigger {
            return trigger.nextTriggerDate() ?? .distantFuture
        }
        return .distantFuture
    }
}
