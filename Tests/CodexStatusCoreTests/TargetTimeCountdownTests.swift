import XCTest
@testable import CodexStatusCore

final class TargetTimeCountdownTests: XCTestCase {
    func testMinutesBeforeTargetRoundUp() {
        let calendar = makeCalendar()
        let now = date("2026-05-06 17:30:01", calendar: calendar)

        let snapshot = TargetTimeCountdownPreferences.snapshot(
            title: "下班",
            targetHour: 18,
            targetMinute: 0,
            pastBehavior: .showZero,
            now: now,
            calendar: calendar
        )

        XCTAssertEqual(snapshot.minutesRemaining, 30)
        XCTAssertFalse(snapshot.isPastTodayTarget)
    }

    func testSecondsBeforeTargetStillShowsOneMinute() {
        let calendar = makeCalendar()
        let now = date("2026-05-06 17:59:30", calendar: calendar)

        let snapshot = TargetTimeCountdownPreferences.snapshot(
            title: "下班",
            targetHour: 18,
            targetMinute: 0,
            pastBehavior: .showZero,
            now: now,
            calendar: calendar
        )

        XCTAssertEqual(snapshot.minutesRemaining, 1)
    }

    func testShowZeroAtAndAfterTarget() {
        let calendar = makeCalendar()
        let now = date("2026-05-06 18:05:00", calendar: calendar)

        let snapshot = TargetTimeCountdownPreferences.snapshot(
            title: "下班",
            targetHour: 18,
            targetMinute: 0,
            pastBehavior: .showZero,
            now: now,
            calendar: calendar
        )

        XCTAssertEqual(snapshot.minutesRemaining, 0)
        XCTAssertTrue(snapshot.isPastTodayTarget)
    }

    func testCanCountToNextDayAfterTarget() {
        let calendar = makeCalendar()
        let now = date("2026-05-06 18:05:00", calendar: calendar)

        let snapshot = TargetTimeCountdownPreferences.snapshot(
            title: "下班",
            targetHour: 18,
            targetMinute: 0,
            pastBehavior: .countToNextDay,
            now: now,
            calendar: calendar
        )

        XCTAssertEqual(snapshot.minutesRemaining, 1_435)
        XCTAssertTrue(snapshot.isPastTodayTarget)
    }

    func testPreferencesDefaultsTitleButAllowsEmptyTitle() {
        let preferences = makePreferences()

        XCTAssertEqual(preferences.title, "下班")

        preferences.title = "   "

        XCTAssertEqual(preferences.title, "")
        XCTAssertEqual(preferences.snapshot().title, "")
    }

    func testPreferencesClampTimeAndSanitizeTitle() {
        let preferences = makePreferences()

        preferences.title = "   123456789012345678901234567890   "
        preferences.targetHour = 42
        preferences.targetMinute = -9

        XCTAssertEqual(preferences.title.count, 24)
        XCTAssertEqual(preferences.title, "123456789012345678901234")
        XCTAssertEqual(preferences.targetHour, 23)
        XCTAssertEqual(preferences.targetMinute, 0)
    }

    func testBackgroundColorPreferenceDefaultsToNoneAndPersists() {
        let preferences = makePreferences()

        XCTAssertEqual(preferences.backgroundColorID, "none")

        preferences.backgroundColorID = "blue"

        XCTAssertEqual(preferences.backgroundColorID, "blue")
    }

    func testTextStylePreferencesDefaultAndPersist() {
        let preferences = makePreferences()

        XCTAssertEqual(preferences.textWeight, .regular)
        XCTAssertEqual(preferences.textColorID, "automatic")

        preferences.textWeight = .bold
        preferences.textColorID = "white"

        XCTAssertEqual(preferences.textWeight, .bold)
        XCTAssertEqual(preferences.textColorID, "white")
    }

    func testIconPreferenceDefaultsToVisibleAndPersists() {
        let preferences = makePreferences()

        XCTAssertTrue(preferences.showsIcon)

        preferences.showsIcon = false

        XCTAssertFalse(preferences.showsIcon)
    }

    private func makePreferences() -> TargetTimeCountdownPreferences {
        let suiteName = "TargetTimeCountdownTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return TargetTimeCountdownPreferences(defaults: defaults)
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
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.date(from: value)!
    }
}
