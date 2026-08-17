import Foundation

enum CSVExportError: LocalizedError {
    case unableToEncode

    var errorDescription: String? {
        switch self {
        case .unableToEncode:
            "The refund data could not be encoded as a CSV file."
        }
    }
}

struct CSVExportService {
    private static let headers = [
        "ID",
        "Retailer",
        "Item",
        "Order Number",
        "Amount",
        "Currency",
        "Status",
        "Refund Method",
        "Purchase Date",
        "Return Date",
        "Shipped Date",
        "Retailer Received Date",
        "Expected Refund Date",
        "Actual Refund Date",
        "Tracking Number",
        "Return Carrier",
        "Notes",
        "Created Date",
        "Last Updated Date"
    ]

    static func makeCSV(
        from refunds: [Refund],
        now: Date = .now,
        calendar: Calendar = .current
    ) -> String {
        var rows = [headers.map(escape).joined(separator: ",")]
        rows.reserveCapacity(refunds.count + 1)

        let timeZone = calendar.timeZone

        for refund in refunds {
            let fields = [
                refund.id.uuidString,
                refund.retailerName,
                refund.itemName,
                refund.orderNumber,
                RefundFormatters.decimalString(refund.refundAmount),
                refund.currencyCode,
                refund.effectiveStatus(on: now, calendar: calendar).displayName,
                refund.refundMethod.displayName,
                dateString(refund.purchaseDate, timeZone: timeZone),
                dateString(refund.returnDate, timeZone: timeZone),
                dateString(refund.shippedDate, timeZone: timeZone),
                dateString(refund.retailerReceivedDate, timeZone: timeZone),
                dateString(refund.expectedRefundDate, timeZone: timeZone),
                dateString(refund.actualRefundDate, timeZone: timeZone),
                refund.trackingNumber,
                refund.returnCarrier,
                refund.notes,
                dateTimeString(refund.createdDate, timeZone: timeZone),
                dateTimeString(refund.lastUpdatedDate, timeZone: timeZone)
            ]
            rows.append(fields.map(escape).joined(separator: ","))
        }

        // A trailing newline improves compatibility with spreadsheet importers.
        return rows.joined(separator: "\r\n") + "\r\n"
    }

    @discardableResult
    static func exportFile(
        from refunds: [Refund],
        filename: String? = nil,
        now: Date = .now,
        calendar: Calendar = .current,
        directory: URL = FileManager.default.temporaryDirectory
    ) throws -> URL {
        let safeFilename = sanitizedFilename(
            filename ??
                "Refunds-\(filenameDateString(now, timeZone: calendar.timeZone)).csv"
        )
        let outputURL = directory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent(safeFilename, isDirectory: false)

        try FileManager.default.createDirectory(
            at: outputURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        let csv = makeCSV(from: refunds, now: now, calendar: calendar)
        guard let data = csv.data(using: .utf8) else {
            throw CSVExportError.unableToEncode
        }
        try data.write(to: outputURL, options: .atomic)
        return outputURL
    }

    static func escape(_ value: String) -> String {
        let value = neutralizingFormulaPrefix(value)
        guard value.contains(",") ||
                value.contains("\"") ||
                value.contains("\n") ||
                value.contains("\r") else {
            return value
        }
        return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
    }

    /// Spreadsheets treat a leading `=`, `+`, `-`, or `@` as the start of a
    /// formula, so a note like "+1 800-555-0199" imports as `#NAME?` — and a
    /// crafted one can read other cells. Quoting does not suppress that; a
    /// leading apostrophe does, and spreadsheets strip it on display.
    private static func neutralizingFormulaPrefix(_ value: String) -> String {
        guard let first = value.first,
              "=+-@\t\r".contains(first) else {
            return value
        }
        return "'\(value)"
    }

    /// Every date the app stores is a *local* midnight, so it has to be rendered
    /// in the same zone to name the same day. `Date.ISO8601FormatStyle` defaults
    /// to GMT, which pushes each date a day earlier everywhere east of it.
    private static func dateString(_ date: Date?, timeZone: TimeZone) -> String {
        guard let date else { return "" }
        return date.formatted(
            Date.ISO8601FormatStyle(dateSeparator: .dash, timeZone: timeZone)
                .year()
                .month()
                .day()
        )
    }

    private static func dateTimeString(_ date: Date, timeZone: TimeZone) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = timeZone
        return formatter.string(from: date)
    }

    private static func filenameDateString(
        _ date: Date,
        timeZone: TimeZone
    ) -> String {
        date.formatted(
            Date.ISO8601FormatStyle(dateSeparator: .dash, timeZone: timeZone)
                .year()
                .month()
                .day()
        )
    }

    private static func sanitizedFilename(_ filename: String) -> String {
        let invalid = CharacterSet(charactersIn: "/:\\")
            .union(.newlines)
            .union(.controlCharacters)
        let components = filename.components(separatedBy: invalid)
        let joined = components.filter { !$0.isEmpty }.joined(separator: "-")
        let base = joined.isEmpty ? "Refunds.csv" : joined
        return base.lowercased().hasSuffix(".csv") ? base : "\(base).csv"
    }
}
