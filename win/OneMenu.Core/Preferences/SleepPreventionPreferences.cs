namespace OneMenu.Core.Preferences;

public class SleepPreventionPreferences
{
    private const string EnabledKey = "preventSystemSleep";
    private const string DurationKey = "preventSystemSleep.durationMinutes";
    private readonly PreferencesStore _store;

    public SleepPreventionPreferences(PreferencesStore store) => _store = store;

    public bool IsEnabled
    {
        get => _store.GetBool(EnabledKey);
        set => _store.Set(EnabledKey, value);
    }

    /// <summary>
    /// Duration in minutes before auto-disabling sleep prevention.
    /// 0 = keep active indefinitely (no auto-disable).
    /// Default: 5 minutes.
    /// </summary>
    public int DurationMinutes
    {
        get
        {
            if (!_store.HasKey(DurationKey)) return 5;
            return Math.Clamp(_store.GetInt(DurationKey), 0, 480);
        }
        set => _store.Set(DurationKey, Math.Clamp(value, 0, 480));
    }
}
