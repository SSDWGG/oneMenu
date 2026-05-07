namespace OneMenu.Core.Preferences;

public class StatusLightColorPreferences
{
    private const string RunningKey = "statusLight.runningColorID";
    private const string IdleKey = "statusLight.idleColorID";

    private readonly PreferencesStore _store;

    public StatusLightColorPreferences(PreferencesStore store)
    {
        _store = store;
    }

    public string RunningColorID
    {
        get
        {
            var stored = _store.GetString(RunningKey);
            if (stored != null && ColorDefinitions.StatusLightColors.Any(c => c.Id == stored))
                return stored;
            return "blue";
        }
        set => _store.Set(RunningKey, value);
    }

    public string IdleColorID
    {
        get
        {
            var stored = _store.GetString(IdleKey);
            if (stored != null && ColorDefinitions.StatusLightColors.Any(c => c.Id == stored))
                return stored;
            return "green";
        }
        set => _store.Set(IdleKey, value);
    }

    public ColorDefinitions.ColorOption RunningColor => ColorDefinitions.StatusLightColorFor(RunningColorID);
    public ColorDefinitions.ColorOption IdleColor => ColorDefinitions.StatusLightColorFor(IdleColorID);
    public string RunningColorTitle => RunningColor.Title;
    public string IdleColorTitle => IdleColor.Title;
}
