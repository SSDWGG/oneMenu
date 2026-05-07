using Microsoft.Toolkit.Uwp.Notifications;

namespace OneMenu.App.Services;

/// <summary>
/// Sends Windows Toast notifications via the Microsoft.Toolkit.Uwp.Notifications library.
/// Falls back to a simple trace if the toast API is unavailable (pre-Win10).
/// </summary>
public static class NotificationService
{
    private static bool _initialized;

    public static void Initialize()
    {
        if (_initialized) return;
        _initialized = true;

        try
        {
            // Register a simple COM activator identity for toast notifications to work
            // This is needed for the notification center to recognize our app
        }
        catch
        {
            // Toast notifications may not be available
        }
    }

    public static void SendSessionEnded(string sessionTitle, string monitorName)
    {
        try
        {
            new ToastContentBuilder()
                .AddText($"{monitorName} 会话结束")
                .AddText(string.IsNullOrEmpty(sessionTitle) ? "一个 AI 会话刚刚完成。" : sessionTitle)
                .Show();
        }
        catch
        {
            // Fallback: trace to debug output
            System.Diagnostics.Debug.WriteLine($"[Notification] {monitorName} session ended: {sessionTitle}");
        }
    }

    public static void SendCountdownFinished()
    {
        try
        {
            new ToastContentBuilder()
                .AddText("倒计时结束")
                .AddText("设定的倒计时已经到零。")
                .Show();
        }
        catch
        {
            System.Diagnostics.Debug.WriteLine("[Notification] Countdown finished");
        }
    }

    public static void SendCountdownReminder(int remainingSeconds)
    {
        try
        {
            new ToastContentBuilder()
                .AddText("倒计时即将结束")
                .AddText($"还剩 {FormatTime(remainingSeconds)}。")
                .Show();
        }
        catch
        {
            System.Diagnostics.Debug.WriteLine($"[Notification] Countdown reminder: {remainingSeconds}s left");
        }
    }

    public static void SendTargetTimeReached(string title)
    {
        try
        {
            new ToastContentBuilder()
                .AddText("目标时间到达")
                .AddText(string.IsNullOrEmpty(title) ? "目标时间已经到达。" : $"「{title}」已经到达。")
                .Show();
        }
        catch
        {
            System.Diagnostics.Debug.WriteLine($"[Notification] Target time reached: {title}");
        }
    }

    public static void SendSystemReminder(string title, string message)
    {
        try
        {
            new ToastContentBuilder()
                .AddText(title)
                .AddText(message)
                .Show();
        }
        catch
        {
            System.Diagnostics.Debug.WriteLine($"[Notification] Reminder: {title} - {message}");
        }
    }

    private static string FormatTime(int totalSeconds)
    {
        var m = totalSeconds / 60;
        var s = totalSeconds % 60;
        return m > 0 ? $"{m} 分 {s} 秒" : $"{s} 秒";
    }
}
