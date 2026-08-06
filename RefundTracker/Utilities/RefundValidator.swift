import Foundation

enum RefundValidationError: LocalizedError, Equatable {
    case missingRetailer
    case missingItemName
    case invalidAmount
    case expectedDateBeforeReturnDate
    case unsupportedCurrencyCode

    var errorDescription: String? {
        switch self {
        case .missingRetailer:
            "Enter a retailer."
        case .missingItemName:
            "Enter an item name."
        case .invalidAmount:
            "Enter a refund amount greater than zero."
        case .expectedDateBeforeReturnDate:
            "The expected refund date cannot be before the return date."
        case .unsupportedCurrencyCode:
            "Enter a valid three-letter currency code."
        }
    }
}

enum RefundValidator {
    static func validate(
        retailerName: String,
        itemName: String,
        refundAmount: Decimal,
        currencyCode: String,
        returnDate: Date,
        expectedRefundDate: Date,
        calendar: Calendar = .current
    ) -> [RefundValidationError] {
        var errors: [RefundValidationError] = []

        if retailerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append(.missingRetailer)
        }
        if itemName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append(.missingItemName)
        }
        if refundAmount <= 0 {
            errors.append(.invalidAmount)
        }

        let normalizedCurrency = currencyCode
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
        if normalizedCurrency.count != 3 ||
            normalizedCurrency.rangeOfCharacter(from: .letters.inverted) != nil {
            errors.append(.unsupportedCurrencyCode)
        }

        if calendar.startOfDay(for: expectedRefundDate) <
            calendar.startOfDay(for: returnDate) {
            errors.append(.expectedDateBeforeReturnDate)
        }

        return errors
    }

    static func validate(
        _ refund: Refund,
        calendar: Calendar = .current
    ) -> [RefundValidationError] {
        validate(
            retailerName: refund.retailerName,
            itemName: refund.itemName,
            refundAmount: refund.refundAmount,
            currencyCode: refund.currencyCode,
            returnDate: refund.returnDate,
            expectedRefundDate: refund.expectedRefundDate,
            calendar: calendar
        )
    }
}
