namespace OneMenu.Core.Reminder;

public enum SystemReminderMode
{
    Once, Daily
}

public record SystemReminderSnapshot(
    bool IsEnabled,
    SystemReminderMode Mode,
    string Title,
    string Message,
    DateTime ScheduledDate,
    DateTime? NextFireDate);

public class SystemReminderPreferences
{
    private const string IsEnabledKey = "systemReminder.isEnabled";
    private const string ModeKey = "systemReminder.mode";
    private const string TitleKey = "systemReminder.title";
    private const string MessageKey = "systemReminder.message";
    private const string ScheduledDateKey = "systemReminder.scheduledDate";

    private readonly Preferences.PreferencesStore _store;

    public SystemReminderPreferences(Preferences.PreferencesStore store) => _store = store;

    public bool IsEnabled
    {
        get => _store.GetBool(IsEnabledKey);
        set
        {
            if (value && !_store.HasKey(ScheduledDateKey))
                _store.Set(ScheduledDateKey, DefaultScheduledDate());
            _store.Set(IsEnabledKey, value);
        }
    }

    public SystemReminderMode Mode
    {
        get
        {
            var raw = _store.GetString(ModeKey);
            return Enum.TryParse<SystemReminderMode>(raw, out var m) ? m : SystemReminderMode.Once;
        }
        set => _store.Set(ModeKey, value.ToString());
    }

    public string Title
    {
        get => Sanitize(_store.GetString(TitleKey), "oneMenu 提醒", 80);
        set => _store.Set(TitleKey, Sanitize(value, "oneMenu 提醒", 80));
    }

    public string Message
    {
        get => Sanitize(_store.GetString(MessageKey), "到了预定提醒时间。", 240);
        set => _store.Set(MessageKey, Sanitize(value, "到了预定提醒时间。", 240));
    }

    public DateTime ScheduledDate
    {
        get
        {
            var dt = _store.GetDateTime(ScheduledDateKey);
            return dt.HasValue ? Normalize(dt.Value) : DefaultScheduledDate();
        }
        set => _store.Set(ScheduledDateKey, Normalize(value));
    }

    public SystemReminderSnapshot Snapshot(DateTime? now = null)
    {
        var n = now ?? DateTime.Now;
        var sched = ScheduledDate;
        return new SystemReminderSnapshot(IsEnabled, Mode, Title, Message, sched,
            NextFireDate(sched, Mode, n));
    }

    public DateTime? NextFireDate(DateTime scheduledDate, SystemReminderMode mode, DateTime now)
    {
        return mode switch
        {
            SystemReminderMode.Once =>
                Normalize(scheduledDate) > now ? Normalize(scheduledDate) : null,
            SystemReminderMode.Daily =>
                NextDailyTime(scheduledDate, now),
            _ => null
        };
    }

    private DateTime? NextFireDateFromNow(DateTime now) =>
        NextFireDate(ScheduledDate, Mode, now);

    private static DateTime NextDailyTime(DateTime scheduledDate, DateTime now)
    {
        var todayTarget = new DateTime(now.Year, now.Month, now.Day,
            scheduledDate.Hour, scheduledDate.Minute, 0);
        return todayTarget > now ? todayTarget : todayTarget.AddDays(1);
    }

    private static DateTime DefaultScheduledDate() =>
        Normalize(DateTime.Now.AddHours(1));

    private static DateTime Normalize(DateTime date) =>
        new(date.Year, date.Month, date.Day, date.Hour, date.Minute, 0);

    private static string Sanitize(string? text, string fallback, int maxLength)
    {
        var trimmed = (text ?? "").Trim();
        if (trimmed.Length == 0) return fallback;
        return trimmed[..Math.Min(trimmed.Length, maxLength)];
    }

    public static string ModeTitle(SystemReminderMode mode) => mode switch
    {
        SystemReminderMode.Once => "单次提醒",
        SystemReminderMode.Daily => "每日提醒",
        _ => mode.ToString()
    };
}
