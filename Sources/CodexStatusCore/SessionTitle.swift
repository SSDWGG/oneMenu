import Foundation

public struct StatusSessionSummary: Equatable, Hashable {
    public let id: String
    public let title: String
    public let lastAnswer: String?

    public init(id: String, title: String, lastAnswer: String? = nil) {
        self.id = id
        self.title = title
        self.lastAnswer = lastAnswer
    }
}

enum SessionTitleNormalizer {
    static func title(from text: String?, maxLength: Int = 80) -> String? {
        guard let text else {
            return nil
        }

        let markedText = textAfterRequestMarker(in: text) ?? text
        let filteredText = markedText
            .components(separatedBy: .newlines)
            .filter { !isAuxiliaryLine($0) }
            .joined(separator: " ")
        let normalized = filteredText
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !normalized.isEmpty else {
            return nil
        }

        if normalized.count <= maxLength {
            return normalized
        }

        return String(normalized.prefix(maxLength - 3)).trimmingCharacters(in: .whitespacesAndNewlines) + "..."
    }

    static func title(fromContent content: Any?, maxLength: Int = 80) -> String? {
        if let text = content as? String {
            return title(from: text, maxLength: maxLength)
        }

        if let parts = content as? [[String: Any]] {
            for part in parts {
                if let title = title(from: part["text"] as? String, maxLength: maxLength) {
                    return title
                }
            }
        }

        return nil
    }

    static func explicitTitle(in object: [String: Any]) -> String? {
        if let title = explicitTitleShallow(in: object) {
            return title
        }

        for key in ["payload", "message", "session"] {
            if let nested = object[key] as? [String: Any],
               let title = explicitTitleShallow(in: nested) {
                return title
            }
        }

        return nil
    }

    static func displayTitle(_ candidate: String?) -> String {
        title(from: candidate) ?? "未命名会话"
    }

    private static func explicitTitleShallow(in object: [String: Any]) -> String? {
        for key in ["thread_name", "title", "name", "summary"] {
            if let title = title(from: object[key] as? String) {
                return title
            }
        }

        return nil
    }

    private static func textAfterRequestMarker(in text: String) -> String? {
        let markers = [
            "## My request for Codex:",
            "## My request for Claude:",
            "## My request:",
            "My request for Codex:",
            "My request for Claude:",
            "My request:"
        ]

        for marker in markers {
            if let range = text.range(of: marker, options: [.caseInsensitive]) {
                return String(text[range.upperBound...])
            }
        }

        return nil
    }

    private static func isAuxiliaryLine(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.hasPrefix("<ide_")
            || trimmed.hasPrefix("</ide_")
            || trimmed.hasPrefix("<environment_context>")
            || trimmed.hasPrefix("</environment_context>")
            || trimmed.hasPrefix("<INSTRUCTIONS>")
            || trimmed.hasPrefix("</INSTRUCTIONS>")
            || trimmed.hasPrefix("<skills_instructions>")
            || trimmed.hasPrefix("<plugins_instructions>")
            || trimmed.hasPrefix("# AGENTS.md instructions")
    }
}
