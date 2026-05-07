using System.Windows;
using System.Windows.Controls;
using OneMenu.Core.Preferences;

namespace OneMenu.App.Pages;

public partial class NotificationPage : Page
{
    private readonly SessionNotificationPreferences _prefs;

    public bool SessionNotificationEnabled
    {
        get => _prefs.IsEnabled;
        set => _prefs.IsEnabled = value;
    }

    public NotificationPage(PreferencesStore store)
    {
        InitializeComponent();
        _prefs = new SessionNotificationPreferences(store);
        DataContext = this;
    }
}
