namespace OneMenu.Core.Models;

public enum CodexState
{
    Idle,
    Thinking
}

public record CodexStatusSnapshot(
    CodexState State,
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
    string CodexHome,
    string? ErrorMessage)
{
    public bool IsThinking => State == CodexState.Thinking;

    public static CodexStatusSnapshot Empty(TimeSpan staleAfter, string codexHome, string errorMessage) =>
        new(
            State: CodexState.Idle,
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
            CodexHome: codexHome,
            ErrorMessage: errorMessage);
}
