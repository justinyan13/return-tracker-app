import Foundation
import Observation

@MainActor
@Observable
final class RefundFormViewModel {
    var retailerName: String
    var itemName: String
    var amountText: String
    var coverEmoji: String
    private(set) var currencyCode: String
    var returnDate: Date
    private(set) var expectedRefundDate: Date

    /// What the single date field on the form actually means.
    enum TrackedDateKind {
        /// The day the return went in the post.
        case shipped
        /// The deadline for a return that still needs sending.
        case shipBy
        /// The day the return was started, for records saved before ship-by
        /// deadlines existed. Reinterpreting those as deadlines would rewrite
        /// what the user originally entered, so they keep their old meaning.
        case returnStarted
    }

    /// Whether the return is already in the post. When false the tracked date
    /// stops being a record of what happened and becomes a deadline.
    var hasShipped: Bool {
        didSet {
            guard hasShipped != oldValue else { return }
            // The two modes point in opposite directions in time, so a date
            // valid for one is usually invalid for the other.
            returnDate = hasShipped
                ? min(returnDate, shippedDateUpperBound)
                : max(returnDate, today)
            shouldDeriveExpectedDate = true
            deriveExpectedDate()
        }
    }

    let isEditing: Bool
    let shippedDateUpperBound: Date
    /// Whether this return can still be switched between shipped and pending.
    /// Only new ones can: an existing return moves to shipped through the
    /// detail screen's "Mark shipped" action, which stamps the real date.
    let canChooseShipmentState: Bool

    private let calendar: Calendar
    private let today: Date
    private let originalTrackedDate: Date?
    private let savedTrackedDateKind: TrackedDateKind
    private var defaultExpectedBusinessDays: Int
    private var shouldDeriveExpectedDate: Bool
    /// Whether the currency was picked on the form itself.
    private var didChooseCurrency = false

    /// For a new return the toggle decides; an existing one keeps whatever it
    /// was saved as.
    var trackedDateKind: TrackedDateKind {
        canChooseShipmentState
            ? (hasShipped ? .shipped : .shipBy)
            : savedTrackedDateKind
    }

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
        self.today = today
        self.defaultExpectedBusinessDays = businessDays
        isEditing = refund != nil
        canChooseShipmentState = refund == nil

        if let refund {
            let kind: TrackedDateKind
            if refund.shippedDate != nil {
                kind = .shipped
            } else if refund.shipByDate != nil {
                kind = .shipBy
            } else {
                kind = .returnStarted
            }
            savedTrackedDateKind = kind

            let savedTrackedDate = refund.shipByDate
                ?? refund.shippedDate
                ?? refund.returnDate
            let upperBound = Self.earliestDate(
                among: [
                    now,
                    refund.retailerReceivedDate,
                    refund.actualRefundDate
                ]
            ) ?? now
            retailerName = refund.retailerName
            // `userFacingItemName` hides the placeholder written for records
            // saved without an item, so it never shows up as literal text.
            itemName = refund.userFacingItemName ?? ""
            amountText = NSDecimalNumber(decimal: refund.refundAmount).stringValue
            coverEmoji = refund.displayCoverEmoji
            currencyCode = Self.normalizedCurrencyCode(refund.currencyCode)
            // A ship-by deadline is allowed to sit in the future; the other
            // two kinds record something that already happened.
            returnDate = kind == .shipBy
                ? savedTrackedDate
                : min(savedTrackedDate, upperBound)
            expectedRefundDate = refund.expectedRefundDate
            originalTrackedDate = savedTrackedDate
            shippedDateUpperBound = upperBound
            hasShipped = kind == .shipped
            shouldDeriveExpectedDate = false
        } else {
            retailerName = ""
            itemName = ""
            amountText = ""
            coverEmoji = RefundCoverEmoji.random()
            currencyCode = Self.normalizedCurrencyCode(defaultCurrencyCode)
            returnDate = today
            expectedRefundDate = BusinessDayCalculator.addingBusinessDays(
                businessDays,
                to: today,
                calendar: calendar
            )
            savedTrackedDateKind = .shipped
            originalTrackedDate = nil
            shippedDateUpperBound = now
            hasShipped = true
            shouldDeriveExpectedDate = true
        }
    }

    var trackedDateTitle: String {
        switch trackedDateKind {
        case .shipped: "Shipped date"
        case .shipBy: "Send by"
        case .returnStarted: "Return date"
        }
    }

    var trackedDateSymbol: String {
        switch trackedDateKind {
        case .shipped: "shippingbox.fill"
        case .shipBy: "calendar.badge.exclamationmark"
        case .returnStarted: "arrow.uturn.backward.circle.fill"
        }
    }

    /// A deadline can only be today or later; the other two kinds record
    /// something that already happened, so they cap at the present.
    ///
    /// A saved deadline that has already lapsed is a state the app supports
    /// (`isShipmentOverdue`), so the lower bound stretches back to include it —
    /// otherwise editing such a return hands the picker a selection outside its
    /// own range and the date the user set becomes unrepresentable.
    var trackedDateRange: ClosedRange<Date> {
        guard trackedDateKind == .shipBy else {
            return Date.distantPast...shippedDateUpperBound
        }
        let lowerBound = min(today, calendar.startOfDay(for: returnDate))
        return lowerBound...Date.distantFuture
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

        if !isEditing && !didChooseCurrency {
            currencyCode = Self.normalizedCurrencyCode(defaultCurrencyCode)
        }

        if !isEditing || shouldDeriveExpectedDate {
            deriveExpectedDate()
        }
    }

    /// Sets the currency for this refund alone. The default in Settings is
    /// left untouched, and a later `applySettings` no longer overwrites the
    /// choice.
    func setCurrencyCode(_ code: String) {
        didChooseCurrency = true
        currencyCode = Self.normalizedCurrencyCode(code)
    }

    func setTrackedDate(_ date: Date) {
        let day = calendar.startOfDay(for: date)
        let range = trackedDateRange
        returnDate = trackedDateKind == .shipBy
            ? max(day, range.lowerBound)
            : min(day, calendar.startOfDay(for: shippedDateUpperBound))
        shouldDeriveExpectedDate = true
        deriveExpectedDate()
    }

    func apply(to refund: Refund) {
        guard let amount else { return }

        refund.retailerName = retailerName
            .trimmingCharacters(in: .whitespacesAndNewlines)
        refund.refundAmount = amount
        refund.currencyCode = currencyCode
        refund.coverEmoji = coverEmoji.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        let trimmedItemName = itemName
            .trimmingCharacters(in: .whitespacesAndNewlines)
        refund.itemName = trimmedItemName.isEmpty
            ? Refund.simplifiedItemPlaceholder
            : trimmedItemName

        if !isEditing {
            deriveExpectedDate()
            refund.expectedRefundDate = expectedRefundDate

            switch trackedDateKind {
            case .shipped, .returnStarted:
                refund.returnDate = returnDate
                refund.shippedDate = returnDate
                refund.shipByDate = nil
                refund.status = .shipped
            case .shipBy:
                // Nothing has been posted yet, so the return started today and
                // the picked date is the deadline to get it sent.
                refund.returnDate = today
                refund.shippedDate = nil
                refund.shipByDate = returnDate
                refund.status = .preparingReturn
            }
        } else if trackedDateChanged {
            deriveExpectedDate()
            refund.expectedRefundDate = expectedRefundDate

            switch trackedDateKind {
            case .shipped:
                refund.returnDate = returnDate
                refund.shippedDate = returnDate
                refund.shipByDate = nil
            case .shipBy:
                refund.shipByDate = returnDate
            case .returnStarted:
                // Pre-deadline record: the date still means when the return
                // was started, and editing it must not invent a shipment.
                refund.returnDate = returnDate
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
