import XCTest
@testable import RefundTracker

final class BusinessDayCalculatorTests: XCTestCase {
    private let calendar = DomainTestSupport.calendar

    func testAddingOneBusinessDaySkipsWeekend() {
        let friday = DomainTestSupport.date(2026, 8, 7, hour: 15)
        let result = BusinessDayCalculator.adding(
            friday,
            businessDays: 1,
            calendar: calendar
        )

        XCTAssertEqual(result, DomainTestSupport.date(2026, 8, 10, hour: 15))
    }

    func testAddingTenBusinessDays() {
        let monday = DomainTestSupport.date(2026, 8, 3)
        let result = BusinessDayCalculator.expectedRefundDate(
            from: monday,
            businessDayWindow: 10,
            calendar: calendar
        )

        XCTAssertEqual(result, DomainTestSupport.date(2026, 8, 17))
    }

    func testSubtractingBusinessDaySkipsWeekend() {
        let monday = DomainTestSupport.date(2026, 8, 10)
        let result = BusinessDayCalculator.adding(
            monday,
            businessDays: -1,
            calendar: calendar
        )

        XCTAssertEqual(result, DomainTestSupport.date(2026, 8, 7))
    }

    func testBusinessDayCountSupportsBothDirections() {
        let friday = DomainTestSupport.date(2026, 8, 7)
        let tuesday = DomainTestSupport.date(2026, 8, 11)

        XCTAssertEqual(
            BusinessDayCalculator.businessDays(
                from: friday,
                to: tuesday,
                calendar: calendar
            ),
            2
        )
        XCTAssertEqual(
            BusinessDayCalculator.businessDays(
                from: tuesday,
                to: friday,
                calendar: calendar
            ),
            -2
        )
    }

    func testZeroBusinessDaysPreservesDateExactly() {
        let date = DomainTestSupport.date(2026, 8, 8, hour: 16, minute: 45)
        XCTAssertEqual(
            BusinessDayCalculator.adding(
                date,
                businessDays: 0,
                calendar: calendar
            ),
            date
        )
    }
}
