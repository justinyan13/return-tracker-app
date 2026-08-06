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
                dateString(refund.purchaseDate),
                dateString(refund.returnDate),
                dateString(refund.shippedDate),
                dateString(refund.retailerReceivedDate),
                dateString(refund.expectedRefundDate),
                dateString(refund.actualRefundDate),
                refund.trackingNumber,
                refund.returnCarrier,
                refund.notes,
                dateTimeString(refund.createdDate),
                dateTimeString(refund.lastUpdatedDate)
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
            filename ?? "Refunds-\(filenameDateString(now)).csv"
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
        guard value.contains(",") ||
                value.contains("\"") ||
                value.contains("\n") ||
                value.contains("\r") else {
            return value
        }
        return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
    }

    private static func dateString(_ date: Date?) -> String {
        guard let date else { return "" }
        return date.formatted(
            .iso8601
                .year()
                .month()
                .day()
                .dateSeparator(.dash)
        )
    }

    private static func dateTimeString(_ date: Date) -> String {
        ISO8601DateFormatter().string(from: date)
    }

    private static func filenameDateString(_ date: Date) -> String {
        date.formatted(
            .iso8601
                .year()
                .month()
                .day()
                .dateSeparator(.dash)
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
