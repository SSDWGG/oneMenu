namespace OneMenu.Core.Preferences;

public enum StatusBarModule
{
    Gpt, Claude, Weather, Hardware, Countdown,
    TargetTimeCountdown, SystemReminder, Sleep
}

public class StatusBarDisplayPreferences
{
    private readonly PreferencesStore _store;

    public StatusBarDisplayPreferences(PreferencesStore store) => _store = store;

    private static string Key(StatusBarModule module) => $"statusBarDisplay.{module}";

    public bool IsVisible(StatusBarModule module)
    {
        if (!_store.HasKey(Key(module)))
            return module != StatusBarModule.Sleep;
        return _store.GetBool(Key(module));
    }

    public void SetVisible(StatusBarModule module, bool isVisible) =>
        _store.Set(Key(module), isVisible);

    public bool HasVisibleModule =>
        Enum.GetValues<StatusBarModule>().Any(m => IsVisible(m));

    public static string ModuleTitle(StatusBarModule module) => module switch
    {
        StatusBarModule.Gpt => "GPT/Codex",
        StatusBarModule.Claude => "Claude",
        StatusBarModule.Weather => "天气",
        StatusBarModule.Hardware => "硬件",
        StatusBarModule.Countdown => "倒计时",
        StatusBarModule.TargetTimeCountdown => "目标倒计",
        StatusBarModule.SystemReminder => "系统提醒",
        StatusBarModule.Sleep => "防休眠",
        _ => module.ToString()
    };
}
