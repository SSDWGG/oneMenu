namespace OneMenu.Core.Preferences;

public enum AppAppearanceMode
{
    System, Light, Dark
}

public class AppAppearancePreferences
{
    private const string Key = "appAppearanceMode";
    private readonly PreferencesStore _store;

    public AppAppearancePreferences(PreferencesStore store) => _store = store;

    public AppAppearanceMode Mode
    {
        get
        {
            var rawValue = _store.GetString(Key);
            if (Enum.TryParse<AppAppearanceMode>(rawValue, out var mode))
                return mode;
            return AppAppearanceMode.System;
        }
        set => _store.Set(Key, value.ToString());
    }

    public static string ModeTitle(AppAppearanceMode mode) => mode switch
    {
        AppAppearanceMode.System => "跟随系统",
        AppAppearanceMode.Light => "浅色",
        AppAppearanceMode.Dark => "深色",
        _ => mode.ToString()
    };

    public static string ModeDescription(AppAppearanceMode mode) => mode switch
    {
        AppAppearanceMode.System => "根据 Windows 系统主题自动切换。",
        AppAppearanceMode.Light => "始终使用浅色外观。",
        AppAppearanceMode.Dark => "始终使用深色外观。",
        _ => ""
    };
}
