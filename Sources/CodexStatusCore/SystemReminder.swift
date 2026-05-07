import Foundation

public enum SystemReminderMode: String, CaseIterable, Equatable {
    case once
    case daily

    public static var allCases: [SystemReminderMode] {
        [.once, .daily]
    }

    public var title: String {
        switch self {
        case .once:
            return "单次提醒"
        case .daily:
            return "每日提醒"
        }
    }
}

public struct SystemReminderSnapshot: Equatable {
    public let isEnabled: Bool
    public let mode: SystemReminderMode
    public let title: String
    public let message: String
    public let scheduledDate: Date
    public let nextFireDate: Date?
}

public final class SystemReminderPreferences {
    private enum Key {
        static let isEnabled = "systemReminder.isEnabled"
        static let mode = "systemReminder.mode"
        static let title = "systemReminder.title"
        static let message = "systemReminder.message"
        static let scheduledDate = "systemReminder.scheduledDate"
    }

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public var isEnabled: Bool {
        get { defaults.bool(forKey: Key.isEnabled) }
        set {
            if newValue, defaults.object(forKey: Key.scheduledDate) == nil {
                defaults.set(Self.defaultScheduledDate(), forKey: Key.scheduledDate)
            }
            defaults.set(newValue, forKey: Key.isEnabled)
        }
    }

    public var mode: SystemReminderMode {
        get {
            guard let rawValue = defaults.string(forKey: Key.mode),
                  let mode = SystemReminderMode(rawValue: rawValue)
            else {
                return .once
            }
            return mode
        }
        set {
            defaults.set(newValue.rawValue, forKey: Key.mode)
        }
    }

    public var title: String {
        get { Self.sanitizedText(defaults.string(forKey: Key.title), fallback: "oneMenu 提醒", maxLength: 80) }
        set { defaults.set(Self.sanitizedText(newValue, fallback: "oneMenu 提醒", maxLength: 80), forKey: Key.title) }
    }

    public var message: String {
        get { Self.sanitizedText(defaults.string(forKey: Key.message), fallback: "到了预定提醒时间。", maxLength: 240) }
        set { defaults.set(Self.sanitizedText(newValue, fallback: "到了预定提醒时间。", maxLength: 240), forKey: Key.message) }
    }

    public var scheduledDate: Date {
        get {
            if let date = defaults.object(forKey: Key.scheduledDate) as? Date {
                return Self.normalizedDate(date)
            }
            return Self.defaultScheduledDate()
        }
        set {
            defaults.set(Self.normalizedDate(newValue), forKey: Key.scheduledDate)
        }
    }

    public func snapshot(now: Date = Date(), calendar: Calendar = .current) -> SystemReminderSnapshot {
        let scheduledDate = scheduledDate
        return SystemReminderSnapshot(
            isEnabled: isEnabled,
            mode: mode,
            title: title,
            message: message,
            scheduledDate: scheduledDate,
            nextFireDate: Self.nextFireDate(for: scheduledDate, mode: mode, now: now, calendar: calendar)
        )
    }

    public func nextFireDate(now: Date = Date(), calendar: Calendar = .current) -> Date? {
        Self.nextFireDate(for: scheduledDate, mode: mode, now: now, calendar: calendar)
    }

    public static func nextFireDate(
        for scheduledDate: Date,
        mode: SystemReminderMode,
        now: Date,
        calendar: Calendar = .current
    ) -> Date? {
        switch mode {
        case .once:
            let normalizedDate = normalizedDate(scheduledDate, calendar: calendar)
            return normalizedDate > now ? normalizedDate : nil
        case .daily:
            var components = calendar.dateComponents([.hour, .minute], from: scheduledDate)
            components.second = 0
            return calendar.nextDate(
                after: now,
                matching: components,
                matchingPolicy: .nextTime,
                repeatedTimePolicy: .first,
                direction: .forward
            )
        }
    }

    public static func normalizedDate(_ date: Date, calendar: Calendar = .current) -> Date {
        var components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        components.second = 0
        return calendar.date(from: components) ?? date
    }

    private static func defaultScheduledDate(now: Date = Date(), calendar: Calendar = .current) -> Date {
        normalizedDate(now.addingTimeInterval(3_600), calendar: calendar)
    }

    private static func sanitizedText(_ text: String?, fallback: String, maxLength: Int) -> String {
        let trimmed = (text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return fallback
        }
        return String(trimmed.prefix(maxLength))
    }
}
