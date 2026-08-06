import Foundation

enum RefundFormatters {
    static func currency(
        _ amount: Decimal,
        code: String,
        locale: Locale = .current
    ) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = locale
        formatter.currencyCode = code
        return formatter.string(from: amount as NSDecimalNumber) ??
            "\(code) \(NSDecimalNumber(decimal: amount).stringValue)"
    }

    static func shortDate(_ date: Date, locale: Locale = .current) -> String {
        date.formatted(
            Date.FormatStyle(date: .abbreviated, time: .omitted).locale(locale)
        )
    }

    static func decimalString(_ value: Decimal) -> String {
        NSDecimalNumber(decimal: value).stringValue
    }
}
