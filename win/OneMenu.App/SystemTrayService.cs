using System.Diagnostics;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Windows;
using H.NotifyIcon;
using OneMenu.App.Services;
using OneMenu.Core.Monitors;
using OneMenu.Core.Preferences;
using OneMenu.Core.Reminder;
using OneMenu.Core.Timers;
using OneMenu.Core.Weather;
using OneMenu.HardwareMonitor;
using OneMenu.HardwareMonitor.Models;

namespace OneMenu.App;

public class SystemTrayService : IDisposable
{
    private readonly PreferencesStore _store;
    private readonly StatusLightColorPreferences _colorPrefs;
    private readonly HardwareStatusBarPreferences _hwPrefs;
    private readonly SessionNotificationPreferences _notifyPrefs;
    private readonly CodexStatusMonitor _gptMonitor;
    private readonly ClaudeStatusMonitor _claudeMonitor;
    private readonly HardwareStatusMonitor _hwMonitor;
    private readonly WeatherService _weatherService;
    private readonly ActiveWorkTransitionTracker _gptTracker;
    private readonly ActiveWorkTransitionTracker _claudeTracker;

    // Countdown
    private readonly CountdownTimerPreferences _countdownPrefs;
    private readonly CountdownTimerController _countdownTimer;

    // Target time
    private readonly TargetTimeCountdownPreferences _targetPrefs;

    // System reminder
    private readonly SystemReminderPreferences _reminderPrefs;
    private readonly SleepPreventionPreferences _sleepPrefs;
    private readonly SleepPreventer _sleepPreventer;

    // Tray icons
    private readonly TaskbarIcon _gptIcon;
    private readonly TaskbarIcon _claudeIcon;
    private readonly TaskbarIcon _weatherIcon;
    private readonly TaskbarIcon _hwIcon;
    private readonly TaskbarIcon _countdownIcon;
    private readonly TaskbarIcon _targetIcon;
    private readonly TaskbarIcon _reminderIcon;
    private readonly TaskbarIcon _sleepIcon;

    private PeriodicTimer? _pollTimer;
    private CancellationTokenSource? _cts;

    private CodexStatusSnapshot? _lastGptSnapshot;
    private ClaudeStatusSnapshot? _lastClaudeSnapshot;
    private WeatherServiceSnapshot _lastWeatherSnapshot = WeatherServiceSnapshot.Create(WeatherServiceState.Idle);
    private CountdownSnapshot _lastCountdownSnapshot;
    private TargetTimeCountdownSnapshot _lastTargetSnapshot;
    private SystemReminderSnapshot _lastReminderSnapshot;

    public SystemTrayService(PreferencesStore store, SleepPreventer sleepPreventer)
    {
        _store = store;
        _colorPrefs = new StatusLightColorPreferences(store);
        _hwPrefs = new HardwareStatusBarPreferences(store);
        _notifyPrefs = new SessionNotificationPreferences(store);
        _countdownPrefs = new CountdownTimerPreferences(store);
        _targetPrefs = new TargetTimeCountdownPreferences(store);
        _reminderPrefs = new SystemReminderPreferences(store);
        _sleepPrefs = new SleepPreventionPreferences(store);
        _sleepPreventer = sleepPreventer;

        _gptMonitor = new CodexStatusMonitor();
        _claudeMonitor = new ClaudeStatusMonitor();
        _hwMonitor = new HardwareStatusMonitor();
        _weatherService = new WeatherService();
        _gptTracker = new ActiveWorkTransitionTracker();
        _claudeTracker = new ActiveWorkTransitionTracker();
        _countdownTimer = new CountdownTimerController(_countdownPrefs);

        _gptIcon = CreateIcon();
        _claudeIcon = CreateIcon();
        _weatherIcon = CreateIcon();
        _hwIcon = CreateIcon();
        _countdownIcon = CreateIcon();
        _targetIcon = CreateIcon();
        _reminderIcon = CreateIcon();
        _sleepIcon = CreateIcon();

        _gptIcon.TrayMouseDoubleClick += (_, _) => ShowSettings();
        _claudeIcon.TrayMouseDoubleClick += (_, _) => ShowSettings();
        _countdownIcon.TrayMouseDoubleClick += (_, _) => ToggleCountdown();
        _sleepIcon.TrayMouseDoubleClick += (_, _) => ToggleSleep();

        _weatherService.OnSnapshotChanged += snap =>
        {
            _lastWeatherSnapshot = snap;
            Application.Current?.Dispatcher.Invoke(UpdateWeatherIcon);
        };

        _countdownTimer.OnChange += snap =>
        {
            _lastCountdownSnapshot = snap;
            Application.Current?.Dispatcher.Invoke(() => UpdateCountdownIcon(snap));
        };

        NotificationService.Initialize();
    }

    public void Start()
    {
        UpdateAllIcons();
        _ = _weatherService.StartAsync();

        _cts = new CancellationTokenSource();
        _ = PollLoop(_cts.Token);
    }

    private async Task PollLoop(CancellationToken ct)
    {
        _pollTimer = new PeriodicTimer(TimeSpan.FromSeconds(1));
        var weatherTicks = 0;

        try
        {
            while (await _pollTimer.WaitForNextTickAsync(ct))
            {
                try
                {
                    UpdateAIStatusIcons();
                    UpdateHardwareIcon();
                    UpdateTargetTimeIcon();
                    UpdateReminderIcon();
                    UpdateSleepIcon();

                    // Tick countdown (1s interval)
                    _countdownTimer.Tick();

                    // Refresh weather every 5 minutes
                    weatherTicks++;
                    if (weatherTicks >= 300)
                    {
                        weatherTicks = 0;
                        await _weatherService.RefreshIfNeededAsync();
                    }
                }
                catch { }
            }
        }
        catch (OperationCanceledException) { }
    }

    private void UpdateAllIcons()
    {
        UpdateAIStatusIcons();
        UpdateHardwareIcon();
        UpdateWeatherIcon();
        UpdateCountdownIcon(_countdownTimer.Snapshot());
        UpdateTargetTimeIcon();
        UpdateReminderIcon();
        UpdateSleepIcon();
    }

    #region AI Status

    private void UpdateAIStatusIcons()
    {
        // GPT
        var gpt = _gptMonitor.Snapshot();
        _lastGptSnapshot = gpt;
        var gptDone = _gptTracker.Update(gpt.ActiveSessionCount);

        if (gpt.ErrorMessage != null)
        {
            _gptIcon.Icon = CircleIcon(Color.Gray);
            _gptIcon.ToolTipText = $"GPT: {gpt.ErrorMessage}";
        }
        else if (gpt.IsThinking)
        {
            _gptIcon.Icon = CircleIcon(_colorPrefs.RunningColor.WpfColor);
            _gptIcon.ToolTipText = $"GPT: {gpt.ActiveSessionCount} active · {gpt.ScannedFileCount} sessions";
        }
        else
        {
            _gptIcon.Icon = CircleIcon(_colorPrefs.IdleColor.WpfColor);
            _gptIcon.ToolTipText = $"GPT: idle · {gpt.ScannedFileCount} sessions";
        }

        if (gptDone && _notifyPrefs.IsEnabled && gpt.LatestSessionTitle != null)
            NotificationService.SendSessionEnded(gpt.LatestSessionTitle, "GPT");

        // Claude
        var claude = _claudeMonitor.Snapshot();
        _lastClaudeSnapshot = claude;
        var claudeDone = _claudeTracker.Update(claude.ActiveSessionCount);

        if (claude.ErrorMessage != null)
        {
            _claudeIcon.Icon = CircleIcon(Color.Gray);
            _claudeIcon.ToolTipText = $"Claude: {claude.ErrorMessage}";
        }
        else if (claude.IsThinking)
        {
            _claudeIcon.Icon = CircleIcon(Color.Orange);
            _claudeIcon.ToolTipText = $"Claude: {claude.ActiveSessionCount} active · {claude.ScannedFileCount} sessions";
        }
        else
        {
            _claudeIcon.Icon = CircleIcon(Color.White);
            _claudeIcon.ToolTipText = $"Claude: idle · {claude.ScannedFileCount} sessions";
        }

        if (claudeDone && _notifyPrefs.IsEnabled && claude.LatestSessionTitle != null)
            NotificationService.SendSessionEnded(claude.LatestSessionTitle, "Claude");
    }

    #endregion

    #region Hardware

    private void UpdateHardwareIcon()
    {
        var snap = _hwMonitor.Snapshot();
        var (text, tip) = FormatHardware(snap);
        _hwIcon.Icon = TextIcon(text, Color.White);
        _hwIcon.ToolTipText = tip;
    }

    private (string, string) FormatHardware(HardwareStatusSnapshot snap)
    {
        return _hwPrefs.Metric switch
        {
            HardwareStatusBarMetric.CpuUsage =>
                snap.CpuUsagePercent.HasValue
                    ? ($"CPU {snap.CpuUsagePercent,3:F0}%", $"CPU: {snap.CpuUsagePercent:F1}%\nGPU: {snap.Gpu.Name ?? "N/A"}")
                    : ("CPU --%", "CPU: detecting..."),
            HardwareStatusBarMetric.MemoryUsage =>
                ($"MEM {snap.Memory.UsedPercent,3:F0}%",
                 $"Memory: {FormatBytes((long)snap.Memory.UsedBytes)} / {FormatBytes((long)snap.Memory.TotalBytes)}"),
            HardwareStatusBarMetric.BatteryLevel =>
                snap.Battery != null ? ($"BAT {snap.Battery.Percent,3}%", $"Battery: {snap.Battery.Percent}%") : ("BAT --%", "No battery"),
            HardwareStatusBarMetric.ThermalState => ($"Therm {snap.ThermalState}", $"Thermal: {snap.ThermalState}"),
            HardwareStatusBarMetric.CpuTemperature =>
                snap.CpuTemperature != null ? ($"CPU {snap.CpuTemperature.Celsius,4:F0}°C", $"CPU: {snap.CpuTemperature.Celsius:F1}°C") : ("CPU --°C", "N/A"),
            HardwareStatusBarMetric.GpuTemperature =>
                snap.GpuTemperature != null ? ($"GPU {snap.GpuTemperature.Celsius,4:F0}°C", $"GPU: {snap.GpuTemperature.Celsius:F1}°C") : ("GPU --°C", "N/A"),
            HardwareStatusBarMetric.FanSpeed =>
                snap.Fans.FirstOrDefault() is { } fan ? ($"FAN {fan.Rpm,4:F0}", $"{fan.Name}: {fan.Rpm:F0} RPM") : ("FAN --", "N/A"),
            _ => ("--", "")
        };
    }

    #endregion

    #region Weather

    private void UpdateWeatherIcon()
    {
        var snap = _lastWeatherSnapshot;
        switch (snap.State)
        {
            case WeatherServiceState.Loaded when snap.Forecast != null:
                var f = snap.Forecast;
                _weatherIcon.Icon = TextIcon($"{f.Current.Condition.Symbol} {f.Current.Temperature:F0}°", Color.White);
                _weatherIcon.ToolTipText = $"{f.Current.Condition.Title} · {f.Current.Temperature:F1}°C · Humidity {f.Current.Humidity ?? 0:F0}%";
                break;
            case WeatherServiceState.Loading:
                _weatherIcon.Icon = TextIcon("...", Color.Gray);
                _weatherIcon.ToolTipText = "Weather loading...";
                break;
            case WeatherServiceState.Failed:
                _weatherIcon.Icon = TextIcon("--", Color.Gray);
                _weatherIcon.ToolTipText = snap.ErrorMessage ?? "Weather failed";
                break;
            default:
                _weatherIcon.Icon = TextIcon("--", Color.Gray);
                _weatherIcon.ToolTipText = "Weather: starting...";
                break;
        }
    }

    #endregion

    #region Countdown

    private void UpdateCountdownIcon(CountdownSnapshot snap)
    {
        _lastCountdownSnapshot = snap;
        var wasFinished = _lastCountdownSnapshot.State == CountdownRunState.Finished;

        switch (snap.State)
        {
            case CountdownRunState.Idle:
                _countdownIcon.Icon = TextIcon(FormatCountdown(snap.TotalSeconds), Color.White);
                _countdownIcon.ToolTipText = "Click to start countdown";
                break;
            case CountdownRunState.Running:
                _countdownIcon.Icon = TextIcon(FormatCountdown(snap.RemainingSeconds),
                    _countdownPrefs.IsReminderActive(snap) ? Color.Red : Color.White);
                _countdownIcon.ToolTipText = $"Remaining: {FormatCountdown(snap.RemainingSeconds)}\nClick to pause";
                break;
            case CountdownRunState.Paused:
                _countdownIcon.Icon = TextIcon($"II {FormatCountdown(snap.RemainingSeconds)}", Color.Orange);
                _countdownIcon.ToolTipText = $"Paused at {FormatCountdown(snap.RemainingSeconds)}\nClick to resume";
                break;
            case CountdownRunState.Finished:
                _countdownIcon.Icon = TextIcon("DONE!", Color.Red);
                _countdownIcon.ToolTipText = "Finished! Click to reset";
                if (!wasFinished)
                    NotificationService.SendCountdownFinished();
                break;
        }
    }

    private void ToggleCountdown()
    {
        switch (_lastCountdownSnapshot.State)
        {
            case CountdownRunState.Idle:
            case CountdownRunState.Finished:
                _countdownTimer.Start();
                break;
            case CountdownRunState.Running:
                _countdownTimer.Pause();
                break;
            case CountdownRunState.Paused:
                _countdownTimer.Resume();
                break;
        }
    }

    #endregion

    #region Target Time

    private void UpdateTargetTimeIcon()
    {
        var snap = _targetPrefs.Snapshot();
        _lastTargetSnapshot = snap;

        var text = $"{snap.Title} {FormatMinutes(snap.MinutesRemaining)}";
        _targetIcon.Icon = TextIcon(text, Color.White);
        _targetIcon.ToolTipText = $"{snap.Title}: {snap.TargetHour:D2}:{snap.TargetMinute:D2}\n" +
                                  $"Remaining: {FormatMinutes(snap.MinutesRemaining)}\n" +
                                  $"{(snap.IsPastTodayTarget ? "Past target" : "Upcoming")}";
    }

    #endregion

    #region Reminder

    private void UpdateReminderIcon()
    {
        var snap = _reminderPrefs.Snapshot();
        _lastReminderSnapshot = snap;

        if (!snap.IsEnabled)
        {
            _reminderIcon.Icon = TextIcon("OFF", Color.Gray);
            _reminderIcon.ToolTipText = "Reminder disabled";
            return;
        }

        var nextFire = snap.NextFireDate;
        if (nextFire.HasValue)
        {
            var remaining = nextFire.Value - DateTime.Now;
            var text = remaining.TotalMinutes >= 60
                ? $"{remaining.TotalHours:F0}h"
                : $"{remaining.TotalMinutes:F0}m";
            _reminderIcon.Icon = TextIcon($"R {text}", Color.Yellow);
            _reminderIcon.ToolTipText =
                $"{snap.Title}\n{snap.Message}\nFire: {nextFire:yyyy-MM-dd HH:mm}";
        }
        else
        {
            _reminderIcon.Icon = TextIcon("R --", Color.Gray);
            _reminderIcon.ToolTipText = $"{snap.Title}\nNo upcoming fire";
        }
    }

    /// <summary>
    /// Check if the reminder should fire now (called each tick).
    /// For simplicity, we check if current minute matches.
    /// </summary>
    private SystemReminderSnapshot? _lastFiredReminder;
    private void CheckAndFireReminder()
    {
        var now = DateTime.Now;
        var normalized = new DateTime(now.Year, now.Month, now.Day, now.Hour, now.Minute, 0);

        if (_lastReminderSnapshot.NextFireDate.HasValue)
        {
            var fireTime = new DateTime(
                _lastReminderSnapshot.NextFireDate.Value.Year,
                _lastReminderSnapshot.NextFireDate.Value.Month,
                _lastReminderSnapshot.NextFireDate.Value.Day,
                _lastReminderSnapshot.NextFireDate.Value.Hour,
                _lastReminderSnapshot.NextFireDate.Value.Minute, 0);

            if (normalized == fireTime && (_lastFiredReminder?.NextFireDate != _lastReminderSnapshot.NextFireDate))
            {
                _lastFiredReminder = _lastReminderSnapshot;
                NotificationService.SendSystemReminder(
                    _lastReminderSnapshot.Title, _lastReminderSnapshot.Message);
            }
        }
    }

    #endregion

    #region Sleep

    private void UpdateSleepIcon()
    {
        var enabled = _sleepPreventer.IsEnabled;
        _sleepIcon.Icon = TextIcon(enabled ? "AWAKE" : "Z", enabled ? Color.Green : Color.Gray);
        _sleepIcon.ToolTipText = enabled
            ? "Sleep prevention ON — system will not sleep.\nClick to disable."
            : "Sleep prevention OFF\nClick to enable.";
    }

    private void ToggleSleep()
    {
        var error = _sleepPreventer.Toggle();
        if (error != null)
        {
            _sleepPrefs.IsEnabled = _sleepPreventer.IsEnabled;
            return;
        }
        _sleepPrefs.IsEnabled = _sleepPreventer.IsEnabled;
        UpdateSleepIcon();
    }

    #endregion

    #region Icon Helpers

    private static TaskbarIcon CreateIcon()
    {
        return new TaskbarIcon
        {
            Icon = CircleIcon(Color.DimGray),
            Visibility = Visibility.Visible,
            ContextMenuMode = ContextMenuMode.SecondButton
        };
    }

    private static Icon CircleIcon(Color color)
    {
        var bmp = new Bitmap(24, 24);
        using var g = Graphics.FromImage(bmp);
        g.SmoothingMode = SmoothingMode.AntiAlias;
        using var brush = new SolidBrush(color);
        g.FillEllipse(brush, 4, 4, 16, 16);
        return Icon.FromHandle(bmp.GetHicon());
    }

    private static Icon TextIcon(string text, Color color)
    {
        var bmp = new Bitmap(64, 16);
        using var g = Graphics.FromImage(bmp);
        g.SmoothingMode = SmoothingMode.AntiAlias;

        // Measure and fit text
        using var font = new Font("Segoe UI", 8.5f, FontStyle.Regular);
        var maxWidth = Math.Min(62, text.Length * 8);
        using var brush = new SolidBrush(color);
        g.DrawString(text, font, brush, 0, 1);
        return Icon.FromHandle(bmp.GetHicon());
    }

    #endregion

    #region Format Helpers

    private static string FormatCountdown(int totalSeconds)
    {
        var m = totalSeconds / 60;
        var s = totalSeconds % 60;
        if (m >= 60) return $"{m / 60}h{m % 60:D2}m";
        return $"{m:D2}:{s:D2}";
    }

    private static string FormatMinutes(int minutes)
    {
        if (minutes >= 60) return $"{minutes / 60}h{minutes % 60:D2}m";
        return $"{minutes}m";
    }

    private static string FormatBytes(long bytes) => bytes switch
    {
        < 1024 => $"{bytes} B",
        < 1048576 => $"{bytes / 1024.0:F1} KB",
        < 1073741824 => $"{bytes / 1048576.0:F1} MB",
        _ => $"{bytes / 1073741824.0:F2} GB"
    };

    #endregion

    private static void ShowSettings() =>
        Application.Current.Dispatcher.Invoke(() =>
        {
            if (Application.Current is App app) app.ShowSettings();
        });

    public void Dispose()
    {
        _cts?.Cancel();
        _pollTimer?.Dispose();
        _cts?.Dispose();
        _weatherService.Dispose();
        _gptIcon.Dispose();
        _claudeIcon.Dispose();
        _weatherIcon.Dispose();
        _hwIcon.Dispose();
        _countdownIcon.Dispose();
        _targetIcon.Dispose();
        _reminderIcon.Dispose();
        _sleepIcon.Dispose();
    }
}
