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

    func refresh() {
        referenceDate = .now
    }
}
