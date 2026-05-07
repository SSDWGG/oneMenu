using Microsoft.Win32;

namespace OneMenu.App.Services;

/// <summary>
/// Manages auto-start with Windows via the HKCU Run registry key.
/// </summary>
public static class AutoStartService
{
    private const string RunKey = @"SOFTWARE\Microsoft\Windows\CurrentVersion\Run";
    private const string ValueName = "oneMenu";

    public static bool IsEnabled
    {
        get
        {
            try
            {
                using var key = Registry.CurrentUser.OpenSubKey(RunKey);
                return key?.GetValue(ValueName) != null;
            }
            catch
            {
                return false;
            }
        }
    }

    public static void Enable()
    {
        try
        {
            using var key = Registry.CurrentUser.OpenSubKey(RunKey, writable: true)
                ?? Registry.CurrentUser.CreateSubKey(RunKey);
            var exePath = Environment.ProcessPath ?? System.Reflection.Assembly.GetEntryAssembly()?.Location;
            if (exePath != null)
                key.SetValue(ValueName, $"\"{exePath}\"");
        }
        catch { }
    }

    public static void Disable()
    {
        try
        {
            using var key = Registry.CurrentUser.OpenSubKey(RunKey, writable: true);
            key?.DeleteValue(ValueName, throwOnMissingValue: false);
        }
        catch { }
    }

    public static void SetEnabled(bool enabled)
    {
        if (enabled) Enable(); else Disable();
    }
}
