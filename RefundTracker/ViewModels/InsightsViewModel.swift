import Foundation
import Observation

@MainActor
@Observable
final class InsightsViewModel {
    private(set) var referenceDate = Date.now

    func metrics(
        for refunds: [Refund],
        currencyCode: String,
        calendar: Calendar = .current
    ) -> InsightsMetrics {
        InsightsCalculator.calculate(
            refunds: refunds,
            currencyCode: currencyCode,
            now: referenceDate,
            calendar: calendar,
            monthCount: 6
        )
    }

    func outstandingMetrics(
        for refunds: [Refund],
        calendar: Calendar = .current
    ) -> DashboardMetrics {
        DashboardCalculator.calculate(
            refunds: refunds,
            now: referenceDate,
            calendar: calendar
        )
    }

    /// Completed Insights never converts currencies. If the preferred currency
    /// has no completed refunds, use one that does instead of showing a false
    /// all-zero history while another currency has landed.
    func completedCurrencyCode(
        for refunds: [Refund],
        preferred: String,
        calendar: Calendar = .current
    ) -> String {
        let normalized = preferred.uppercased()
        let available = Set(
            refunds
                .filter {
                    $0.effectiveStatus(
                        on: referenceDate,
                        calendar: calendar
                    ) == .refunded
                }
                .map { $0.currencyCode.uppercased() }
        )
        guard !available.contains(normalized) else { return normalized }
        return available.sorted().first ?? normalized
    }

    func refresh(at date: Date = .now) {
        referenceDate = date
    }
}
