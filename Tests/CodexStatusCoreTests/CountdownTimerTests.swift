import XCTest
@testable import CodexStatusCore

final class CountdownTimerTests: XCTestCase {
    func testCountsDownSecondsAndFinishes() {
        let preferences = makePreferences()
        preferences.durationValue = 5
        preferences.durationUnit = .seconds
        let timer = CountdownTimerController(preferences: preferences)
        let start = Date(timeIntervalSince1970: 100)

        timer.start(now: start)

        XCTAssertEqual(timer.snapshot(now: start).state, .running)
        XCTAssertEqual(timer.snapshot(now: start).remainingSeconds, 5)
        XCTAssertEqual(timer.snapshot(now: start.addingTimeInterval(2.2)).remainingSeconds, 3)

        let finished = timer.tick(now: start.addingTimeInterval(5.1))
        XCTAssertEqual(finished.state, .finished)
        XCTAssertEqual(finished.remainingSeconds, 0)
    }

    func testPauseAndResumePreservesOriginalTotalDuration() {
        let preferences = makePreferences()
        preferences.durationValue = 2
        preferences.durationUnit = .minutes
        let timer = CountdownTimerController(preferences: preferences)
        let start = Date(timeIntervalSince1970: 200)

        timer.start(now: start)
        timer.pause(now: start.addingTimeInterval(30))

        let paused = timer.snapshot(now: start.addingTimeInterval(80))
        XCTAssertEqual(paused.state, .paused)
        XCTAssertEqual(paused.totalSeconds, 120)
        XCTAssertEqual(paused.remainingSeconds, 90)

        timer.resume(now: start.addingTimeInterval(90))
        let resumed = timer.snapshot(now: start.addingTimeInterval(100))
        XCTAssertEqual(resumed.state, .running)
        XCTAssertEqual(resumed.totalSeconds, 120)
        XCTAssertEqual(resumed.remainingSeconds, 80)
    }

    func testChangingDurationResetsToIdle() {
        let preferences = makePreferences()
        preferences.durationValue = 10
        preferences.durationUnit = .seconds
        let timer = CountdownTimerController(preferences: preferences)
        let start = Date(timeIntervalSince1970: 300)

        timer.start(now: start)
        preferences.durationValue = 1
        preferences.durationUnit = .minutes
        timer.durationDidChange(now: start.addingTimeInterval(4))

        let snapshot = timer.snapshot(now: start.addingTimeInterval(5))
        XCTAssertEqual(snapshot.state, .idle)
        XCTAssertEqual(snapshot.totalSeconds, 60)
        XCTAssertEqual(snapshot.remainingSeconds, 60)
    }

    func testReminderActivatesOnlyNearEndOrFinished() {
        let preferences = makePreferences()
        preferences.durationValue = 2
        preferences.durationUnit = .minutes
        preferences.reminderLeadValue = 30
        preferences.reminderLeadUnit = .seconds
        let timer = CountdownTimerController(preferences: preferences)
        let start = Date(timeIntervalSince1970: 400)

        timer.start(now: start)

        XCTAssertFalse(preferences.isReminderActive(for: timer.snapshot(now: start.addingTimeInterval(80))))
        XCTAssertTrue(preferences.isReminderActive(for: timer.snapshot(now: start.addingTimeInterval(91))))
        XCTAssertTrue(preferences.isReminderActive(for: timer.tick(now: start.addingTimeInterval(120))))
    }

    func testZeroReminderLeadOnlyActivatesWhenFinished() {
        let preferences = makePreferences()
        preferences.durationValue = 5
        preferences.durationUnit = .seconds
        preferences.reminderLeadValue = 0
        preferences.reminderLeadUnit = .seconds
        let timer = CountdownTimerController(preferences: preferences)
        let start = Date(timeIntervalSince1970: 500)

        timer.start(now: start)

        XCTAssertFalse(preferences.isReminderActive(for: timer.snapshot(now: start.addingTimeInterval(4.5))))
        XCTAssertTrue(preferences.isReminderActive(for: timer.tick(now: start.addingTimeInterval(5))))
    }

    private func makePreferences() -> CountdownTimerPreferences {
        let suiteName = "CountdownTimerTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return CountdownTimerPreferences(defaults: defaults)
    }
}
