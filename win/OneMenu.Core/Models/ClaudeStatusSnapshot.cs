namespace OneMenu.Core.Models;

public enum ClaudeState
{
    Idle,
    Thinking
}

public record ClaudeStatusSnapshot(
    ClaudeState State,
    int ActiveSessionCount,
    DateTime? LatestEventAt,
    string? LatestEventType,
    string? LatestSessionFile,
    string? LatestSessionTitle,
    List<StatusSessionSummary> ActiveSessions,
    List<StatusSessionSummary> IdleSessions,
    string[] ActiveSessionTitles,
    string[] IdleSessionTitles,
    int ScannedFileCount,
    TimeSpan StaleAfter,
    string ClaudeHome,
    string? ErrorMessage)
{
    public bool IsThinking => State == ClaudeState.Thinking;

    public static ClaudeStatusSnapshot Empty(TimeSpan staleAfter, string claudeHome, string errorMessage) =>
        new(
            State: ClaudeState.Idle,
            ActiveSessionCount: 0,
            LatestEventAt: null,
            LatestEventType: null,
            LatestSessionFile: null,
            LatestSessionTitle: null,
            ActiveSessions: [],
            IdleSessions: [],
            ActiveSessionTitles: [],
            IdleSessionTitles: [],
            ScannedFileCount: 0,
            StaleAfter: staleAfter,
            ClaudeHome: claudeHome,
            ErrorMessage: errorMessage);
}
