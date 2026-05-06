import Foundation

public enum CodexState: String, Equatable {
    case idle
    case thinking
}

public struct CodexStatusSnapshot: Equatable {
    public let state: CodexState
    public let activeSessionCount: Int
    public let latestEventAt: Date?
    public let latestEventType: String?
    public let latestSessionFile: URL?
    public let latestSessionTitle: String?
    public let activeSessions: [StatusSessionSummary]
    public let idleSessions: [StatusSessionSummary]
    public let activeSessionTitles: [String]
    public let idleSessionTitles: [String]
    public let scannedFileCount: Int
    public let staleAfter: TimeInterval
    public let codexHome: URL
    public let errorMessage: String?

    public var isThinking: Bool {
        state == .thinking
    }
}

public final class CodexStatusMonitor {
    public let codexHome: URL
    public let staleAfter: TimeInterval

    private let sessionsDirectory: URL
    private let fileManager: FileManager
    private let parser: SessionActivityParser
    private let scanLimit: Int
    private let titleIndexURL: URL

    public init(
        codexHome: URL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".codex"),
        staleAfter: TimeInterval = 30 * 60,
        scanLimit: Int = 100,
        fileManager: FileManager = .default
    ) {
        self.codexHome = codexHome
        self.staleAfter = staleAfter
        self.scanLimit = scanLimit
        self.fileManager = fileManager
        self.sessionsDirectory = codexHome.appendingPathComponent("sessions", isDirectory: true)
        self.parser = SessionActivityParser()
        self.titleIndexURL = codexHome.appendingPathComponent("session_index.jsonl")
    }

    public func snapshot(at now: Date = Date()) -> CodexStatusSnapshot {
        guard fileManager.fileExists(atPath: sessionsDirectory.path) else {
            return CodexStatusSnapshot(
                state: .idle,
                activeSessionCount: 0,
                latestEventAt: nil,
                latestEventType: nil,
                latestSessionFile: nil,
                latestSessionTitle: nil,
                activeSessions: [],
                idleSessions: [],
                activeSessionTitles: [],
                idleSessionTitles: [],
                scannedFileCount: 0,
                staleAfter: staleAfter,
                codexHome: codexHome,
                errorMessage: "没有找到 Codex sessions 目录"
            )
        }

        do {
            let files = try recentSessionFiles(limit: scanLimit)
            let titleIndex = SessionTitleIndex(fileURL: titleIndexURL).load()
            var latestActivity: SessionActivity?
            var activeActivities: [SessionActivity] = []
            var idleActivities: [SessionActivity] = []

            for file in files {
                guard var activity = try parser.parse(url: file.url, modifiedAt: file.modifiedAt) else {
                    continue
                }
                if let sessionID = sessionID(from: activity.fileURL) {
                    activity.title = titleIndex[sessionID] ?? activity.title
                }

                if isNewer(activity, than: latestActivity) {
                    latestActivity = activity
                }

                if activity.isOpenTask, isFresh(activity, now: now) {
                    activeActivities.append(activity)
                } else {
                    idleActivities.append(activity)
                }
            }

            let representative = newestActivity(in: activeActivities) ?? latestActivity
            let activeSessions = sessionSummaries(from: activeActivities)
            let idleSessions = sessionSummaries(from: idleActivities)

            return CodexStatusSnapshot(
                state: activeActivities.isEmpty ? .idle : .thinking,
                activeSessionCount: activeActivities.count,
                latestEventAt: representative?.latestEventAt,
                latestEventType: representative?.latestEventType,
                latestSessionFile: representative?.fileURL,
                latestSessionTitle: representative.map(sessionTitle),
                activeSessions: activeSessions,
                idleSessions: idleSessions,
                activeSessionTitles: activeSessions.map(\.title),
                idleSessionTitles: idleSessions.map(\.title),
                scannedFileCount: files.count,
                staleAfter: staleAfter,
                codexHome: codexHome,
                errorMessage: nil
            )
        } catch {
            return CodexStatusSnapshot(
                state: .idle,
                activeSessionCount: 0,
                latestEventAt: nil,
                latestEventType: nil,
                latestSessionFile: nil,
                latestSessionTitle: nil,
                activeSessions: [],
                idleSessions: [],
                activeSessionTitles: [],
                idleSessionTitles: [],
                scannedFileCount: 0,
                staleAfter: staleAfter,
                codexHome: codexHome,
                errorMessage: error.localizedDescription
            )
        }
    }

    private func recentSessionFiles(limit: Int) throws -> [SessionFile] {
        let resourceKeys: Set<URLResourceKey> = [.isRegularFileKey, .contentModificationDateKey]
        guard let enumerator = fileManager.enumerator(
            at: sessionsDirectory,
            includingPropertiesForKeys: Array(resourceKeys),
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return []
        }

        var files: [SessionFile] = []
        for case let url as URL in enumerator where url.pathExtension == "jsonl" {
            let values = try? url.resourceValues(forKeys: resourceKeys)
            guard values?.isRegularFile == true, let modifiedAt = values?.contentModificationDate else {
                continue
            }
            files.append(SessionFile(url: url, modifiedAt: modifiedAt))
        }

        return Array(files.sorted { $0.modifiedAt > $1.modifiedAt }.prefix(limit))
    }

    private func isFresh(_ activity: SessionActivity, now: Date) -> Bool {
        let freshnessDate = max(activity.latestEventAt ?? activity.modifiedAt, activity.modifiedAt)
        return now.timeIntervalSince(freshnessDate) <= staleAfter
    }

    private func isNewer(_ activity: SessionActivity, than other: SessionActivity?) -> Bool {
        guard let other else {
            return true
        }
        return (activity.latestEventAt ?? activity.modifiedAt) > (other.latestEventAt ?? other.modifiedAt)
    }

    private func newestActivity(in activities: [SessionActivity]) -> SessionActivity? {
        activities.max { lhs, rhs in
            (lhs.latestEventAt ?? lhs.modifiedAt) < (rhs.latestEventAt ?? rhs.modifiedAt)
        }
    }

    private func sessionSummaries(from activities: [SessionActivity]) -> [StatusSessionSummary] {
        activities
            .sorted {
                ($0.latestEventAt ?? $0.modifiedAt) > ($1.latestEventAt ?? $1.modifiedAt)
            }
            .map { activity in
                StatusSessionSummary(
                    id: sessionIdentifier(for: activity),
                    title: sessionTitle(for: activity),
                    lastAnswer: activity.lastAnswer
                )
            }
    }

    private func sessionTitle(for activity: SessionActivity) -> String {
        SessionTitleNormalizer.displayTitle(activity.title)
    }

    private func sessionIdentifier(for activity: SessionActivity) -> String {
        sessionID(from: activity.fileURL) ?? activity.fileURL.path
    }

    private func sessionID(from url: URL) -> String? {
        let baseName = url.deletingPathExtension().lastPathComponent
        guard baseName.count >= 36 else {
            return nil
        }

        let suffix = String(baseName.suffix(36))
        let uuidPattern = #"^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$"#
        return suffix.range(of: uuidPattern, options: .regularExpression) == nil ? nil : suffix
    }
}

private struct SessionFile {
    let url: URL
    let modifiedAt: Date
}

private struct SessionTitleIndex {
    let fileURL: URL

    func load() -> [String: String] {
        guard let text = try? String(contentsOf: fileURL, encoding: .utf8) else {
            return [:]
        }

        var titlesByID: [String: String] = [:]
        for line in text.split(separator: "\n") {
            guard let data = String(line).data(using: .utf8),
                  let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let id = object["id"] as? String,
                  let title = SessionTitleNormalizer.explicitTitle(in: object)
            else {
                continue
            }

            titlesByID[id] = title
        }

        return titlesByID
    }
}

struct SessionActivity {
    let fileURL: URL
    let modifiedAt: Date
    var title: String?
    var latestEventAt: Date?
    var latestEventType: String?
    var lastTaskStartedAt: Date?
    var lastTaskCompletedAt: Date?
    var lastAnswer: String?
    var sawAnyEvent = false

    var isOpenTask: Bool {
        if let lastTaskStartedAt, let lastTaskCompletedAt {
            return lastTaskStartedAt > lastTaskCompletedAt
        }

        if lastTaskStartedAt != nil {
            return true
        }

        if lastTaskCompletedAt != nil {
            return false
        }

        // A completed Codex task writes task_complete at the end. If a recently
        // modified tail has activity but no completion marker, treat it as open.
        return sawAnyEvent
    }
}

final class SessionActivityParser {
    private let tailByteLimit: UInt64
    private let isoWithFractionalSeconds: ISO8601DateFormatter
    private let isoWithoutFractionalSeconds: ISO8601DateFormatter

    init(tailByteLimit: UInt64 = 512 * 1024) {
        self.tailByteLimit = tailByteLimit
        self.isoWithFractionalSeconds = ISO8601DateFormatter()
        self.isoWithFractionalSeconds.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        self.isoWithoutFractionalSeconds = ISO8601DateFormatter()
        self.isoWithoutFractionalSeconds.formatOptions = [.withInternetDateTime]
    }

    func parse(url: URL, modifiedAt: Date) throws -> SessionActivity? {
        let text = try tailText(from: url)
        var activity = SessionActivity(fileURL: url, modifiedAt: modifiedAt)

        for line in text.split(separator: "\n") {
            guard let event = parseEvent(from: String(line)) else {
                continue
            }

            activity.sawAnyEvent = true
            activity.latestEventAt = event.timestamp
            activity.latestEventType = event.eventType
            if activity.title == nil {
                activity.title = event.titleCandidate
            }
            if let contentText = event.contentText {
                activity.lastAnswer = contentText
            }

            if event.topLevelType == "event_msg" {
                switch event.eventType {
                case "task_started":
                    activity.lastTaskStartedAt = event.timestamp
                case "task_complete":
                    activity.lastTaskCompletedAt = event.timestamp
                default:
                    break
                }
            }
        }

        return activity.sawAnyEvent ? activity : nil
    }

    private func tailText(from url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }

        let fileSize = try handle.seekToEnd()
        let bytesToRead = min(fileSize, tailByteLimit)
        let offset = fileSize - bytesToRead
        try handle.seek(toOffset: offset)

        let data = try handle.readToEnd() ?? Data()
        var text = String(decoding: data, as: UTF8.self)

        if offset > 0, let firstNewline = text.firstIndex(of: "\n") {
            text.removeSubrange(text.startIndex...firstNewline)
        }

        return text
    }

    private func parseEvent(from line: String) -> ParsedSessionEvent? {
        guard let data = line.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let timestampText = object["timestamp"] as? String,
              let timestamp = parseTimestamp(timestampText),
              let topLevelType = object["type"] as? String
        else {
            return nil
        }

        let payload = object["payload"] as? [String: Any]
        let eventType = payload?["type"] as? String ?? topLevelType
        let titleCandidate = SessionTitleNormalizer.explicitTitle(in: object)
            ?? userTitleCandidate(from: payload)
        let contentText = extractContentText(topLevelType: topLevelType, payload: payload, object: object)
        return ParsedSessionEvent(
            timestamp: timestamp,
            topLevelType: topLevelType,
            eventType: eventType,
            titleCandidate: titleCandidate,
            contentText: contentText
        )
    }

    private func extractContentText(topLevelType: String, payload: [String: Any]?, object: [String: Any]) -> String? {
        switch topLevelType {
        case "assistant":
            break
        default:
            return nil
        }

        let message = object["message"] as? [String: Any]
        return SessionTitleNormalizer.title(fromContent: message?["content"] ?? payload?["content"], maxLength: 200)
    }

    private func parseTimestamp(_ timestamp: String) -> Date? {
        isoWithFractionalSeconds.date(from: timestamp) ?? isoWithoutFractionalSeconds.date(from: timestamp)
    }

    private func userTitleCandidate(from payload: [String: Any]?) -> String? {
        guard payload?["role"] as? String == "user" else {
            return nil
        }

        return SessionTitleNormalizer.title(fromContent: payload?["content"])
    }
}

private struct ParsedSessionEvent {
    let timestamp: Date
    let topLevelType: String
    let eventType: String
    let titleCandidate: String?
    let contentText: String?
}
