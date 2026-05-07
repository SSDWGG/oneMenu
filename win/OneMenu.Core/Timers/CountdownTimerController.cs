namespace OneMenu.Core.Timers;

public enum CountdownDurationUnit
{
    Seconds, Minutes
}

public enum CountdownRunState
{
    Idle, Running, Paused, Finished
}

public record CountdownSnapshot(
    CountdownRunState State,
    int TotalSeconds,
    int RemainingSeconds,
    DateTime UpdatedAt);

public class CountdownTimerPreferences
{
    private const string DurationValueKey = "countdown.durationValue";
    private const string DurationUnitKey = "countdown.durationUnit";
    private const string ReminderLeadValueKey = "countdown.reminderLeadValue";
    private const string ReminderLeadUnitKey = "countdown.reminderLeadUnit";
    private const string ReminderColorIDKey = "countdown.reminderColorID";

    private readonly Preferences.PreferencesStore _store;

    public CountdownTimerPreferences(Preferences.PreferencesStore store) => _store = store;

    public int DurationValue
    {
        get
        {
            var v = _store.GetInt(DurationValueKey, 0);
            return v > 0 ? Math.Min(v, 9999) : 5;
        }
        set => _store.Set(DurationValueKey, Math.Clamp(value, 1, 9999));
    }

    public CountdownDurationUnit DurationUnit
    {
        get
        {
            var raw = _store.GetString(DurationUnitKey);
            return Enum.TryParse<CountdownDurationUnit>(raw, out var u) ? u : CountdownDurationUnit.Minutes;
        }
        set => _store.Set(DurationUnitKey, value.ToString());
    }

    public int ConfiguredSeconds =>
        Math.Max(1, DurationValue * (DurationUnit == CountdownDurationUnit.Minutes ? 60 : 1));

    public int ReminderLeadValue
    {
        get
        {
            if (!_store.HasKey(ReminderLeadValueKey)) return 30;
            return Math.Clamp(_store.GetInt(ReminderLeadValueKey, 30), 0, 9999);
        }
        set => _store.Set(ReminderLeadValueKey, Math.Clamp(value, 0, 9999));
    }

    public CountdownDurationUnit ReminderLeadUnit
    {
        get
        {
            var raw = _store.GetString(ReminderLeadUnitKey);
            return Enum.TryParse<CountdownDurationUnit>(raw, out var u) ? u : CountdownDurationUnit.Seconds;
        }
        set => _store.Set(ReminderLeadUnitKey, value.ToString());
    }

    public int ReminderLeadSeconds =>
        ReminderLeadValue * (ReminderLeadUnit == CountdownDurationUnit.Minutes ? 60 : 1);

    public string ReminderColorID
    {
        get => _store.GetString(ReminderColorIDKey) ?? "red";
        set => _store.Set(ReminderColorIDKey, value);
    }

    public bool IsReminderActive(CountdownSnapshot snapshot)
    {
        return snapshot.State switch
        {
            CountdownRunState.Finished => true,
            CountdownRunState.Running => ReminderLeadSeconds > 0 && snapshot.RemainingSeconds <= ReminderLeadSeconds,
            _ => false
        };
    }
}

public class CountdownTimerController
{
    private readonly CountdownTimerPreferences _prefs;
    private CountdownRunState _state = CountdownRunState.Idle;
    private DateTime? _startedAt;
    private int _totalSecondsWhenStarted;
    private int? _remainingWhenPaused;

    public event Action<CountdownSnapshot>? OnChange;

    public CountdownTimerController(CountdownTimerPreferences preferences)
    {
        _prefs = preferences;
        _totalSecondsWhenStarted = preferences.ConfiguredSeconds;
    }

    public CountdownSnapshot Snapshot(DateTime? now = null)
    {
        var n = now ?? DateTime.UtcNow;
        var remaining = RemainingSeconds(n);
        var state = _state == CountdownRunState.Running && remaining == 0
            ? CountdownRunState.Finished : _state;
        return new CountdownSnapshot(state, TotalSecondsForCurrentState, remaining, n);
    }

    public void Start(DateTime? now = null)
    {
        var n = now ?? DateTime.UtcNow;
        _totalSecondsWhenStarted = _prefs.ConfiguredSeconds;
        _remainingWhenPaused = null;
        _startedAt = n;
        _state = CountdownRunState.Running;
        Emit(n);
    }

    public void Pause(DateTime? now = null)
    {
        if (_state != CountdownRunState.Running) return;
        var n = now ?? DateTime.UtcNow;
        var remaining = RemainingSeconds(n);
        _remainingWhenPaused = remaining;
        _startedAt = null;
        _state = remaining == 0 ? CountdownRunState.Finished : CountdownRunState.Paused;
        Emit(n);
    }

    public void Resume(DateTime? now = null)
    {
        if (_state != CountdownRunState.Paused) return;
        var n = now ?? DateTime.UtcNow;
        var remaining = Math.Max(1, _remainingWhenPaused ?? _prefs.ConfiguredSeconds);
        _remainingWhenPaused = null;
        _startedAt = n.AddSeconds(-(_totalSecondsWhenStarted - remaining));
        _state = CountdownRunState.Running;
        Emit(n);
    }

    public void Reset(DateTime? now = null)
    {
        var n = now ?? DateTime.UtcNow;
        _totalSecondsWhenStarted = _prefs.ConfiguredSeconds;
        _remainingWhenPaused = null;
        _startedAt = null;
        _state = CountdownRunState.Idle;
        Emit(n);
    }

    public void DurationDidChange(DateTime? now = null) => Reset(now);

    public CountdownSnapshot Tick(DateTime? now = null)
    {
        var n = now ?? DateTime.UtcNow;
        if (_state == CountdownRunState.Running && RemainingSeconds(n) == 0)
        {
            _remainingWhenPaused = 0;
            _startedAt = null;
            _state = CountdownRunState.Finished;
        }
        var snap = Snapshot(n);
        OnChange?.Invoke(snap);
        return snap;
    }

    private int TotalSecondsForCurrentState => _state switch
    {
        CountdownRunState.Idle => _prefs.ConfiguredSeconds,
        _ => _totalSecondsWhenStarted
    };

    private int RemainingSeconds(DateTime date)
    {
        switch (_state)
        {
            case CountdownRunState.Idle:
                return _prefs.ConfiguredSeconds;
            case CountdownRunState.Paused:
                return Math.Max(0, _remainingWhenPaused ?? _totalSecondsWhenStarted);
            case CountdownRunState.Finished:
                return 0;
            case CountdownRunState.Running:
                if (_startedAt == null) return _totalSecondsWhenStarted;
                var elapsed = Math.Max(0, (date - _startedAt.Value).TotalSeconds);
                return Math.Max(0, (int)Math.Ceiling(_totalSecondsWhenStarted - elapsed));
            default:
                return 0;
        }
    }

    private void Emit(DateTime now) => OnChange?.Invoke(Snapshot(now));
}

public static class CountdownDurationUnitExtensions
{
    public static string Title(this CountdownDurationUnit unit) => unit switch
    {
        CountdownDurationUnit.Seconds => "秒",
        CountdownDurationUnit.Minutes => "分钟",
        _ => unit.ToString()
    };
}
