namespace OneMenu.Core.Preferences;

/// <summary>
/// Color definitions matching the macOS StatusLightColor system.
/// Used for status bar indicator colors, countdown reminder colors,
/// and target time countdown colors.
/// </summary>
public static class ColorDefinitions
{
    public record ColorOption(string Id, string Title, string HexColor);

    // ---- Status Light Colors (for GPT/Claude running/idle indicators) ----
    public static readonly List<ColorOption> StatusLightColors =
    [
        new("blue", "蓝色", "#007AFF"),
        new("green", "绿色", "#34C759"),
        new("teal", "青色", "#5AC8FA"),
        new("purple", "紫色", "#AF52DE"),
        new("orange", "橙色", "#FF9500"),
        new("yellow", "黄色", "#FFCC00"),
        new("red", "红色", "#FF3B30"),
        new("gray", "灰色", "#8E8E93"),
    ];

    public static ColorOption StatusLightColorFor(string id) =>
        StatusLightColors.FirstOrDefault(c => c.Id == id) ?? StatusLightColors[0];

    // ---- Countdown Reminder Colors ----
    public static readonly List<ColorOption> CountdownReminderColors =
    [
        new("red", "红色", "#FF3B30"),
        new("orange", "橙色", "#FF9500"),
        new("yellow", "黄色", "#FFCC00"),
        new("pink", "粉色", "#FF2D55"),
        new("purple", "紫色", "#AF52DE"),
        new("blue", "蓝色", "#007AFF"),
    ];

    public static ColorOption CountdownReminderColorFor(string id) =>
        CountdownReminderColors.FirstOrDefault(c => c.Id == id) ?? CountdownReminderColors[0];

    // ---- Target Time Countdown Background Colors ----
    public static readonly List<ColorOption> TargetTimeCountdownBackgroundColors =
    [
        new("none", "无色", "#00000000"),
        new("blue", "蓝色", "#007AFF"),
        new("green", "绿色", "#34C759"),
        new("teal", "青色", "#5AC8FA"),
        new("purple", "紫色", "#AF52DE"),
        new("orange", "橙色", "#FF9500"),
        new("yellow", "黄色", "#FFCC00"),
        new("red", "红色", "#FF3B30"),
    ];

    public static ColorOption TargetTimeCountdownBackgroundColorFor(string id) =>
        TargetTimeCountdownBackgroundColors.FirstOrDefault(c => c.Id == id) ?? TargetTimeCountdownBackgroundColors[0];

    // ---- Target Time Countdown Text Colors ----
    public static readonly List<ColorOption> TargetTimeCountdownTextColors =
    [
        new("automatic", "自动", "#000000"),
        new("white", "白色", "#FFFFFF"),
        new("black", "黑色", "#000000"),
        new("blue", "蓝色", "#007AFF"),
        new("green", "绿色", "#34C759"),
        new("teal", "青色", "#5AC8FA"),
        new("purple", "紫色", "#AF52DE"),
        new("orange", "橙色", "#FF9500"),
        new("yellow", "黄色", "#FFCC00"),
        new("red", "红色", "#FF3B30"),
    ];

    public static ColorOption TargetTimeCountdownTextColorFor(string id) =>
        TargetTimeCountdownTextColors.FirstOrDefault(c => c.Id == id) ?? TargetTimeCountdownTextColors[0];
}
