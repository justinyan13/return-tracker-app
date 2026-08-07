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

    /// Insights never converts between currencies, so a preferred currency with
    /// no records would render an all-zero screen. Fall back to a currency that
    /// is actually present, the same way the dashboard picks its headline.
    func displayCurrencyCode(
        for refunds: [Refund],
        preferred: String
    ) -> String {
        let normalized = preferred.uppercased()
        let available = Set(refunds.map { $0.currencyCode.uppercased() })
        guard !available.contains(normalized) else { return normalized }
        return available.sorted().first ?? normalized
    }

    func refresh() {
        referenceDate = .now
    }
}
