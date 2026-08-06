import Foundation
import Observation

@MainActor
@Observable
final class DashboardViewModel {
    private(set) var referenceDate = Date.now

    func metrics(for refunds: [Refund]) -> DashboardMetrics {
        DashboardCalculator.calculate(
            refunds: refunds,
            now: referenceDate,
            calendar: .current,
            upcomingDays: 14
        )
    }

    func refresh(at date: Date = .now) {
        referenceDate = date
    }
}
