using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using OneMenu.Core.Preferences;
using OneMenu.Core.Timers;

namespace OneMenu.App.Pages;

public partial class CountdownPage : Page
{
    private readonly CountdownTimerPreferences _prefs;

    public record ColorItem(string Id, string Title, Brush WpfBrush);

    public CountdownPage(PreferencesStore store)
    {
        InitializeComponent();
        _prefs = new CountdownTimerPreferences(store);

        DurationValue.Text = _prefs.DurationValue.ToString();
        DurationUnit.SelectedItem = _prefs.DurationUnit == CountdownDurationUnit.Minutes
            ? DurationUnit.Items[1] : DurationUnit.Items[0];

        ReminderValue.Text = _prefs.ReminderLeadValue.ToString();
        ReminderUnit.SelectedItem = _prefs.ReminderLeadUnit == CountdownDurationUnit.Minutes
            ? ReminderUnit.Items[1] : ReminderUnit.Items[0];

        var colors = ColorDefinitions.CountdownReminderColors
            .Select(c => new ColorItem(c.Id, c.Title, new SolidColorBrush(c.ToMediaColor())))
            .ToList();
        ReminderColor.ItemsSource = colors;
        ReminderColor.SelectedItem = colors.FirstOrDefault(c => c.Id == _prefs.ReminderColorID);
    }

    private void OnDurationChanged(object sender, TextChangedEventArgs e)
    {
        if (int.TryParse(DurationValue.Text, out var v))
            _prefs.DurationValue = Math.Clamp(v, 1, 9999);
    }

    private void OnDurationUnitChanged(object sender, SelectionChangedEventArgs e)
    {
        _prefs.DurationUnit = ((ComboBoxItem)DurationUnit.SelectedItem).Tag.ToString() == "Minutes"
            ? CountdownDurationUnit.Minutes : CountdownDurationUnit.Seconds;
    }

    private void OnReminderChanged(object sender, TextChangedEventArgs e)
    {
        if (int.TryParse(ReminderValue.Text, out var v))
            _prefs.ReminderLeadValue = Math.Clamp(v, 0, 9999);
    }

    private void OnReminderUnitChanged(object sender, SelectionChangedEventArgs e)
    {
        _prefs.ReminderLeadUnit = ((ComboBoxItem)ReminderUnit.SelectedItem).Tag.ToString() == "Minutes"
            ? CountdownDurationUnit.Minutes : CountdownDurationUnit.Seconds;
    }

    private void OnReminderColorChanged(object sender, SelectionChangedEventArgs e)
    {
        if (ReminderColor.SelectedItem is ColorItem item)
            _prefs.ReminderColorID = item.Id;
    }
}
