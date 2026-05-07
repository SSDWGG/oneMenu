using System.Diagnostics;
using System.Windows;
using OneMenu.App.Services;
using OneMenu.Core.Preferences;

namespace OneMenu.App;

public partial class App : Application
{
    private static Mutex? _singleInstanceMutex;
    private SystemTrayService? _trayService;
    private PreferencesStore? _store;
    private MainWindow? _settingsWindow;
    private SleepPreventer? _sleepPreventer;

    public SleepPreventer? GetSleepPreventer() => _sleepPreventer;

    protected override void OnStartup(StartupEventArgs e)
    {
        base.OnStartup(e);

        _singleInstanceMutex = new Mutex(true, "oneMenu.Windows.SingleInstance", out var isNewInstance);
        if (!isNewInstance)
        {
            MessageBox.Show("oneMenu is already running.", "oneMenu",
                MessageBoxButton.OK, MessageBoxImage.Information);
            Shutdown();
            return;
        }

        _store = new PreferencesStore();

        // Wire sleep prevention from persisted preference
        _sleepPreventer = new SleepPreventer();
        var sleepPrefs = new SleepPreventionPreferences(_store);
        if (sleepPrefs.IsEnabled)
            _sleepPreventer.Enable();

        _trayService = new SystemTrayService(_store, _sleepPreventer);
        _trayService.Start();

        GC.KeepAlive(_singleInstanceMutex);
    }

    protected override void OnExit(ExitEventArgs e)
    {
        _trayService?.Dispose();
        _settingsWindow?.Close();
        _sleepPreventer?.Dispose();
        _singleInstanceMutex?.Close();
        base.OnExit(e);
    }

    public void ShowSettings()
    {
        if (_settingsWindow == null || !_settingsWindow.IsVisible)
        {
            _settingsWindow = new MainWindow(_store!);
            _settingsWindow.Closed += (_, _) => _settingsWindow = null;
        }
        _settingsWindow.Show();
        _settingsWindow.Activate();
    }

    public static void OpenFolder(string path)
    {
        try
        {
            Process.Start("explorer.exe", path);
        }
        catch
        {
            MessageBox.Show($"Cannot open: {path}", "oneMenu",
                MessageBoxButton.OK, MessageBoxImage.Warning);
        }
    }

    public static new App Current => (App)Application.Current;
}
