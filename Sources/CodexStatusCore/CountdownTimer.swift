import Foundation

public enum CountdownDurationUnit: String, CaseIterable, Equatable {
    case seconds
    case minutes

    public static var allCases: [CountdownDurationUnit] {
        [.seconds, .minutes]
    }

    public var title: String {
        switch self {
        case .seconds:
            return "秒"
        case .minutes:
            return "分钟"
        }
    }

    public var secondsMultiplier: Int {
        switch self {
        case .seconds:
            return 1
        case .minutes:
            return 60
        }
    }
}

public enum CountdownRunState: Equatable {
    case idle
    case running
    case paused
    case finished
}

public struct CountdownSnapshot: Equatable {
    public let state: CountdownRunState
    public let totalSeconds: Int
    public let remainingSeconds: Int
    public let updatedAt: Date
}

public final class CountdownTimerPreferences {
    private enum Key {
        static let durationValue = "countdown.durationValue"
        static let durationUnit = "countdown.durationUnit"
        static let reminderLeadValue = "countdown.reminderLeadValue"
        static let reminderLeadUnit = "countdown.reminderLeadUnit"
        static let reminderColorID = "countdown.reminderColorID"
    }

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public var durationValue: Int {
        get {
            let storedValue = defaults.integer(forKey: Key.durationValue)
            return storedValue > 0 ? min(storedValue, 9_999) : 5
        }
        set {
            defaults.set(min(max(newValue, 1), 9_999), forKey: Key.durationValue)
        }
    }

    public var durationUnit: CountdownDurationUnit {
        get {
            guard let rawValue = defaults.string(forKey: Key.durationUnit),
                  let unit = CountdownDurationUnit(rawValue: rawValue)
            else {
                return .minutes
            }
            return unit
        }
        set {
            defaults.set(newValue.rawValue, forKey: Key.durationUnit)
        }
    }

    public var configuredSeconds: Int {
        max(1, durationValue * durationUnit.secondsMultiplier)
    }

    public var reminderLeadValue: Int {
        get {
            if defaults.object(forKey: Key.reminderLeadValue) == nil {
                return 30
            }
            return min(max(defaults.integer(forKey: Key.reminderLeadValue), 0), 9_999)
        }
        set {
            defaults.set(min(max(newValue, 0), 9_999), forKey: Key.reminderLeadValue)
        }
    }

    public var reminderLeadUnit: CountdownDurationUnit {
        get {
            guard let rawValue = defaults.string(forKey: Key.reminderLeadUnit),
                  let unit = CountdownDurationUnit(rawValue: rawValue)
            else {
                return .seconds
            }
            return unit
        }
        set {
            defaults.set(newValue.rawValue, forKey: Key.reminderLeadUnit)
        }
    }

    public var reminderLeadSeconds: Int {
        reminderLeadValue * reminderLeadUnit.secondsMultiplier
    }

    public var reminderColorID: String {
        get { defaults.string(forKey: Key.reminderColorID) ?? "red" }
        set { defaults.set(newValue, forKey: Key.reminderColorID) }
    }

    public func isReminderActive(for snapshot: CountdownSnapshot) -> Bool {
        switch snapshot.state {
        case .finished:
            return true
        case .running:
            let leadSeconds = reminderLeadSeconds
            return leadSeconds > 0 && snapshot.remainingSeconds <= leadSeconds
        case .idle, .paused:
            return false
        }
    }
}

public final class CountdownTimerController {
    private let preferences: CountdownTimerPreferences
    private var state: CountdownRunState = .idle
    private var startedAt: Date?
    private var totalSecondsWhenStarted: Int
    private var remainingWhenPaused: Int?

    public var onChange: ((CountdownSnapshot) -> Void)?

    public init(preferences: CountdownTimerPreferences) {
        self.preferences = preferences
        self.totalSecondsWhenStarted = preferences.configuredSeconds
    }

    public func snapshot(now: Date = Date()) -> CountdownSnapshot {
        let remainingSeconds = remainingSeconds(at: now)
        let resolvedState: CountdownRunState = state == .running && remainingSeconds == 0 ? .finished : state
        return CountdownSnapshot(
            state: resolvedState,
            totalSeconds: totalSecondsForCurrentState,
            remainingSeconds: remainingSeconds,
            updatedAt: now
        )
    }

    public func start(now: Date = Date()) {
        totalSecondsWhenStarted = preferences.configuredSeconds
        remainingWhenPaused = nil
        startedAt = now
        state = .running
        emit(now: now)
    }

    public func pause(now: Date = Date()) {
        guard state == .running else {
            return
        }

        let remaining = remainingSeconds(at: now)
        remainingWhenPaused = remaining
        startedAt = nil
        state = remaining == 0 ? .finished : .paused
        emit(now: now)
    }

    public func resume(now: Date = Date()) {
        guard state == .paused else {
            return
        }

        let remaining = max(1, remainingWhenPaused ?? preferences.configuredSeconds)
        remainingWhenPaused = nil
        startedAt = now.addingTimeInterval(-Double(totalSecondsWhenStarted - remaining))
        state = .running
        emit(now: now)
    }

    public func reset(now: Date = Date()) {
        totalSecondsWhenStarted = preferences.configuredSeconds
        remainingWhenPaused = nil
        startedAt = nil
        state = .idle
        emit(now: now)
    }

    public func durationDidChange(now: Date = Date()) {
        reset(now: now)
    }

    @discardableResult
    public func tick(now: Date = Date()) -> CountdownSnapshot {
        let wasRunning = state == .running
        if wasRunning && remainingSeconds(at: now) == 0 {
            remainingWhenPaused = 0
            startedAt = nil
            state = .finished
        }

        let currentSnapshot = snapshot(now: now)
        if wasRunning {
            onChange?(currentSnapshot)
        }
        return currentSnapshot
    }

    private var totalSecondsForCurrentState: Int {
        switch state {
        case .idle:
            return preferences.configuredSeconds
        case .running, .paused, .finished:
            return totalSecondsWhenStarted
        }
    }

    private func remainingSeconds(at date: Date) -> Int {
        switch state {
        case .idle:
            return preferences.configuredSeconds
        case .paused:
            return max(0, remainingWhenPaused ?? totalSecondsWhenStarted)
        case .finished:
            return 0
        case .running:
            guard let startedAt else {
                return totalSecondsWhenStarted
            }
            let elapsed = max(0, date.timeIntervalSince(startedAt))
            let remaining = Double(totalSecondsWhenStarted) - elapsed
            return max(0, Int(ceil(remaining)))
        }
    }

    private func emit(now: Date) {
        onChange?(snapshot(now: now))
    }
}
