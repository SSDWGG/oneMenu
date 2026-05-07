using System.Text.Json;
using OneMenu.Core.Infrastructure;
using OneMenu.Core.Models;

namespace OneMenu.Core.Monitors;

public class ClaudeStatusMonitor
{
    private readonly string _claudeHome;
    private readonly TimeSpan _staleAfter;
    private readonly string _projectsDirectory;
    private readonly int _scanLimit;
    private readonly ClaudeJsonParser _parser;

    public string ClaudeHome => _claudeHome;

    public ClaudeStatusMonitor(
        string? claudeHome = null,
        TimeSpan? staleAfter = null,
        int scanLimit = 100)
    {
        _claudeHome = claudeHome
            ?? Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.UserProfile), ".claude");
        _staleAfter = staleAfter ?? TimeSpan.FromMinutes(30);
        _scanLimit = scanLimit;
        _projectsDirectory = Path.Combine(_claudeHome, "projects");
        _parser = new ClaudeJsonParser();
    }

    public ClaudeStatusSnapshot Snapshot(DateTime? now = null)
    {
        var nowValue = now ?? DateTime.UtcNow;

        if (!Directory.Exists(_projectsDirectory))
        {
            return ClaudeStatusSnapshot.Empty(_staleAfter, _claudeHome, "没有找到 Claude projects 目录");
        }

        try
        {
            var files = RecentProjectFiles(_scanLimit);
            ClaudeSessionActivity? latestActivity = null;
            var activeActivities = new List<ClaudeSessionActivity>();
            var idleActivities = new List<ClaudeSessionActivity>();

            foreach (var file in files)
            {
                var activity = _parser.Parse(file.path, file.modifiedAt);
                if (activity == null) continue;

                if (IsNewer(activity, latestActivity))
                    latestActivity = activity;

                if (activity.IsOpenTask && IsFresh(activity, nowValue))
                    activeActivities.Add(activity);
                else
                    idleActivities.Add(activity);
            }

            var representative = NewestActivity(activeActivities) ?? latestActivity;
            var activeSessions = SessionSummaries(activeActivities);
            var idleSessions = SessionSummaries(idleActivities);

            return new ClaudeStatusSnapshot(
                State: activeActivities.Count == 0 ? ClaudeState.Idle : ClaudeState.Thinking,
                ActiveSessionCount: activeActivities.Count,
                LatestEventAt: representative?.LatestEventAt,
                LatestEventType: representative?.LatestEventType,
                LatestSessionFile: representative?.FilePath,
                LatestSessionTitle: representative != null ? SessionTitle(representative) : null,
                ActiveSessions: activeSessions,
                IdleSessions: idleSessions,
                ActiveSessionTitles: activeSessions.Select(s => s.Title).ToArray(),
                IdleSessionTitles: idleSessions.Select(s => s.Title).ToArray(),
                ScannedFileCount: files.Count,
                StaleAfter: _staleAfter,
                ClaudeHome: _claudeHome,
                ErrorMessage: null);
        }
        catch (Exception ex)
        {
            return ClaudeStatusSnapshot.Empty(_staleAfter, _claudeHome, ex.Message);
        }
    }

    private List<(string path, DateTime modifiedAt)> RecentProjectFiles(int limit)
    {
        var files = new List<(string path, DateTime modifiedAt)>();

        try
        {
            foreach (var filePath in Directory.EnumerateFiles(_projectsDirectory, "*.jsonl",
                SearchOption.AllDirectories))
            {
                try
                {
                    var fileInfo = new FileInfo(filePath);
                    files.Add((filePath, fileInfo.LastWriteTimeUtc));
                }
                catch
                {
                    // skip inaccessible files
                }
            }
        }
        catch
        {
            // directory enumeration failed
        }

        return files
            .OrderByDescending(f => f.modifiedAt)
            .Take(limit)
            .ToList();
    }

    private bool IsFresh(ClaudeSessionActivity activity, DateTime now)
    {
        var freshnessDate = Max(activity.LatestEventAt ?? activity.ModifiedAt, activity.ModifiedAt);
        return (now - freshnessDate) <= _staleAfter;
    }

    private static bool IsNewer(ClaudeSessionActivity activity, ClaudeSessionActivity? other)
    {
        if (other == null) return true;
        return (activity.LatestEventAt ?? activity.ModifiedAt) >
               (other.LatestEventAt ?? other.ModifiedAt);
    }

    private static ClaudeSessionActivity? NewestActivity(List<ClaudeSessionActivity> activities)
    {
        return activities.MaxBy(a => a.LatestEventAt ?? a.ModifiedAt);
    }

    private static List<StatusSessionSummary> SessionSummaries(List<ClaudeSessionActivity> activities)
    {
        return activities
            .OrderByDescending(a => a.LatestEventAt ?? a.ModifiedAt)
            .Select(a => new StatusSessionSummary(
                Id: a.FilePath,
                Title: SessionTitle(a),
                LastAnswer: a.LastAnswer))
            .ToList();
    }

    private static string SessionTitle(ClaudeSessionActivity activity) =>
        SessionTitleNormalizer.DisplayTitle(activity.Title);

    private static DateTime Max(DateTime a, DateTime b) => a > b ? a : b;

    /// <summary>
    /// JSONL event parser for Claude session files.
    /// </summary>
    private class ClaudeJsonParser
    {
        private static readonly string[] IsoFormats =
        {
            "yyyy-MM-dd'T'HH:mm:ss.FFFFFFF'Z'",
            "yyyy-MM-dd'T'HH:mm:ss.FFFFFFFzzz",
            "yyyy-MM-dd'T'HH:mm:ss'Z'",
            "yyyy-MM-dd'T'HH:mm:sszzz"
        };

        private enum TurnState { Started, Completed, Ignored }

        public ClaudeSessionActivity? Parse(string filePath, DateTime modifiedAt)
        {
            try
            {
                var text = new JsonlFileReader().ReadTail(filePath);
                var activity = new ClaudeSessionActivity
                {
                    FilePath = filePath,
                    ModifiedAt = modifiedAt
                };

                foreach (var line in text.Split('\n'))
                {
                    var trimmed = line.Trim();
                    if (trimmed.Length == 0) continue;

                    var evt = ParseEvent(trimmed);
                    if (evt == null) continue;

                    activity.SawAnyEvent = true;
                    activity.LatestEventAt = evt.Value.Timestamp;
                    activity.LatestEventType = evt.Value.EventType;
                    activity.Title ??= evt.Value.TitleCandidate;
                    if (evt.Value.ContentText != null)
                        activity.LastAnswer = evt.Value.ContentText;

                    switch (evt.Value.TurnState)
                    {
                        case TurnState.Started:
                            activity.LastTaskStartedAt = evt.Value.Timestamp;
                            break;
                        case TurnState.Completed:
                            activity.LastTaskCompletedAt = evt.Value.Timestamp;
                            break;
                    }
                }

                return activity.SawAnyEvent ? activity : null;
            }
            catch
            {
                return null;
            }
        }

        private (DateTime Timestamp, string EventType, string? TitleCandidate, string? ContentText,
            TurnState TurnState)? ParseEvent(string line)
        {
            try
            {
                using var doc = JsonDocument.Parse(line);
                var root = doc.RootElement;

                if (!root.TryGetProperty("timestamp", out var tsEl) ||
                    tsEl.ValueKind != JsonValueKind.String)
                    return null;
                if (!TryParseTimestamp(tsEl.GetString()!, out var timestamp))
                    return null;
                if (!root.TryGetProperty("type", out var typeEl) ||
                    typeEl.ValueKind != JsonValueKind.String)
                    return null;

                var topLevelType = typeEl.GetString()!;

                JsonElement? message = root.TryGetProperty("message", out var msg) &&
                    msg.ValueKind == JsonValueKind.Object ? msg : null;

                var role = message?.TryGetProperty("role", out var r) == true &&
                    r.ValueKind == JsonValueKind.String ? r.GetString() : null;
                var stopReason = message?.TryGetProperty("stop_reason", out var sr) == true &&
                    sr.ValueKind == JsonValueKind.String ? sr.GetString() : null;

                var titleCandidate = SessionTitleNormalizer.ExplicitTitleIn(root)
                    ?? UserTitleCandidate(topLevelType, message);

                string? contentText = topLevelType == "assistant"
                    ? SessionTitleNormalizer.TitleFromContent(
                        message?.TryGetProperty("content", out var c) == true ? c : null, 200)
                    : null;

                return topLevelType switch
                {
                    "user" => (timestamp, "user", titleCandidate, null, TurnState.Started),
                    "assistant" when stopReason == "end_turn" =>
                        (timestamp, "assistant:end_turn", titleCandidate, contentText, TurnState.Completed),
                    "assistant" =>
                        (timestamp, $"assistant:{stopReason ?? role ?? "assistant"}", titleCandidate,
                         contentText, TurnState.Started),
                    _ => (timestamp, topLevelType, titleCandidate, null, TurnState.Ignored)
                };
            }
            catch
            {
                return null;
            }
        }

        private static string? UserTitleCandidate(string topLevelType, JsonElement? message)
        {
            if (topLevelType != "user" && (message?.TryGetProperty("role", out var r) != true ||
                r.ValueKind != JsonValueKind.String || r.GetString() != "user"))
                return null;

            if (message?.TryGetProperty("content", out var content) == true)
                return SessionTitleNormalizer.TitleFromContent(content);
            return null;
        }

        private static bool TryParseTimestamp(string text, out DateTime result)
        {
            if (DateTime.TryParseExact(text, IsoFormats,
                    System.Globalization.CultureInfo.InvariantCulture,
                    System.Globalization.DateTimeStyles.AssumeUniversal |
                    System.Globalization.DateTimeStyles.AdjustToUniversal,
                    out result))
                return true;

            if (DateTime.TryParse(text, null,
                    System.Globalization.DateTimeStyles.RoundtripKind, out result))
            {
                result = result.ToUniversalTime();
                return true;
            }

            return false;
        }
    }
}
