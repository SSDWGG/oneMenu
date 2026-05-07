using System.Windows;
using System.Windows.Controls;
using OneMenu.App.Services;
using OneMenu.Core.Preferences;

namespace OneMenu.App.Pages;

public partial class SleepPreventionPage : Page
{
    private readonly SleepPreventionPreferences _prefs;
    private readonly SleepPreventer? _preventer;

    public SleepPreventionPage(PreferencesStore store)
    {
        InitializeComponent();
        _prefs = new SleepPreventionPreferences(store);

        // Find the running preventer from the application
        _preventer = (App.Current as App)?.GetSleepPreventer();

        EnableCheck.IsChecked = _prefs.IsEnabled;

        UpdateStatus();
    }

    private void OnToggled(object sender, RoutedEventArgs e)
    {
        var enabled = EnableCheck.IsChecked == true;
        _prefs.IsEnabled = enabled;

        if (_preventer != null)
        {
            var error = enabled ? _preventer.Enable() : (() => { _preventer.Disable(); return null; })();
            if (error != null)
            {
                StatusLabel.Text = $"错误: {error}";
                StatusLabel.Foreground =
                    System.Windows.Media.Brushes.Red;
                _prefs.IsEnabled = false;
                EnableCheck.IsChecked = false;
                return;
            }
        }

        UpdateStatus();
    }

    private void UpdateStatus()
    {
        var enabled = _preventer?.IsEnabled ?? _prefs.IsEnabled;
        StatusLabel.Text = enabled
            ? "防休眠已启用 — 系统将不会自动休眠。"
            : "防休眠已关闭 — 系统正常休眠。";
        StatusLabel.Foreground = enabled
            ? System.Windows.Media.Brushes.Green
            : System.Windows.Media.Brushes.Gray;
    }
}
