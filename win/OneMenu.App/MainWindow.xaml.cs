using System.Windows;
using System.Windows.Controls;
using OneMenu.Core.Preferences;
using OneMenu.App.Pages;

namespace OneMenu.App;

public partial class MainWindow : Window
{
    private readonly PreferencesStore _store;
    private readonly Dictionary<SettingsSection, Type> _pages = new()
    {
        [SettingsSection.Codex] = typeof(ColorSettingsPage),
        [SettingsSection.Claude] = typeof(ColorSettingsPage),
        [SettingsSection.Weather] = typeof(WeatherPage),
        [SettingsSection.Hardware] = typeof(HardwarePage),
        [SettingsSection.Countdown] = typeof(CountdownPage),
        [SettingsSection.TargetTime] = typeof(TargetTimePage),
        [SettingsSection.Reminder] = typeof(SystemReminderPage),
        [SettingsSection.Sleep] = typeof(SleepPreventionPage),
        [SettingsSection.Appearance] = typeof(AppearancePage),
        [SettingsSection.Notifications] = typeof(NotificationPage),
    };

    private record SidebarItem(string Title, string Subtitle);

    public MainWindow(PreferencesStore store)
    {
        InitializeComponent();
        _store = store;

        SidebarList.ItemsSource = new List<SidebarItem>
        {
            new("Codex/GPT", "活跃检测"),
            new("Claude", "活跃检测"),
            new("天气", "预报与定位"),
            new("硬件", "系统状态"),
            new("倒计时", "秒与分钟"),
            new("目标倒计", "到点分钟"),
            new("系统提醒", "单次 / 每日"),
            new("防休眠", "保持活跃"),
            new("外观", "亮暗色模式"),
            new("通知", "桌面与邮件"),
        };

        SidebarList.SelectedIndex = 0;
    }

    private void OnSectionChanged(object sender, SelectionChangedEventArgs e)
    {
        if (SidebarList.SelectedIndex < 0) return;
        var section = (SettingsSection)SidebarList.SelectedIndex;

        if (_pages.TryGetValue(section, out var pageType))
        {
            Page page;
            if (section is SettingsSection.Codex or SettingsSection.Claude)
            {
                var isCodex = section == SettingsSection.Codex;
                page = (Page)Activator.CreateInstance(pageType, _store, isCodex)!;
            }
            else
            {
                page = (Page)Activator.CreateInstance(pageType, _store)!;
            }
            ContentFrame.Navigate(page);
        }
    }
}

internal enum SettingsSection
{
    Codex, Claude, Weather, Hardware, Countdown,
    TargetTime, Reminder, Sleep, Appearance, Notifications
}
