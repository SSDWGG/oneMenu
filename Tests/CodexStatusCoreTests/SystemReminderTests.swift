import XCTest
@testable import CodexStatusCore

final class SystemReminderTests: XCTestCase {
    func testOneTimeReminderReturnsFutureDate() {
        let calendar = makeCalendar()
        let now = date("2026-05-06 10:00", calendar: calendar)
        let scheduledDate = date("2026-05-06 10:30", calendar: calendar)

        XCTAssertEqual(
            SystemReminderPreferences.nextFireDate(for: scheduledDate, mode: .once, now: now, calendar: calendar),
            scheduledDate
        )
    }

    func testOneTimeReminderDoesNotReturnPastDate() {
        let calendar = makeCalendar()
        let now = date("2026-05-06 10:30", calendar: calendar)
        let scheduledDate = date("2026-05-06 10:00", calendar: calendar)

        XCTAssertNil(SystemReminderPreferences.nextFireDate(for: scheduledDate, mode: .once, now: now, calendar: calendar))
    }

    func testDailyReminderReturnsTodayWhenTimeIsStillAhead() {
        let calendar = makeCalendar()
        let now = date("2026-05-06 10:00", calendar: calendar)
        let scheduledDate = date("2026-01-01 10:30", calendar: calendar)

        XCTAssertEqual(
            SystemReminderPreferences.nextFireDate(for: scheduledDate, mode: .daily, now: now, calendar: calendar),
            date("2026-05-06 10:30", calendar: calendar)
        )
    }

    func testDailyReminderRollsToTomorrowWhenTimeHasPassed() {
        let calendar = makeCalendar()
        let now = date("2026-05-06 10:30", calendar: calendar)
        let scheduledDate = date("2026-01-01 10:00", calendar: calendar)

        XCTAssertEqual(
            SystemReminderPreferences.nextFireDate(for: scheduledDate, mode: .daily, now: now, calendar: calendar),
            date("2026-05-07 10:00", calendar: calendar)
        )
    }

    func testPreferencesSanitizeEmptyText() {
        let preferences = makePreferences()

        preferences.title = "   "
        preferences.message = "\n"

        XCTAssertEqual(preferences.title, "oneMenu 提醒")
        XCTAssertEqual(preferences.message, "到了预定提醒时间。")
    }

    private func makePreferences() -> SystemReminderPreferences {
        let suiteName = "SystemReminderTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return SystemReminderPreferences(defaults: defaults)
    }

    private func makeCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private func date(_ value: String, calendar: Calendar) -> Date {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.date(from: value)!
    }
}
