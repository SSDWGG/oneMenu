using System.Runtime.InteropServices;

namespace OneMenu.App.Services;

public class SleepPreventer : IDisposable
{
    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern uint SetThreadExecutionState(uint esFlags);

    private const uint ES_CONTINUOUS = 0x80000000;
    private const uint ES_SYSTEM_REQUIRED = 0x00000001;
    private const uint ES_DISPLAY_REQUIRED = 0x00000002;

    private bool _isEnabled;
    private CancellationTokenSource? _autoDisableCts;
    private DateTime? _enabledAt;

    public bool IsEnabled => _isEnabled;
    public event Action? OnAutoDisabled;

    public string? Enable(int durationMinutes = 0)
    {
        if (_isEnabled) return null;

        var result = SetThreadExecutionState(
            ES_CONTINUOUS | ES_SYSTEM_REQUIRED | ES_DISPLAY_REQUIRED);
        if (result == 0)
            return $"SetThreadExecutionState failed (error {Marshal.GetLastWin32Error()})";

        _isEnabled = true;
        _enabledAt = DateTime.Now;

        if (durationMinutes > 0)
        {
            _autoDisableCts?.Cancel();
            _autoDisableCts = new CancellationTokenSource();
            var ct = _autoDisableCts.Token;
            _ = Task.Run(async () =>
            {
                try
                {
                    await Task.Delay(TimeSpan.FromMinutes(durationMinutes), ct);
                    if (!ct.IsCancellationRequested)
                    {
                        Disable();
                        OnAutoDisabled?.Invoke();
                    }
                }
                catch (TaskCanceledException) { }
            }, ct);
        }

        return null;
    }

    public void Disable()
    {
        if (!_isEnabled) return;
        _autoDisableCts?.Cancel();
        SetThreadExecutionState(ES_CONTINUOUS);
        _isEnabled = false;
        _enabledAt = null;
    }

    public string? Toggle(int durationMinutes = 0)
    {
        if (_isEnabled) { Disable(); return null; }
        return Enable(durationMinutes);
    }

    public int ElapsedMinutes =>
        _isEnabled && _enabledAt.HasValue
            ? (int)(DateTime.Now - _enabledAt.Value).TotalMinutes : 0;

    public int RemainingMinutes(int totalDuration) =>
        _isEnabled && _enabledAt.HasValue
            ? Math.Max(0, totalDuration - ElapsedMinutes) : 0;

    public void Dispose()
    {
        _autoDisableCts?.Cancel();
        if (_isEnabled) Disable();
    }
}
