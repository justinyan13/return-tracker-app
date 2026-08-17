import Foundation
import SwiftData

enum SampleDataFactory {
    static func makeSamples(
        now: Date = .now,
        calendar: Calendar = .current
    ) -> [Refund] {
        func day(_ offset: Int) -> Date {
            calendar.date(byAdding: .day, value: offset, to: now) ?? now
        }

        let expectedNextWeek = Refund(
            retailerName: "Everlane",
            itemName: "ReNew Transit Backpack",
            orderNumber: "EVR-104982",
            refundAmount: decimal("95.00"),
            currencyCode: "USD",
            purchaseDate: day(-18),
            returnDate: day(-3),
            shippedDate: day(-3),
            retailerReceivedDate: day(-1),
            expectedRefundDate: day(7),
            refundMethod: .originalPaymentMethod,
            status: .refundPending,
            trackingNumber: "1Z999AA10123456784",
            returnCarrier: "UPS",
            notes: "Return accepted after trying a different size.",
            createdDate: day(-3),
            lastUpdatedDate: day(-1),
            isSampleData: true
        )

        let overdue = Refund(
            retailerName: "Home & Hearth",
            itemName: "Linen duvet cover",
            orderNumber: "HH-783120",
            refundAmount: decimal("148.50"),
            currencyCode: "USD",
            purchaseDate: day(-44),
            returnDate: day(-25),
            shippedDate: day(-24),
            retailerReceivedDate: day(-19),
            expectedRefundDate: day(-5),
            refundMethod: .originalPaymentMethod,
            status: .refundPending,
            trackingNumber: "9400111899560000123456",
            returnCarrier: "USPS",
            notes: "Contact support if this is not received by Friday.",
            createdDate: day(-25),
            lastUpdatedDate: day(-19),
            isSampleData: true
        )

        let completed = Refund(
            retailerName: "Patagonia",
            itemName: "Better Sweater jacket",
            orderNumber: "PAT-620491",
            refundAmount: decimal("139.00"),
            currencyCode: "USD",
            purchaseDate: day(-31),
            returnDate: day(-16),
            shippedDate: day(-15),
            retailerReceivedDate: day(-12),
            expectedRefundDate: day(-4),
            actualRefundDate: day(-2),
            refundMethod: .originalPaymentMethod,
            status: .refunded,
            trackingNumber: "771234567890",
            returnCarrier: "FedEx",
            notes: "Refund appeared on card statement.",
            createdDate: day(-16),
            lastUpdatedDate: day(-2),
            isSampleData: true
        )

        let shipped = Refund(
            retailerName: "Nordstrom",
            itemName: "Leather ankle boots",
            orderNumber: "ND-44158320",
            refundAmount: decimal("189.95"),
            currencyCode: "USD",
            purchaseDate: day(-12),
            returnDate: day(-2),
            shippedDate: day(-1),
            expectedRefundDate: day(12),
            refundMethod: .originalPaymentMethod,
            status: .shipped,
            trackingNumber: "1Z888BB20112345678",
            returnCarrier: "UPS",
            createdDate: day(-2),
            lastUpdatedDate: day(-1),
            isSampleData: true
        )

        let disputed = Refund(
            retailerName: "TechMarket",
            itemName: "Noise-cancelling headphones",
            orderNumber: "TM-900184",
            refundAmount: decimal("249.99"),
            currencyCode: "USD",
            purchaseDate: day(-52),
            returnDate: day(-32),
            shippedDate: day(-31),
            retailerReceivedDate: day(-27),
            expectedRefundDate: day(-12),
            refundMethod: .originalPaymentMethod,
            status: .disputed,
            trackingNumber: "9274899998435123456781",
            returnCarrier: "USPS",
            notes: "Retailer says the box arrived empty; card issuer dispute opened.",
            createdDate: day(-32),
            lastUpdatedDate: day(-3),
            isSampleData: true
        )

        return [expectedNextWeek, overdue, completed, shipped, disputed]
    }

    private static func decimal(_ value: String) -> Decimal {
        Decimal(string: value, locale: Locale(identifier: "en_US_POSIX")) ?? 0
    }
}

@MainActor
enum SampleDataService {
    @discardableResult
    static func insert(
        into context: ModelContext,
        now: Date = .now,
        calendar: Calendar = .current
    ) throws -> [Refund] {
        let existing = try context.fetch(
            FetchDescriptor<Refund>(
                predicate: #Predicate { $0.isSampleData == true }
            )
        )
        guard existing.isEmpty else { return existing }

        let samples = SampleDataFactory.makeSamples(now: now, calendar: calendar)
        for refund in samples {
            context.insert(refund)
        }
        try context.save()
        return samples
    }

    @discardableResult
    static func insert(
        in context: ModelContext,
        now: Date = .now,
        calendar: Calendar = .current
    ) throws -> [Refund] {
        try insert(into: context, now: now, calendar: calendar)
    }

    @discardableResult
    static func reset(
        in context: ModelContext,
        now: Date = .now,
        calendar: Calendar = .current
    ) throws -> [Refund] {
        try deleteSampleData(in: context)
        return try insert(into: context, now: now, calendar: calendar)
    }

    static func deleteSampleData(in context: ModelContext) throws {
        let samples = try context.fetch(
            FetchDescriptor<Refund>(
                predicate: #Predicate { $0.isSampleData == true }
            )
        )
        try delete(samples, in: context)
    }

    /// An explicit full reset for settings flows that clearly warn the user.
    /// Sample reset uses `reset(in:)` and never deletes real records.
    static func deleteAllRefunds(in context: ModelContext) throws {
        let refunds = try context.fetch(FetchDescriptor<Refund>())
        try delete(refunds, in: context)
    }

    /// The cascade rule removes attachment *rows*, but their bytes live outside
    /// the store. Without this the files stay in Application Support with no
    /// row left to point at them, and nothing in the app can ever reclaim them.
    private static func delete(
        _ refunds: [Refund],
        in context: ModelContext
    ) throws {
        let storedFilenames = refunds.flatMap { refund in
            refund.attachments.map(\.storedFilename)
        }
        for refund in refunds {
            context.delete(refund)
        }
        try context.save()
        try? AttachmentStore.shared.deleteFiles(named: storedFilenames)
    }
}
