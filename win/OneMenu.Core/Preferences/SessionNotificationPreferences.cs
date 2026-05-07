namespace OneMenu.Core.Preferences;

public class SessionNotificationPreferences
{
    private const string Key = "sessionEndNotificationEnabled";
    private readonly PreferencesStore _store;

    public SessionNotificationPreferences(PreferencesStore store) => _store = store;

    public bool IsEnabled
    {
        get
        {
            if (!_store.HasKey(Key))
                return true; // default on
            return _store.GetBool(Key);
        }
        set => _store.Set(Key, value);
    }
}
