import Foundation

public enum TargetTimeCountdownPastBehavior: String, CaseIterable, Equatable {
    case showZero
    case countToNextDay

    public static var allCases: [TargetTimeCountdownPastBehavior] {
        [.showZero, .countToNextDay]
    }

    public var title: String {
        switch self {
        case .showZero:
            return "过点显示 0"
        case .countToNextDay:
            return "滚到明天"
        }
    }
}

public enum TargetTimeCountdownTextWeight: String, CaseIterable, Equatable {
    case regular
    case medium
    case semibold
    case bold

    public static var allCases: [TargetTimeCountdownTextWeight] {
        [.regular, .medium, .semibold, .bold]
    }

    public var title: String {
        switch self {
        case .regular:
            return "常规"
        case .medium:
            return "中等"
        case .semibold:
            return "半粗"
        case .bold:
            return "粗体"
        }
    }
}

public struct TargetTimeCountdownSnapshot: Equatable {
    public let title: String
    public let targetHour: Int
    public let targetMinute: Int
    public let pastBehavior: TargetTimeCountdownPastBehavior
    public let targetDate: Date
    public let minutesRemaining: Int
    public let isPastTodayTarget: Bool
}

public final class TargetTimeCountdownPreferences {
    private enum Key {
        static let title = "targetTimeCountdown.title"
        static let targetHour = "targetTimeCountdown.targetHour"
        static let targetMinute = "targetTimeCountdown.targetMinute"
        static let pastBehavior = "targetTimeCountdown.pastBehavior"
        static let backgroundColorID = "targetTimeCountdown.backgroundColorID"
        static let textWeight = "targetTimeCountdown.textWeight"
        static let textColorID = "targetTimeCountdown.textColorID"
        static let showsIcon = "targetTimeCountdown.showsIcon"
    }

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public var title: String {
        get {
            guard defaults.object(forKey: Key.title) != nil else {
                return "下班"
            }
            return Self.sanitizedTitle(defaults.string(forKey: Key.title))
        }
        set { defaults.set(Self.sanitizedTitle(newValue), forKey: Key.title) }
    }

    public var targetHour: Int {
        get {
            if defaults.object(forKey: Key.targetHour) == nil {
                return 18
            }
            return min(max(defaults.integer(forKey: Key.targetHour), 0), 23)
        }
        set { defaults.set(min(max(newValue, 0), 23), forKey: Key.targetHour) }
    }

    public var targetMinute: Int {
        get {
            if defaults.object(forKey: Key.targetMinute) == nil {
                return 0
            }
            return min(max(defaults.integer(forKey: Key.targetMinute), 0), 59)
        }
        set { defaults.set(min(max(newValue, 0), 59), forKey: Key.targetMinute) }
    }

    public var pastBehavior: TargetTimeCountdownPastBehavior {
        get {
            guard let rawValue = defaults.string(forKey: Key.pastBehavior),
                  let behavior = TargetTimeCountdownPastBehavior(rawValue: rawValue)
            else {
                return .showZero
            }
            return behavior
        }
        set {
            defaults.set(newValue.rawValue, forKey: Key.pastBehavior)
        }
    }

    public var backgroundColorID: String {
        get { defaults.string(forKey: Key.backgroundColorID) ?? "none" }
        set { defaults.set(newValue, forKey: Key.backgroundColorID) }
    }

    public var textWeight: TargetTimeCountdownTextWeight {
        get {
            guard let rawValue = defaults.string(forKey: Key.textWeight),
                  let weight = TargetTimeCountdownTextWeight(rawValue: rawValue)
            else {
                return .regular
            }
            return weight
        }
        set {
            defaults.set(newValue.rawValue, forKey: Key.textWeight)
        }
    }

    public var textColorID: String {
        get { defaults.string(forKey: Key.textColorID) ?? "automatic" }
        set { defaults.set(newValue, forKey: Key.textColorID) }
    }

    public var showsIcon: Bool {
        get {
            if defaults.object(forKey: Key.showsIcon) == nil {
                return true
            }
            return defaults.bool(forKey: Key.showsIcon)
        }
        set { defaults.set(newValue, forKey: Key.showsIcon) }
    }

    public func snapshot(now: Date = Date(), calendar: Calendar = .current) -> TargetTimeCountdownSnapshot {
        Self.snapshot(
            title: title,
            targetHour: targetHour,
            targetMinute: targetMinute,
            pastBehavior: pastBehavior,
            now: now,
            calendar: calendar
        )
    }

    public static func snapshot(
        title: String,
        targetHour: Int,
        targetMinute: Int,
        pastBehavior: TargetTimeCountdownPastBehavior,
        now: Date,
        calendar: Calendar = .current
    ) -> TargetTimeCountdownSnapshot {
        let safeHour = min(max(targetHour, 0), 23)
        let safeMinute = min(max(targetMinute, 0), 59)
        let todayTarget = targetDate(onSameDayAs: now, hour: safeHour, minute: safeMinute, calendar: calendar)
        let isPastTodayTarget = now >= todayTarget
        let effectiveTarget: Date

        if isPastTodayTarget, pastBehavior == .countToNextDay {
            effectiveTarget = calendar.date(byAdding: .day, value: 1, to: todayTarget) ?? todayTarget
        } else {
            effectiveTarget = todayTarget
        }

        let minutesRemaining: Int
        if isPastTodayTarget, pastBehavior == .showZero {
            minutesRemaining = 0
        } else {
            let interval = max(0, effectiveTarget.timeIntervalSince(now))
            minutesRemaining = Int(ceil(interval / 60))
        }

        return TargetTimeCountdownSnapshot(
            title: sanitizedTitle(title),
            targetHour: safeHour,
            targetMinute: safeMinute,
            pastBehavior: pastBehavior,
            targetDate: effectiveTarget,
            minutesRemaining: minutesRemaining,
            isPastTodayTarget: isPastTodayTarget
        )
    }

    private static func targetDate(onSameDayAs date: Date, hour: Int, minute: Int, calendar: Calendar) -> Date {
        var components = calendar.dateComponents([.year, .month, .day], from: date)
        components.hour = hour
        components.minute = minute
        components.second = 0
        return calendar.date(from: components) ?? date
    }

    private static func sanitizedTitle(_ title: String?) -> String {
        let trimmed = (title ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return String(trimmed.prefix(24))
    }
}
