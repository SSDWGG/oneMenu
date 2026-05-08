using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using OneMenu.Core.Preferences;

namespace OneMenu.App.Pages;

public partial class ColorSettingsPage : Page
{
    private readonly StatusLightColorPreferences _prefs;
    private readonly bool _isCodex;

    public record ColorItem(string Id, string Title, Brush WpfBrush);

    public new string Title => _isCodex ? "Codex/GPT" : "Claude";

    public ColorSettingsPage(PreferencesStore store, bool isCodex)
    {
        InitializeComponent();
        _isCodex = isCodex;
        _prefs = new StatusLightColorPreferences(store);
        DataContext = this;

        var colors = ColorDefinitions.StatusLightColors
            .Select(c => new ColorItem(c.Id, c.Title, new SolidColorBrush(c.ToMediaColor())))
            .ToList();

        RunningColorCombo.ItemsSource = colors;
        IdleColorCombo.ItemsSource = colors;

        var runningId = isCodex ? _prefs.RunningColorID : _prefs.RunningColorID;
        var idleId = isCodex ? _prefs.IdleColorID : _prefs.IdleColorID;

        RunningColorCombo.SelectedItem = colors.FirstOrDefault(c => c.Id == runningId);
        IdleColorCombo.SelectedItem = colors.FirstOrDefault(c => c.Id == idleId);
    }

    private void OnRunningColorChanged(object sender, SelectionChangedEventArgs e)
    {
        if (RunningColorCombo.SelectedItem is ColorItem item)
            _prefs.RunningColorID = item.Id;
    }

    private void OnIdleColorChanged(object sender, SelectionChangedEventArgs e)
    {
        if (IdleColorCombo.SelectedItem is ColorItem item)
            _prefs.IdleColorID = item.Id;
    }
}
