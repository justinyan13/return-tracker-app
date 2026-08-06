import Foundation

enum BusinessDayCalculator {
    /// Adds weekdays while preserving the time of day. Public holidays are not
    /// excluded because the app has no locale-specific holiday data source.
    static func adding(
        _ date: Date,
        businessDays: Int,
        calendar: Calendar = .current
    ) -> Date {
        addingBusinessDays(businessDays, to: date, calendar: calendar)
    }

    static func addingBusinessDays(
        _ businessDays: Int,
        to date: Date,
        calendar: Calendar = .current
    ) -> Date {
        guard businessDays != 0 else { return date }

        let step = businessDays > 0 ? 1 : -1
        var remaining = abs(businessDays)
        var result = date

        while remaining > 0 {
            guard let nextDate = calendar.date(byAdding: .day, value: step, to: result) else {
                return result
            }
            result = nextDate

            if !calendar.isDateInWeekend(result) {
                remaining -= 1
            }
        }

        return result
    }

    static func expectedRefundDate(
        from returnDate: Date,
        businessDayWindow: Int = 10,
        calendar: Calendar = .current
    ) -> Date {
        addingBusinessDays(
            max(0, businessDayWindow),
            to: returnDate,
            calendar: calendar
        )
    }

    /// Counts weekdays after `startDate` and through `endDate`. Passing dates in
    /// reverse order returns the corresponding negative count.
    static func businessDays(
        from startDate: Date,
        to endDate: Date,
        calendar: Calendar = .current
    ) -> Int {
        let start = calendar.startOfDay(for: startDate)
        let end = calendar.startOfDay(for: endDate)
        guard start != end else { return 0 }

        let direction = start < end ? 1 : -1
        var cursor = start
        var count = 0

        while cursor != end {
            guard let next = calendar.date(byAdding: .day, value: direction, to: cursor) else {
                break
            }
            cursor = next
            if !calendar.isDateInWeekend(cursor) {
                count += direction
            }
        }

        return count
    }
}
