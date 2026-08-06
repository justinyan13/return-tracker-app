import Foundation
import Observation

@MainActor
@Observable
final class RefundFormViewModel {
    var retailerName = ""
    var itemName = ""
    var orderNumber = ""
    var amountText = ""
    var currencyCode: String

    var includesPurchaseDate = false
    var purchaseDate = Date()
    var returnDate: Date
    var shippedDate: Date?
    var includesReceivedDate = false
    var retailerReceivedDate = Date()
    var expectedRefundDate: Date
    var includesActualRefundDate = false
    var actualRefundDate = Date()

    var refundMethod: RefundMethod = .originalPaymentMethod
    var status: RefundStatus = .preparingReturn
    var trackingNumber = ""
    var returnCarrier = ""
    var notes = ""

    private(set) var didManuallyChangeExpectedDate = false
    private let calendar: Calendar
    private var defaultExpectedBusinessDays: Int
    private var statusBeforeRefunded: RefundStatus = .preparingReturn

    static let selectableStatuses = RefundStatus.allCases.filter { $0 != .overdue }

    init(
        refund: Refund? = nil,
        defaultExpectedBusinessDays: Int = 10,
        defaultCurrencyCode: String = Locale.current.currency?.identifier ?? "USD",
        calendar: Calendar = .current
    ) {
        let normalizedBusinessDays = max(defaultExpectedBusinessDays, 1)
        self.calendar = calendar
        self.defaultExpectedBusinessDays = normalizedBusinessDays

        if let refund {
            retailerName = refund.retailerName
            itemName = refund.itemName
            orderNumber = refund.orderNumber
            amountText = NSDecimalNumber(decimal: refund.refundAmount).stringValue
            currencyCode = refund.currencyCode

            includesPurchaseDate = refund.purchaseDate != nil
            purchaseDate = refund.purchaseDate ?? refund.returnDate
            returnDate = refund.returnDate
            shippedDate = refund.shippedDate
            includesReceivedDate = refund.retailerReceivedDate != nil
            retailerReceivedDate = refund.retailerReceivedDate ?? refund.returnDate
            expectedRefundDate = refund.expectedRefundDate
            actualRefundDate = refund.actualRefundDate ?? .now

            refundMethod = refund.refundMethod
            let persistedStatus = Self.normalizedWorkflowStatus(refund.status)
            if persistedStatus.isManuallyOverridingAutomaticStatus {
                status = persistedStatus
                includesActualRefundDate = false
            } else if refund.actualRefundDate != nil || persistedStatus == .refunded {
                status = .refunded
                includesActualRefundDate = true
            } else {
                status = persistedStatus
                includesActualRefundDate = false
            }
            statusBeforeRefunded = Self.openStatusBeforeRefunded(
                persistedStatus: persistedStatus,
                shippedDate: refund.shippedDate,
                retailerReceivedDate: refund.retailerReceivedDate
            )
            trackingNumber = refund.trackingNumber
            returnCarrier = refund.returnCarrier
            notes = refund.notes
            didManuallyChangeExpectedDate = true
        } else {
            let today = calendar.startOfDay(for: .now)
            currencyCode = defaultCurrencyCode
            returnDate = today
            shippedDate = nil
            expectedRefundDate = BusinessDayCalculator.addingBusinessDays(
                normalizedBusinessDays,
                to: today,
                calendar: calendar
            )
        }
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
        return Decimal(string: trimmed.replacingOccurrences(of: ",", with: ""))
    }

    var validationMessages: [String] {
        var messages: [String] = []
        if retailerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            messages.append("Enter a retailer.")
        }
        if itemName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            messages.append("Enter an item name.")
        }
        if amount == nil || amount.map({ $0 <= 0 }) == true {
            messages.append("Enter a refund amount greater than zero.")
        }
        if calendar.startOfDay(for: expectedRefundDate)
            < calendar.startOfDay(for: returnDate) {
            messages.append("The expected refund date cannot be before the return date.")
        }
        if includesPurchaseDate, isBefore(returnDate, purchaseDate) {
            messages.append("The purchase date cannot be after the return date.")
        }
        if includesReceivedDate,
           isBefore(retailerReceivedDate, retailerReceivedDateMinimum) {
            messages.append("The retailer received date cannot be before the return was shipped.")
        }
        if includesActualRefundDate,
           isBefore(actualRefundDate, actualRefundDateMinimum) {
            messages.append("The refund received date cannot be before the return milestones.")
        }
        return messages
    }

    var isValid: Bool {
        validationMessages.isEmpty
    }

    var displayedStatus: RefundStatus {
        if status.isManuallyOverridingAutomaticStatus {
            return status
        }
        if status == .refunded || includesActualRefundDate {
            return .refunded
        }
        if calendar.startOfDay(for: .now)
            > calendar.startOfDay(for: expectedRefundDate) {
            return .overdue
        }
        return Self.normalizedWorkflowStatus(status)
    }

    var retailerReceivedDateMinimum: Date {
        later(returnDate, shippedDate)
    }

    var actualRefundDateMinimum: Date {
        var minimum = later(returnDate, shippedDate)
        if includesReceivedDate {
            minimum = later(minimum, retailerReceivedDate)
        }
        return minimum
    }

    func setReturnDate(_ date: Date) {
        returnDate = date

        if includesPurchaseDate, isBefore(returnDate, purchaseDate) {
            purchaseDate = returnDate
        }

        if let shippedDate, isBefore(shippedDate, returnDate) {
            self.shippedDate = returnDate
        }

        if includesReceivedDate,
           isBefore(retailerReceivedDate, retailerReceivedDateMinimum) {
            retailerReceivedDate = retailerReceivedDateMinimum
        }

        if includesActualRefundDate,
           isBefore(actualRefundDate, actualRefundDateMinimum) {
            actualRefundDate = actualRefundDateMinimum
        }

        if didManuallyChangeExpectedDate {
            if isBefore(expectedRefundDate, returnDate) {
                expectedRefundDate = returnDate
            }
        } else {
            expectedRefundDate = BusinessDayCalculator.addingBusinessDays(
                defaultExpectedBusinessDays,
                to: calendar.startOfDay(for: returnDate),
                calendar: calendar
            )
        }
    }

    func returnDateChanged() {
        setReturnDate(returnDate)
    }

    func expectedDateChangedByUser() {
        didManuallyChangeExpectedDate = true
    }

    func setRetailerReceived(_ isIncluded: Bool) {
        includesReceivedDate = isIncluded
        guard isIncluded else {
            if status == .deliveredToRetailer {
                status = shippedDate == nil ? .preparingReturn : .shipped
                statusBeforeRefunded = status
            }
            return
        }

        if shippedDate == nil {
            shippedDate = returnDate
        }
        if isBefore(retailerReceivedDate, retailerReceivedDateMinimum) {
            retailerReceivedDate = later(.now, retailerReceivedDateMinimum)
        }
        if status == .preparingReturn || status == .shipped {
            status = .deliveredToRetailer
            statusBeforeRefunded = .deliveredToRetailer
        }
        if includesActualRefundDate,
           isBefore(actualRefundDate, actualRefundDateMinimum) {
            actualRefundDate = actualRefundDateMinimum
        }
    }

    func setRetailerReceivedDate(_ date: Date) {
        retailerReceivedDate = date
        if includesActualRefundDate,
           isBefore(actualRefundDate, actualRefundDateMinimum) {
            actualRefundDate = actualRefundDateMinimum
        }
    }

    func setActualRefundReceived(_ isIncluded: Bool) {
        includesActualRefundDate = isIncluded
        if isIncluded {
            if status != .refunded {
                statusBeforeRefunded = Self.normalizedWorkflowStatus(status)
            }
            status = .refunded
            if isBefore(actualRefundDate, actualRefundDateMinimum) {
                actualRefundDate = later(.now, actualRefundDateMinimum)
            }
        } else if status == .refunded {
            status = Self.normalizedWorkflowStatus(statusBeforeRefunded)
        }
    }

    func setStatus(_ newStatus: RefundStatus) {
        let normalizedStatus = Self.normalizedWorkflowStatus(newStatus)
        if normalizedStatus != .refunded {
            statusBeforeRefunded = normalizedStatus
        }
        status = normalizedStatus
        synchronizeMilestones(for: normalizedStatus)
    }

    func applyCreationDefaults(
        expectedBusinessDays: Int,
        currencyCode: String
    ) {
        guard retailerName.isEmpty,
              itemName.isEmpty,
              amountText.isEmpty,
              !didManuallyChangeExpectedDate else {
            return
        }

        defaultExpectedBusinessDays = max(expectedBusinessDays, 1)
        defaultCreationDate(expectedBusinessDays: defaultExpectedBusinessDays)
        self.currencyCode = currencyCode
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
    }

    func apply(to refund: Refund) {
        guard let amount else { return }
        let normalizedStatus = Self.normalizedWorkflowStatus(status)
        synchronizeMilestones(for: normalizedStatus)

        refund.retailerName = retailerName.cleaned
        refund.itemName = itemName.cleaned
        refund.orderNumber = orderNumber.cleaned
        refund.refundAmount = amount
        refund.currencyCode = currencyCode
        refund.purchaseDate = includesPurchaseDate ? purchaseDate : nil
        refund.returnDate = returnDate
        refund.shippedDate = shippedDate
        refund.retailerReceivedDate = includesReceivedDate ? retailerReceivedDate : nil
        refund.expectedRefundDate = expectedRefundDate
        refund.actualRefundDate = includesActualRefundDate ? actualRefundDate : nil
        refund.refundMethod = refundMethod
        refund.status = includesActualRefundDate ? .refunded : normalizedStatus
        refund.trackingNumber = trackingNumber.cleaned
        refund.returnCarrier = returnCarrier.cleaned
        refund.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        refund.touch()
    }

    private func defaultCreationDate(expectedBusinessDays: Int) {
        expectedRefundDate = BusinessDayCalculator.addingBusinessDays(
            max(expectedBusinessDays, 1),
            to: calendar.startOfDay(for: returnDate),
            calendar: calendar
        )
    }

    private func synchronizeMilestones(for status: RefundStatus) {
        if let shippedDate, isBefore(shippedDate, returnDate) {
            self.shippedDate = returnDate
        }

        switch status {
        case .preparingReturn:
            shippedDate = nil
            includesReceivedDate = false
            includesActualRefundDate = false
        case .shipped:
            if shippedDate == nil || isBefore(shippedDate ?? returnDate, returnDate) {
                shippedDate = later(.now, returnDate)
            }
            includesReceivedDate = false
            includesActualRefundDate = false
        case .deliveredToRetailer:
            if shippedDate == nil || isBefore(shippedDate ?? returnDate, returnDate) {
                shippedDate = returnDate
            }
            includesReceivedDate = true
            if isBefore(retailerReceivedDate, retailerReceivedDateMinimum) {
                retailerReceivedDate = later(.now, retailerReceivedDateMinimum)
            }
            includesActualRefundDate = false
        case .refundPending:
            includesActualRefundDate = false
        case .refunded:
            includesActualRefundDate = true
            if isBefore(actualRefundDate, actualRefundDateMinimum) {
                actualRefundDate = later(.now, actualRefundDateMinimum)
            }
        case .disputed, .cancelled:
            includesActualRefundDate = false
        case .overdue:
            // Overdue is always derived from the expected date.
            self.status = .refundPending
            includesActualRefundDate = false
        }
    }

    private func later(_ first: Date, _ second: Date?) -> Date {
        guard let second else { return first }
        return isBefore(first, second) ? second : first
    }

    private func isBefore(_ first: Date, _ second: Date) -> Bool {
        calendar.startOfDay(for: first) < calendar.startOfDay(for: second)
    }

    private static func normalizedWorkflowStatus(_ status: RefundStatus) -> RefundStatus {
        status == .overdue ? .refundPending : status
    }

    private static func openStatusBeforeRefunded(
        persistedStatus: RefundStatus,
        shippedDate: Date?,
        retailerReceivedDate: Date?
    ) -> RefundStatus {
        if persistedStatus != .refunded {
            return normalizedWorkflowStatus(persistedStatus)
        }
        if retailerReceivedDate != nil {
            return .refundPending
        }
        if shippedDate != nil {
            return .shipped
        }
        return .refundPending
    }
}

private extension String {
    var cleaned: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
