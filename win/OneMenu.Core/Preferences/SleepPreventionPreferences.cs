namespace OneMenu.Core.Preferences;

public class SleepPreventionPreferences
{
    private const string Key = "preventSystemSleep";
    private readonly PreferencesStore _store;

    public SleepPreventionPreferences(PreferencesStore store) => _store = store;

    public bool IsEnabled
    {
        get => _store.GetBool(Key);
        set => _store.Set(Key, value);
    }
}
