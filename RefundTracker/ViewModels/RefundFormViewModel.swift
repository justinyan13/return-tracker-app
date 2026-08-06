import Foundation
import Observation

@MainActor
@Observable
final class RefundFormViewModel {
    var retailerName: String
    var amountText: String
    private(set) var currencyCode: String
    var returnDate: Date
    private(set) var expectedRefundDate: Date

    let isEditing: Bool
    let shippedDateUpperBound: Date
    let tracksShipmentDate: Bool

    private let calendar: Calendar
    private let originalTrackedDate: Date?
    private var defaultExpectedBusinessDays: Int
    private var shouldDeriveExpectedDate: Bool

    init(
        refund: Refund? = nil,
        defaultExpectedBusinessDays: Int = 10,
        defaultCurrencyCode: String = Locale.current.currency?.identifier ?? "USD",
        calendar: Calendar = .current,
        now: Date = .now
    ) {
        let businessDays = max(defaultExpectedBusinessDays, 1)
        let today = calendar.startOfDay(for: now)

        self.calendar = calendar
        self.defaultExpectedBusinessDays = businessDays
        isEditing = refund != nil

        if let refund {
            let savedTrackedDate = refund.shippedDate ?? refund.returnDate
            let upperBound = Self.earliestDate(
                among: [
                    now,
                    refund.retailerReceivedDate,
                    refund.actualRefundDate
                ]
            ) ?? now
            retailerName = refund.retailerName
            amountText = NSDecimalNumber(decimal: refund.refundAmount).stringValue
            currencyCode = Self.normalizedCurrencyCode(refund.currencyCode)
            returnDate = min(savedTrackedDate, upperBound)
            expectedRefundDate = refund.expectedRefundDate
            originalTrackedDate = savedTrackedDate
            shippedDateUpperBound = upperBound
            tracksShipmentDate = refund.shippedDate != nil
            shouldDeriveExpectedDate = false
        } else {
            retailerName = ""
            amountText = ""
            currencyCode = Self.normalizedCurrencyCode(defaultCurrencyCode)
            returnDate = today
            expectedRefundDate = BusinessDayCalculator.addingBusinessDays(
                businessDays,
                to: today,
                calendar: calendar
            )
            originalTrackedDate = nil
            shippedDateUpperBound = now
            tracksShipmentDate = true
            shouldDeriveExpectedDate = true
        }
    }

    var trackedDateTitle: String {
        tracksShipmentDate ? "Shipped date" : "Return date"
    }

    var trackedDateSymbol: String {
        tracksShipmentDate ? "shippingbox.fill" : "arrow.uturn.backward.circle.fill"
    }

    var amount: Decimal? {
        let trimmed = amountText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = .current
        formatter.generatesDecimalNumbers = true

        if let number = formatter.number(from: trimmed) as? NSDecimalNumber {
            return number.decimalValue
        }

        return Decimal(
            string: trimmed.replacingOccurrences(of: ",", with: "")
        )
    }

    var validationMessages: [String] {
        var messages: [String] = []
        if retailerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            messages.append("Enter a merchant name.")
        }
        if amount == nil || amount.map({ $0 <= 0 }) == true {
            messages.append("Enter a refund amount greater than zero.")
        }
        return messages
    }

    var isValid: Bool {
        validationMessages.isEmpty
    }

    func applySettings(
        expectedBusinessDays: Int,
        defaultCurrencyCode: String
    ) {
        defaultExpectedBusinessDays = max(expectedBusinessDays, 1)

        if !isEditing {
            currencyCode = Self.normalizedCurrencyCode(defaultCurrencyCode)
        }

        if !isEditing || shouldDeriveExpectedDate {
            deriveExpectedDate()
        }
    }

    func setTrackedDate(_ date: Date) {
        returnDate = min(
            calendar.startOfDay(for: date),
            calendar.startOfDay(for: shippedDateUpperBound)
        )
        shouldDeriveExpectedDate = true
        deriveExpectedDate()
    }

    func apply(to refund: Refund) {
        guard let amount else { return }

        refund.retailerName = retailerName
            .trimmingCharacters(in: .whitespacesAndNewlines)
        refund.refundAmount = amount
        refund.currencyCode = currencyCode

        if refund.itemName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            refund.itemName = Refund.simplifiedItemPlaceholder
        }

        if !isEditing {
            refund.returnDate = returnDate
            refund.shippedDate = returnDate
            deriveExpectedDate()
            refund.expectedRefundDate = expectedRefundDate
            refund.status = .shipped
        } else if trackedDateChanged {
            refund.returnDate = returnDate
            deriveExpectedDate()
            refund.expectedRefundDate = expectedRefundDate

            if tracksShipmentDate {
                refund.shippedDate = returnDate

                if refund.status == .preparingReturn {
                    refund.status = .shipped
                }
            }
        }

        refund.touch()
    }

    private var trackedDateChanged: Bool {
        guard let originalTrackedDate else { return true }
        return !calendar.isDate(returnDate, inSameDayAs: originalTrackedDate)
    }

    private func deriveExpectedDate() {
        expectedRefundDate = BusinessDayCalculator.addingBusinessDays(
            defaultExpectedBusinessDays,
            to: calendar.startOfDay(for: returnDate),
            calendar: calendar
        )
    }

    private static func normalizedCurrencyCode(_ currencyCode: String) -> String {
        let normalized = currencyCode
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
        return normalized.count == 3 ? normalized : "USD"
    }

    private static func earliestDate(among dates: [Date?]) -> Date? {
        dates.compactMap { $0 }.min()
    }
}
