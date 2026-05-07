using System.Text.RegularExpressions;

namespace OneMenu.Core.Infrastructure;

public static partial class SessionTitleNormalizer
{
    private const int DefaultMaxLength = 80;

    /// <summary>
    /// Normalizes a title from plain text content.
    /// </summary>
    public static string? TitleFrom(string? text, int maxLength = DefaultMaxLength)
    {
        if (string.IsNullOrEmpty(text))
            return null;

        var markedText = TextAfterRequestMarker(text) ?? text;
        var filteredText = string.Join(" ",
            markedText.Split('\n')
                .Where(line => !IsAuxiliaryLine(line)));

        var normalized = WhitespaceRegex().Replace(filteredText, " ").Trim();

        if (normalized.Length == 0)
            return null;

        if (normalized.Length <= maxLength)
            return normalized;

        return (normalized[..(maxLength - 3)].TrimEnd() + "...");
    }

    /// <summary>
    /// Extracts a title from a JSON content object (string or array of parts).
    /// </summary>
    public static string? TitleFromContent(object? content, int maxLength = DefaultMaxLength)
    {
        if (content is string text)
            return TitleFrom(text, maxLength);

        if (content is System.Text.Json.JsonElement element)
        {
            if (element.ValueKind == System.Text.Json.JsonValueKind.String)
                return TitleFrom(element.GetString(), maxLength);

            if (element.ValueKind == System.Text.Json.JsonValueKind.Array)
            {
                foreach (var part in element.EnumerateArray())
                {
                    if (part.TryGetProperty("text", out var textProp) &&
                        textProp.ValueKind == System.Text.Json.JsonValueKind.String)
                    {
                        var title = TitleFrom(textProp.GetString(), maxLength);
                        if (title != null) return title;
                    }
                }
            }
        }

        return null;
    }

    /// <summary>
    /// Searches nested JSON objects for explicit title fields.
    /// </summary>
    public static string? ExplicitTitleIn(System.Text.Json.JsonElement root)
    {
        var title = ExplicitTitleShallow(root);
        if (title != null) return title;

        foreach (var key in new[] { "payload", "message", "session" })
        {
            if (root.TryGetProperty(key, out var nested) &&
                nested.ValueKind == System.Text.Json.JsonValueKind.Object)
            {
                title = ExplicitTitleShallow(nested);
                if (title != null) return title;
            }
        }

        return null;
    }

    public static string DisplayTitle(string? candidate) =>
        TitleFrom(candidate) ?? "未命名会话";

    private static string? ExplicitTitleShallow(System.Text.Json.JsonElement obj)
    {
        foreach (var key in new[] { "thread_name", "title", "name", "summary" })
        {
            if (obj.TryGetProperty(key, out var value) &&
                value.ValueKind == System.Text.Json.JsonValueKind.String)
            {
                var title = TitleFrom(value.GetString());
                if (title != null) return title;
            }
        }
        return null;
    }

    private static string? TextAfterRequestMarker(string text)
    {
        var markers = new[]
        {
            "## My request for Codex:",
            "## My request for Claude:",
            "## My request:",
            "My request for Codex:",
            "My request for Claude:",
            "My request:"
        };

        foreach (var marker in markers)
        {
            var idx = text.IndexOf(marker, StringComparison.OrdinalIgnoreCase);
            if (idx >= 0)
                return text[(idx + marker.Length)..];
        }

        return null;
    }

    private static bool IsAuxiliaryLine(string line)
    {
        var trimmed = line.Trim();
        return trimmed.StartsWith("<ide_")
            || trimmed.StartsWith("</ide_")
            || trimmed.StartsWith("<environment_context>")
            || trimmed.StartsWith("</environment_context>")
            || trimmed.StartsWith("<INSTRUCTIONS>")
            || trimmed.StartsWith("</INSTRUCTIONS>")
            || trimmed.StartsWith("<skills_instructions>")
            || trimmed.StartsWith("<plugins_instructions>")
            || trimmed.StartsWith("# AGENTS.md instructions");
    }

    [GeneratedRegex(@"\s+")]
    private static partial Regex WhitespaceRegex();
}
