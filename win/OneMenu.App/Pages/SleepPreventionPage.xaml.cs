using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using System.Windows.Threading;
using OneMenu.App.Services;
using OneMenu.Core.Preferences;

namespace OneMenu.App.Pages;

public partial class SleepPreventionPage : Page
{
    private readonly SleepPreventionPreferences _prefs;
    private readonly SleepPreventer? _preventer;
    private readonly DispatcherTimer _refreshTimer;

    public SleepPreventionPage(PreferencesStore store)
    {
        InitializeComponent();
        _prefs = new SleepPreventionPreferences(store);
        _preventer = (App.Current as App)?.GetSleepPreventer();

        EnableCheck.IsChecked = _prefs.IsEnabled;
        DurationBox.Text = _prefs.DurationMinutes.ToString();

        // Auto-start
        AutoStartCheck.IsChecked = AutoStartService.IsEnabled;

        UpdateStatus();

        // Refresh remaining time every second
        _refreshTimer = new DispatcherTimer(TimeSpan.FromSeconds(1), DispatcherPriority.Normal,
            (_, _) => UpdateStatus(), Dispatcher);
        _refreshTimer.Start();
    }

    private void OnToggled(object sender, RoutedEventArgs e)
    {
        var enabled = EnableCheck.IsChecked == true;
        _prefs.IsEnabled = enabled;

        if (_preventer != null)
        {
            var error = enabled
                ? _preventer.Enable(_prefs.DurationMinutes)
                : (() => { _preventer.Disable(); return null; })();

            if (error != null)
            {
                StatusLabel.Text = $"错误: {error}";
                StatusLabel.Foreground = Brushes.Red;
                _prefs.IsEnabled = false;
                EnableCheck.IsChecked = false;
                return;
            }
        }

        UpdateStatus();
    }

    private void OnDurationChanged(object sender, TextChangedEventArgs e)
    {
        if (int.TryParse(DurationBox.Text, out var mins))
            _prefs.DurationMinutes = Math.Clamp(mins, 0, 480);
    }

    private void OnAutoStartChanged(object sender, RoutedEventArgs e)
        => AutoStartService.SetEnabled(AutoStartCheck.IsChecked == true);

    private void UpdateStatus()
    {
        var enabled = _preventer?.IsEnabled ?? false;

        if (enabled)
        {
            var elapsed = _preventer?.ElapsedMinutes ?? 0;
            var total = _prefs.DurationMinutes;
            var remaining = _preventer?.RemainingMinutes(total) ?? 0;

            if (total > 0)
            {
                StatusLabel.Text =
                    $"已开启 {elapsed} 分钟 · {remaining} 分钟后自动关闭";
                RemainingLabel.Text =
                    $"☕ 咖啡杯图标已填满 · 剩余 {remaining} 分钟";
            }
            else
            {
                StatusLabel.Text = "已开启（不会自动关闭）";
                RemainingLabel.Text = "☕ 咖啡杯图标已填满";
            }
            StatusLabel.Foreground = Brushes.Green;
            RemainingLabel.Foreground = Brushes.DarkGoldenrod;
        }
        else
        {
            StatusLabel.Text = "防休眠已关闭 — 系统正常休眠。";
            StatusLabel.Foreground = Brushes.Gray;
            RemainingLabel.Text = "☕ 咖啡杯为空";
            RemainingLabel.Foreground = Brushes.Gray;
        }
    }

    ~SleepPreventionPage()
    {
        _refreshTimer.Stop();
    }
}
