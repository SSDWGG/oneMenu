using System.Runtime.InteropServices;

namespace OneMenu.App.Services;

/// <summary>
/// Prevents Windows from sleeping using SetThreadExecutionState (kernel32).
/// Equivalent to macOS IOPMAssertionCreateWithName.
/// </summary>
public class SleepPreventer : IDisposable
{
    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern uint SetThreadExecutionState(uint esFlags);

    // ReSharper disable InconsistentNaming
    private const uint ES_CONTINUOUS = 0x80000000;
    private const uint ES_SYSTEM_REQUIRED = 0x00000001;
    private const uint ES_DISPLAY_REQUIRED = 0x00000002;
    // ReSharper restore InconsistentNaming

    private bool _isEnabled;

    public bool IsEnabled => _isEnabled;

    /// <summary>
    /// Prevents system sleep and display sleep.
    /// Returns null on success, or an error message on failure.
    /// </summary>
    public string? Enable()
    {
        if (_isEnabled) return null;

        try
        {
            var result = SetThreadExecutionState(
                ES_CONTINUOUS | ES_SYSTEM_REQUIRED | ES_DISPLAY_REQUIRED);

            if (result == 0)
            {
                var err = Marshal.GetLastWin32Error();
                return $"SetThreadExecutionState failed (error {err})";
            }

            _isEnabled = true;
            return null;
        }
        catch (Exception ex)
        {
            return $"Sleep prevention failed: {ex.Message}";
        }
    }

    /// <summary>
    /// Restores normal sleep behavior.
    /// </summary>
    public void Disable()
    {
        if (!_isEnabled) return;

        SetThreadExecutionState(ES_CONTINUOUS);
        _isEnabled = false;
    }

    /// <summary>
    /// Toggle sleep prevention on/off.
    /// </summary>
    public string? Toggle()
    {
        return _isEnabled ? (() => { Disable(); return null; })() : Enable();
    }

    public void Dispose()
    {
        if (_isEnabled) Disable();
    }
}
