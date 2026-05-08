using System.Text.Json;
using System.Text.RegularExpressions;
using OneMenu.Core.Infrastructure;
using OneMenu.Core.Models;

namespace OneMenu.Core.Monitors;

public partial class CodexStatusMonitor
{
    private readonly string _codexHome;
    private readonly TimeSpan _staleAfter;
    private readonly string _sessionsDirectory;
    private readonly string _titleIndexPath;
    private readonly int _scanLimit;
    private readonly JsonlFileReader _reader;
    private readonly JsonParser _parser;

    public string CodexHome => _codexHome;

    public CodexStatusMonitor(
        string? codexHome = null,
        TimeSpan? staleAfter = null,
        int scanLimit = 100)
    {
        _codexHome = codexHome
            ?? Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.UserProfile), ".codex");
        _staleAfter = staleAfter ?? TimeSpan.FromMinutes(30);
        _scanLimit = scanLimit;
        _sessionsDirectory = Path.Combine(_codexHome, "sessions");
        _titleIndexPath = Path.Combine(_codexHome, "session_index.jsonl");
        _reader = new JsonlFileReader();
        _parser = new JsonParser();
    }

    public CodexStatusSnapshot Snapshot(DateTime? now = null)
    {
        var nowValue = now ?? DateTime.UtcNow;

        if (!Directory.Exists(_sessionsDirectory))
        {
            return CodexStatusSnapshot.Empty(_staleAfter, _codexHome, "没有找到 Codex sessions 目录");
        }

        try
        {
            var files = RecentSessionFiles(_scanLimit);
            var titleIndex = LoadTitleIndex();
            SessionActivity? latestActivity = null;
            var activeActivities = new List<SessionActivity>();
            var idleActivities = new List<SessionActivity>();

            foreach (var file in files)
            {
                var activity = _parser.Parse(file.path, file.modifiedAt);
                if (activity == null) continue;

                if (TryExtractSessionId(file.path, out var sessionId))
                {
                    if (titleIndex.TryGetValue(sessionId, out var indexedTitle))
                        activity.Title = indexedTitle;
                }

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

            return new CodexStatusSnapshot(
                State: activeActivities.Count == 0 ? CodexState.Idle : CodexState.Thinking,
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
                CodexHome: _codexHome,
                ErrorMessage: null);
        }
        catch (Exception ex)
        {
            return CodexStatusSnapshot.Empty(_staleAfter, _codexHome, ex.Message);
        }
    }

    private List<(string path, DateTime modifiedAt)> RecentSessionFiles(int limit)
    {
        var files = new List<(string path, DateTime modifiedAt)>();

        try
        {
            foreach (var filePath in Directory.EnumerateFiles(_sessionsDirectory, "*.jsonl",
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

    private Dictionary<string, string> LoadTitleIndex()
    {
        var result = new Dictionary<string, string>();
        if (!File.Exists(_titleIndexPath)) return result;

        try
        {
            foreach (var line in File.ReadLines(_titleIndexPath))
            {
                if (string.IsNullOrWhiteSpace(line)) continue;
                try
                {
                    using var doc = JsonDocument.Parse(line);
                    var root = doc.RootElement;
                    if (root.TryGetProperty("id", out var idEl) &&
                        idEl.ValueKind == JsonValueKind.String)
                    {
                        var title = SessionTitleNormalizer.ExplicitTitleIn(root);
                        if (title != null)
                            result[idEl.GetString()!] = title;
                    }
                }
                catch
                {
                    // skip malformed lines
                }
            }
        }
        catch
        {
            // file read failed
        }

        return result;
    }

    private bool IsFresh(SessionActivity activity, DateTime now)
    {
        var freshnessDate = Max(activity.LatestEventAt ?? activity.ModifiedAt, activity.ModifiedAt);
        return (now - freshnessDate) <= _staleAfter;
    }

    private static bool IsNewer(SessionActivity activity, SessionActivity? other)
    {
        if (other == null) return true;
        return (activity.LatestEventAt ?? activity.ModifiedAt) >
               (other.LatestEventAt ?? other.ModifiedAt);
    }

    private static SessionActivity? NewestActivity(List<SessionActivity> activities)
    {
        return activities.MaxBy(a => a.LatestEventAt ?? a.ModifiedAt);
    }

    private static List<StatusSessionSummary> SessionSummaries(List<SessionActivity> activities)
    {
        return activities
            .OrderByDescending(a => a.LatestEventAt ?? a.ModifiedAt)
            .Select(a => new StatusSessionSummary(
                Id: SessionIdentifierFor(a),
                Title: SessionTitle(a),
                LastAnswer: a.LastAnswer))
            .ToList();
    }

    private static string SessionTitle(SessionActivity activity) =>
        SessionTitleNormalizer.DisplayTitle(activity.Title);

    private static string SessionIdentifierFor(SessionActivity activity) =>
        TryExtractSessionId(activity.FilePath, out var id) ? id : activity.FilePath;

    private static bool TryExtractSessionId(string filePath, out string sessionId)
    {
        sessionId = "";
        var baseName = Path.GetFileNameWithoutExtension(filePath);
        if (baseName.Length < 36) return false;

        var suffix = baseName[^36..];
        if (UuidRegex().IsMatch(suffix))
        {
            sessionId = suffix;
            return true;
        }
        return false;
    }

    private static DateTime Max(DateTime a, DateTime b) => a > b ? a : b;

    [GeneratedRegex(@"^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$")]
    private static partial Regex UuidRegex();

    /// <summary>
    /// JSONL event parser for Codex session files.
    /// </summary>
    private class JsonParser
    {
        private static readonly string[] IsoFormats =
        {
            "yyyy-MM-dd'T'HH:mm:ss.FFFFFFF'Z'",
            "yyyy-MM-dd'T'HH:mm:ss.FFFFFFFzzz",
            "yyyy-MM-dd'T'HH:mm:ss'Z'",
            "yyyy-MM-dd'T'HH:mm:sszzz"
        };

        public SessionActivity? Parse(string filePath, DateTime modifiedAt)
        {
            try
            {
                var text = new JsonlFileReader().ReadTail(filePath);
                var activity = new SessionActivity
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

                    if (evt.Value.TopLevelType == "event_msg")
                    {
                        switch (evt.Value.EventType)
                        {
                            case "task_started":
                                activity.LastTaskStartedAt = evt.Value.Timestamp;
                                break;
                            case "task_complete":
                                activity.LastTaskCompletedAt = evt.Value.Timestamp;
                                break;
                        }
                    }
                }

                return activity.SawAnyEvent ? activity : null;
            }
            catch
            {
                return null;
            }
        }

        private (DateTime Timestamp, string TopLevelType, string EventType, string? TitleCandidate,
            string? ContentText)? ParseEvent(string line)
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
                JsonElement? payload = root.TryGetProperty("payload", out var pl) &&
                    pl.ValueKind == JsonValueKind.Object ? pl : null;
                var eventType = (payload?.TryGetProperty("type", out var et) == true &&
                    et.ValueKind == JsonValueKind.String) ? et.GetString()! : topLevelType;

                var titleCandidate = SessionTitleNormalizer.ExplicitTitleIn(root)
                    ?? UserTitleCandidate(payload);

                string? contentText = ExtractContentText(topLevelType, payload, root);

                return (timestamp, topLevelType, eventType, titleCandidate, contentText);
            }
            catch
            {
                return null;
            }
        }

        private static string? ExtractContentText(string topLevelType, JsonElement? payload, JsonElement root)
        {
            if (topLevelType != "assistant")
                return null;

            JsonElement? message = root.TryGetProperty("message", out var msg) &&
                msg.ValueKind == JsonValueKind.Object ? msg : null;

            JsonElement? content = message?.TryGetProperty("content", out var mc) == true
                ? mc : payload?.TryGetProperty("content", out var pc) == true
                    ? pc : null;

            if (content == null) return null;
            return SessionTitleNormalizer.TitleFromContent(content.Value, 200);
        }

        private static string? UserTitleCandidate(JsonElement? payload)
        {
            if (payload == null) return null;
            if (payload.Value.TryGetProperty("role", out var role) &&
                role.ValueKind == JsonValueKind.String &&
                role.GetString() == "user")
            {
                if (payload.Value.TryGetProperty("content", out var content))
                    return SessionTitleNormalizer.TitleFromContent(content);
            }
            return null;
        }

        private static bool TryParseTimestamp(string text, out DateTime result)
        {
            // ISO 8601 with optional fractional seconds and timezone
            if (DateTime.TryParseExact(text, IsoFormats,
                    System.Globalization.CultureInfo.InvariantCulture,
                    System.Globalization.DateTimeStyles.AssumeUniversal |
                    System.Globalization.DateTimeStyles.AdjustToUniversal,
                    out result))
                return true;

            // Fallback to standard .NET ISO parser
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
