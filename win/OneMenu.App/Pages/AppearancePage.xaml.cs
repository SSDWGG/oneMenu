using System.Windows;
using System.Windows.Controls;
using OneMenu.Core.Preferences;

namespace OneMenu.App.Pages;

public partial class AppearancePage : Page
{
    private readonly AppAppearancePreferences _prefs;

    public record ModeItem(string Title, string Description, AppAppearanceMode Mode);

    public AppearancePage(PreferencesStore store)
    {
        InitializeComponent();
        _prefs = new AppAppearancePreferences(store);

        var modes = Enum.GetValues<AppAppearanceMode>()
            .Select(m => new ModeItem(
                AppAppearancePreferences.ModeTitle(m),
                AppAppearancePreferences.ModeDescription(m), m))
            .ToList();

        ModeCombo.ItemsSource = modes;
        ModeCombo.SelectedItem = modes.FirstOrDefault(m => m.Mode == _prefs.Mode);
    }

    private void OnModeChanged(object sender, SelectionChangedEventArgs e)
    {
        if (ModeCombo.SelectedItem is ModeItem item)
            _prefs.Mode = item.Mode;
    }
}
