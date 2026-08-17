import XCTest
@testable import RefundTracker

final class CSVExportServiceTests: XCTestCase {
    func testCSVEscapesCommasQuotesAndNewlines() {
        let now = DomainTestSupport.date(2026, 8, 6)
        let refund = Refund(
            retailerName: "Shop, Inc.",
            itemName: "The \"Best\" Jacket",
            orderNumber: "ORDER-1",
            refundAmount: Decimal(string: "49.95")!,
            currencyCode: "USD",
            returnDate: DomainTestSupport.date(2026, 8, 1),
            expectedRefundDate: DomainTestSupport.date(2026, 8, 10),
            refundMethod: .originalPaymentMethod,
            status: .refundPending,
            notes: "First line\nSecond line"
        )

        let csv = CSVExportService.makeCSV(
            from: [refund],
            now: now,
            calendar: DomainTestSupport.calendar
        )

        XCTAssertTrue(csv.hasPrefix("ID,Retailer,Item,"))
        XCTAssertTrue(csv.contains("\"Shop, Inc.\""))
        XCTAssertTrue(csv.contains("\"The \"\"Best\"\" Jacket\""))
        XCTAssertTrue(csv.contains("\"First line\nSecond line\""))
        XCTAssertTrue(csv.contains(",49.95,USD,Refund pending,"))
        XCTAssertTrue(csv.hasSuffix("\r\n"))
    }

    func testCSVIncludesActualDateAndTrackingFields() {
        let refund = Refund(
            retailerName: "Store",
            itemName: "Shoes",
            refundAmount: 80,
            currencyCode: "USD",
            returnDate: DomainTestSupport.date(2026, 7, 1),
            expectedRefundDate: DomainTestSupport.date(2026, 7, 15),
            actualRefundDate: DomainTestSupport.date(2026, 7, 12),
            status: .refunded,
            trackingNumber: "TRACK123",
            returnCarrier: "UPS"
        )

        let csv = CSVExportService.makeCSV(
            from: [refund],
            now: DomainTestSupport.date(2026, 8, 6),
            calendar: DomainTestSupport.calendar
        )

        XCTAssertTrue(csv.contains("2026-07-12"))
        XCTAssertTrue(csv.contains("TRACK123,UPS"))
        XCTAssertTrue(csv.contains(",Refunded,"))
    }

    /// Dates are stored as local midnight, so rendering them in GMT named the
    /// previous day for every zone east of it.
    func testDateColumnsUseTheSuppliedCalendarsTimeZone() {
        var berlin = Calendar(identifier: .gregorian)
        berlin.timeZone = TimeZone(identifier: "Europe/Berlin")!
        let localMidnight = berlin.date(
            from: DateComponents(year: 2026, month: 8, day: 14)
        )!

        let refund = Refund(
            retailerName: "Zara",
            itemName: "Jacket",
            refundAmount: 80,
            currencyCode: "EUR",
            returnDate: localMidnight,
            expectedRefundDate: localMidnight,
            status: .shipped
        )

        let csv = CSVExportService.makeCSV(
            from: [refund],
            now: localMidnight,
            calendar: berlin
        )

        XCTAssertTrue(csv.contains("2026-08-14"))
        XCTAssertFalse(csv.contains("2026-08-13"))
    }

    func testLeadingFormulaCharactersAreNeutralized() {
        XCTAssertEqual(CSVExportService.escape("+1 800-555-0199"), "'+1 800-555-0199")
        XCTAssertEqual(CSVExportService.escape("=HYPERLINK(\"x\")"), "\"'=HYPERLINK(\"\"x\"\")\"")
        XCTAssertEqual(CSVExportService.escape("Everlane"), "Everlane")
    }

    func testExportCreatesReadableCSVFile() throws {
        let temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

        let url = try CSVExportService.exportFile(
            from: [],
            filename: "My/Refunds",
            now: DomainTestSupport.date(2026, 8, 6),
            calendar: DomainTestSupport.calendar,
            directory: temporaryDirectory
        )

        XCTAssertEqual(url.pathExtension, "csv")
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        XCTAssertTrue(try String(contentsOf: url, encoding: .utf8).contains("Retailer"))
    }
}
