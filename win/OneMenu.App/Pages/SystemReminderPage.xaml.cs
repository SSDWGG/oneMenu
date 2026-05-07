using System.Windows;
using System.Windows.Controls;
using OneMenu.Core.Preferences;
using OneMenu.Core.Reminder;

namespace OneMenu.App.Pages;

public partial class SystemReminderPage : Page
{
    private readonly SystemReminderPreferences _prefs;

    public record ModeItem(string Title, SystemReminderMode Mode);

    public SystemReminderPage(PreferencesStore store)
    {
        InitializeComponent();
        _prefs = new SystemReminderPreferences(store);

        EnableCheck.IsChecked = _prefs.IsEnabled;
        TitleBox.Text = _prefs.Title;
        MessageBox.Text = _prefs.Message;

        ModeCombo.ItemsSource = Enum.GetValues<SystemReminderMode>()
            .Select(m => new ModeItem(SystemReminderPreferences.ModeTitle(m), m)).ToList();
        ModeCombo.SelectedItem = ((List<ModeItem>)ModeCombo.ItemsSource).First(m => m.Mode == _prefs.Mode);

        var sched = _prefs.ScheduledDate;
        HourBox.Text = sched.Hour.ToString();
        MinuteBox.Text = sched.Minute.ToString();

        EnableCheck.Checked += (_, _) => _prefs.IsEnabled = true;
        EnableCheck.Unchecked += (_, _) => _prefs.IsEnabled = false;
    }

    private void OnModeChanged(object sender, SelectionChangedEventArgs e)
    {
        if (ModeCombo.SelectedItem is ModeItem m) _prefs.Mode = m.Mode;
    }

    private void OnTimeChanged(object sender, TextChangedEventArgs e)
    {
        if (int.TryParse(HourBox.Text, out var h) && int.TryParse(MinuteBox.Text, out var min))
        {
            var now = DateTime.Now;
            _prefs.ScheduledDate = new DateTime(now.Year, now.Month, now.Day,
                Math.Clamp(h, 0, 23), Math.Clamp(min, 0, 59), 0);
        }
    }

    private void OnTitleChanged(object sender, TextChangedEventArgs e) => _prefs.Title = TitleBox.Text;
    private void OnMessageChanged(object sender, TextChangedEventArgs e) => _prefs.Message = MessageBox.Text;
}
