namespace OneMenu.Core.Timers;

public enum TargetTimeCountdownPastBehavior
{
    ShowZero, CountToNextDay
}

public enum TargetTimeCountdownTextWeight
{
    Regular, Medium, Semibold, Bold
}

public record TargetTimeCountdownSnapshot(
    string Title,
    int TargetHour,
    int TargetMinute,
    TargetTimeCountdownPastBehavior PastBehavior,
    DateTime TargetDate,
    int MinutesRemaining,
    bool IsPastTodayTarget);

public class TargetTimeCountdownPreferences
{
    private const string TitleKey = "targetTimeCountdown.title";
    private const string TargetHourKey = "targetTimeCountdown.targetHour";
    private const string TargetMinuteKey = "targetTimeCountdown.targetMinute";
    private const string PastBehaviorKey = "targetTimeCountdown.pastBehavior";
    private const string BackgroundColorIDKey = "targetTimeCountdown.backgroundColorID";
    private const string TextWeightKey = "targetTimeCountdown.textWeight";
    private const string TextColorIDKey = "targetTimeCountdown.textColorID";
    private const string ShowsIconKey = "targetTimeCountdown.showsIcon";

    private readonly Preferences.PreferencesStore _store;

    public TargetTimeCountdownPreferences(Preferences.PreferencesStore store) => _store = store;

    public string Title
    {
        get => Sanitize(_store.GetString(TitleKey), "下班");
        set => _store.Set(TitleKey, Sanitize(value, "下班"));
    }

    public int TargetHour
    {
        get
        {
            if (!_store.HasKey(TargetHourKey)) return 18;
            return Math.Clamp(_store.GetInt(TargetHourKey, 18), 0, 23);
        }
        set => _store.Set(TargetHourKey, Math.Clamp(value, 0, 23));
    }

    public int TargetMinute
    {
        get
        {
            if (!_store.HasKey(TargetMinuteKey)) return 0;
            return Math.Clamp(_store.GetInt(TargetMinuteKey, 0), 0, 59);
        }
        set => _store.Set(TargetMinuteKey, Math.Clamp(value, 0, 59));
    }

    public TargetTimeCountdownPastBehavior PastBehavior
    {
        get
        {
            var raw = _store.GetString(PastBehaviorKey);
            return Enum.TryParse<TargetTimeCountdownPastBehavior>(raw, out var b) ? b : TargetTimeCountdownPastBehavior.ShowZero;
        }
        set => _store.Set(PastBehaviorKey, value.ToString());
    }

    public string BackgroundColorID
    {
        get => _store.GetString(BackgroundColorIDKey) ?? "none";
        set => _store.Set(BackgroundColorIDKey, value);
    }

    public TargetTimeCountdownTextWeight TextWeight
    {
        get
        {
            var raw = _store.GetString(TextWeightKey);
            return Enum.TryParse<TargetTimeCountdownTextWeight>(raw, out var w) ? w : TargetTimeCountdownTextWeight.Regular;
        }
        set => _store.Set(TextWeightKey, value.ToString());
    }

    public string TextColorID
    {
        get => _store.GetString(TextColorIDKey) ?? "automatic";
        set => _store.Set(TextColorIDKey, value);
    }

    public bool ShowsIcon
    {
        get
        {
            if (!_store.HasKey(ShowsIconKey)) return true;
            return _store.GetBool(ShowsIconKey);
        }
        set => _store.Set(ShowsIconKey, value);
    }

    public TargetTimeCountdownSnapshot Snapshot(DateTime? now = null)
    {
        var n = now ?? DateTime.Now;
        return ComputeSnapshot(Title, TargetHour, TargetMinute, PastBehavior, n);
    }

    public static TargetTimeCountdownSnapshot ComputeSnapshot(
        string title, int hour, int minute, TargetTimeCountdownPastBehavior pastBehavior, DateTime now)
    {
        var safeHour = Math.Clamp(hour, 0, 23);
        var safeMinute = Math.Clamp(minute, 0, 59);
        var todayTarget = new DateTime(now.Year, now.Month, now.Day, safeHour, safeMinute, 0);
        var isPast = now >= todayTarget;

        DateTime effectiveTarget = (isPast, pastBehavior) switch
        {
            (true, TargetTimeCountdownPastBehavior.CountToNextDay) => todayTarget.AddDays(1),
            _ => todayTarget
        };

        int minutesRemaining = (isPast, pastBehavior) switch
        {
            (true, TargetTimeCountdownPastBehavior.ShowZero) => 0,
            _ => Math.Max(0, (int)Math.Ceiling((effectiveTarget - now).TotalMinutes))
        };

        return new TargetTimeCountdownSnapshot(
            Sanitize(title, "下班"), safeHour, safeMinute, pastBehavior,
            effectiveTarget, minutesRemaining, isPast);
    }

    private static string Sanitize(string? text, string fallback)
    {
        var trimmed = (text ?? "").Trim();
        return trimmed.Length > 0 ? trimmed[..Math.Min(trimmed.Length, 24)] : fallback;
    }

    // Display helpers
    public static string PastBehaviorTitle(TargetTimeCountdownPastBehavior b) => b switch
    {
        TargetTimeCountdownPastBehavior.ShowZero => "过点显示 0",
        TargetTimeCountdownPastBehavior.CountToNextDay => "滚到明天",
        _ => b.ToString()
    };

    public static string TextWeightTitle(TargetTimeCountdownTextWeight w) => w switch
    {
        TargetTimeCountdownTextWeight.Regular => "常规",
        TargetTimeCountdownTextWeight.Medium => "中等",
        TargetTimeCountdownTextWeight.Semibold => "半粗",
        TargetTimeCountdownTextWeight.Bold => "粗体",
        _ => w.ToString()
    };
}
