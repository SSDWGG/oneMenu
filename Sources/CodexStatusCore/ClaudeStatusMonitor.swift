import Foundation

public enum ClaudeState: String, Equatable {
    case idle
    case thinking
}

public struct ClaudeStatusSnapshot: Equatable {
    public let state: ClaudeState
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
    public let claudeHome: URL
    public let errorMessage: String?

    public var isThinking: Bool {
        state == .thinking
    }
}

public final class ClaudeStatusMonitor {
    public let claudeHome: URL
    public let staleAfter: TimeInterval

    private let projectsDirectory: URL
    private let fileManager: FileManager
    private let parser: ClaudeSessionActivityParser
    private let scanLimit: Int

    public init(
        claudeHome: URL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".claude"),
        staleAfter: TimeInterval = 30 * 60,
        scanLimit: Int = 100,
        fileManager: FileManager = .default
    ) {
        self.claudeHome = claudeHome
        self.staleAfter = staleAfter
        self.scanLimit = scanLimit
        self.fileManager = fileManager
        self.projectsDirectory = claudeHome.appendingPathComponent("projects", isDirectory: true)
        self.parser = ClaudeSessionActivityParser()
    }

    public func snapshot(at now: Date = Date()) -> ClaudeStatusSnapshot {
        guard fileManager.fileExists(atPath: projectsDirectory.path) else {
            return ClaudeStatusSnapshot(
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
                claudeHome: claudeHome,
                errorMessage: "没有找到 Claude projects 目录"
            )
        }

        do {
            let files = try recentProjectFiles(limit: scanLimit)
            var latestActivity: ClaudeSessionActivity?
            var activeActivities: [ClaudeSessionActivity] = []
            var idleActivities: [ClaudeSessionActivity] = []

            for file in files {
                guard let activity = try parser.parse(url: file.url, modifiedAt: file.modifiedAt) else {
                    continue
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

            return ClaudeStatusSnapshot(
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
                claudeHome: claudeHome,
                errorMessage: nil
            )
        } catch {
            return ClaudeStatusSnapshot(
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
                claudeHome: claudeHome,
                errorMessage: error.localizedDescription
            )
        }
    }

    private func recentProjectFiles(limit: Int) throws -> [ClaudeProjectFile] {
        let resourceKeys: Set<URLResourceKey> = [.isRegularFileKey, .contentModificationDateKey]
        guard let enumerator = fileManager.enumerator(
            at: projectsDirectory,
            includingPropertiesForKeys: Array(resourceKeys),
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return []
        }

        var files: [ClaudeProjectFile] = []
        for case let url as URL in enumerator where url.pathExtension == "jsonl" {
            let values = try? url.resourceValues(forKeys: resourceKeys)
            guard values?.isRegularFile == true, let modifiedAt = values?.contentModificationDate else {
                continue
            }
            files.append(ClaudeProjectFile(url: url, modifiedAt: modifiedAt))
        }

        return Array(files.sorted { $0.modifiedAt > $1.modifiedAt }.prefix(limit))
    }

    private func isFresh(_ activity: ClaudeSessionActivity, now: Date) -> Bool {
        let freshnessDate = max(activity.latestEventAt ?? activity.modifiedAt, activity.modifiedAt)
        return now.timeIntervalSince(freshnessDate) <= staleAfter
    }

    private func isNewer(_ activity: ClaudeSessionActivity, than other: ClaudeSessionActivity?) -> Bool {
        guard let other else {
            return true
        }
        return (activity.latestEventAt ?? activity.modifiedAt) > (other.latestEventAt ?? other.modifiedAt)
    }

    private func newestActivity(in activities: [ClaudeSessionActivity]) -> ClaudeSessionActivity? {
        activities.max { lhs, rhs in
            (lhs.latestEventAt ?? lhs.modifiedAt) < (rhs.latestEventAt ?? rhs.modifiedAt)
        }
    }

    private func sessionSummaries(from activities: [ClaudeSessionActivity]) -> [StatusSessionSummary] {
        activities
            .sorted {
                ($0.latestEventAt ?? $0.modifiedAt) > ($1.latestEventAt ?? $1.modifiedAt)
            }
            .map { activity in
                StatusSessionSummary(
                    id: activity.fileURL.path,
                    title: sessionTitle(for: activity),
                    lastAnswer: activity.lastAnswer
                )
            }
    }

    private func sessionTitle(for activity: ClaudeSessionActivity) -> String {
        SessionTitleNormalizer.displayTitle(activity.title)
    }
}

private struct ClaudeProjectFile {
    let url: URL
    let modifiedAt: Date
}

struct ClaudeSessionActivity {
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

        return lastTaskStartedAt != nil
    }
}

final class ClaudeSessionActivityParser {
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

    func parse(url: URL, modifiedAt: Date) throws -> ClaudeSessionActivity? {
        let text = try tailText(from: url)
        var activity = ClaudeSessionActivity(fileURL: url, modifiedAt: modifiedAt)

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

            switch event.turnState {
            case .started:
                activity.lastTaskStartedAt = event.timestamp
            case .completed:
                activity.lastTaskCompletedAt = event.timestamp
            case .ignored:
                break
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

    private func parseEvent(from line: String) -> ParsedClaudeEvent? {
        guard let data = line.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let timestampText = object["timestamp"] as? String,
              let timestamp = parseTimestamp(timestampText),
              let topLevelType = object["type"] as? String
        else {
            return nil
        }

        let message = object["message"] as? [String: Any]
        let role = message?["role"] as? String
        let stopReason = message?["stop_reason"] as? String
        let titleCandidate = SessionTitleNormalizer.explicitTitle(in: object)
            ?? userTitleCandidate(topLevelType: topLevelType, message: message)
        let contentText = topLevelType == "assistant"
            ? SessionTitleNormalizer.title(fromContent: message?["content"], maxLength: 200)
            : nil

        switch topLevelType {
        case "user":
            return ParsedClaudeEvent(
                timestamp: timestamp,
                eventType: "user",
                contentText: nil,
                turnState: .started,
                titleCandidate: titleCandidate
            )
        case "assistant":
            if stopReason == "end_turn" {
                return ParsedClaudeEvent(
                    timestamp: timestamp,
                    eventType: "assistant:end_turn",
                    contentText: contentText,
                    turnState: .completed,
                    titleCandidate: titleCandidate
                )
            }

            let suffix = stopReason ?? role ?? "assistant"
            return ParsedClaudeEvent(
                timestamp: timestamp,
                eventType: "assistant:\(suffix)",
                contentText: contentText,
                turnState: .started,
                titleCandidate: titleCandidate
            )
        default:
            return ParsedClaudeEvent(
                timestamp: timestamp,
                eventType: topLevelType,
                contentText: nil,
                turnState: .ignored,
                titleCandidate: titleCandidate
            )
        }
    }

    private func parseTimestamp(_ timestamp: String) -> Date? {
        isoWithFractionalSeconds.date(from: timestamp) ?? isoWithoutFractionalSeconds.date(from: timestamp)
    }

    private func userTitleCandidate(topLevelType: String, message: [String: Any]?) -> String? {
        guard topLevelType == "user" || message?["role"] as? String == "user" else {
            return nil
        }

        return SessionTitleNormalizer.title(fromContent: message?["content"])
    }
}

private enum ClaudeTurnState {
    case started
    case completed
    case ignored
}

private struct ParsedClaudeEvent {
    let timestamp: Date
    let eventType: String
    let contentText: String?
    let turnState: ClaudeTurnState
    let titleCandidate: String?
}
