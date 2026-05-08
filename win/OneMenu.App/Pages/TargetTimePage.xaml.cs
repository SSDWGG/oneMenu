using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using OneMenu.Core.Preferences;
using OneMenu.Core.Timers;

namespace OneMenu.App.Pages;

public partial class TargetTimePage : Page
{
    private readonly TargetTimeCountdownPreferences _prefs;

    public record ColorItem(string Id, string Title, Brush WpfBrush);
    public record BehaviorItem(string Title, TargetTimeCountdownPastBehavior Behavior);
    public record WeightItem(string Title, TargetTimeCountdownTextWeight Weight);

    public TargetTimePage(PreferencesStore store)
    {
        InitializeComponent();
        _prefs = new TargetTimeCountdownPreferences(store);

        TitleBox.Text = _prefs.Title;
        HourBox.Text = _prefs.TargetHour.ToString();
        MinuteBox.Text = _prefs.TargetMinute.ToString();

        PastBehaviorCombo.ItemsSource = Enum.GetValues<TargetTimeCountdownPastBehavior>()
            .Select(b => new BehaviorItem(TargetTimeCountdownPreferences.PastBehaviorTitle(b), b)).ToList();
        PastBehaviorCombo.SelectedItem = ((List<BehaviorItem>)PastBehaviorCombo.ItemsSource)
            .First(b => b.Behavior == _prefs.PastBehavior);

        BgColorCombo.ItemsSource = ColorDefinitions.TargetTimeCountdownBackgroundColors
            .Select(c => new ColorItem(c.Id, c.Title, new SolidColorBrush(c.ToMediaColor()))).ToList();
        BgColorCombo.SelectedItem = ((List<ColorItem>)BgColorCombo.ItemsSource)
            .First(c => c.Id == _prefs.BackgroundColorID);

        TextWeightCombo.ItemsSource = Enum.GetValues<TargetTimeCountdownTextWeight>()
            .Select(w => new WeightItem(TargetTimeCountdownPreferences.TextWeightTitle(w), w)).ToList();
        TextWeightCombo.SelectedItem = ((List<WeightItem>)TextWeightCombo.ItemsSource)
            .First(w => w.Weight == _prefs.TextWeight);

        TextColorCombo.ItemsSource = ColorDefinitions.TargetTimeCountdownTextColors
            .Select(c => new ColorItem(c.Id, c.Title, new SolidColorBrush(c.ToMediaColor()))).ToList();
        TextColorCombo.SelectedItem = ((List<ColorItem>)TextColorCombo.ItemsSource)
            .First(c => c.Id == _prefs.TextColorID);

        ShowIconCheck.IsChecked = _prefs.ShowsIcon;
    }

    private void OnTitleChanged(object sender, TextChangedEventArgs e) => _prefs.Title = TitleBox.Text;
    private void OnHourChanged(object sender, TextChangedEventArgs e) { if (int.TryParse(HourBox.Text, out var v)) _prefs.TargetHour = v; }
    private void OnMinuteChanged(object sender, TextChangedEventArgs e) { if (int.TryParse(MinuteBox.Text, out var v)) _prefs.TargetMinute = v; }
    private void OnPastBehaviorChanged(object sender, SelectionChangedEventArgs e) { if (PastBehaviorCombo.SelectedItem is BehaviorItem b) _prefs.PastBehavior = b.Behavior; }
    private void OnBgColorChanged(object sender, SelectionChangedEventArgs e) { if (BgColorCombo.SelectedItem is ColorItem c) _prefs.BackgroundColorID = c.Id; }
    private void OnTextWeightChanged(object sender, SelectionChangedEventArgs e) { if (TextWeightCombo.SelectedItem is WeightItem w) _prefs.TextWeight = w.Weight; }
    private void OnTextColorChanged(object sender, SelectionChangedEventArgs e) { if (TextColorCombo.SelectedItem is ColorItem c) _prefs.TextColorID = c.Id; }
    private void OnShowIconChanged(object sender, RoutedEventArgs e) => _prefs.ShowsIcon = ShowIconCheck.IsChecked == true;
}
