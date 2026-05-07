import Foundation

public struct EmailNotificationConfig: Equatable {
    public let smtpURL: String
    public let username: String?
    public let password: String?
    public let passwordCommand: String?
    public let from: String
    public let to: [String]
    public let subject: String
    public let requiresTLS: Bool
    public let curlPath: String
    public let timeoutSeconds: TimeInterval

    public init(
        smtpURL: String,
        username: String? = nil,
        password: String? = nil,
        passwordCommand: String? = nil,
        from: String,
        to: [String],
        subject: String = "oneMenu: all AI work finished",
        requiresTLS: Bool = true,
        curlPath: String = "/usr/bin/curl",
        timeoutSeconds: TimeInterval = 60
    ) {
        self.smtpURL = smtpURL
        self.username = username
        self.password = password
        self.passwordCommand = passwordCommand
        self.from = from
        self.to = to
        self.subject = subject
        self.requiresTLS = requiresTLS
        self.curlPath = curlPath
        self.timeoutSeconds = timeoutSeconds
    }
}

public enum EmailNotificationConfigLoader {
    public static let configPathEnvironmentKey = "AISTATUS_EMAIL_CONFIG"
    public static let passwordEnvironmentKey = "AISTATUS_EMAIL_PASSWORD"
    public static let passwordCommandEnvironmentKey = "AISTATUS_EMAIL_PASSWORD_COMMAND"

    public static func defaultConfigURL(
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
    ) -> URL {
        homeDirectory
            .appendingPathComponent(".aistatus", isDirectory: true)
            .appendingPathComponent("email.json")
    }

    public static func load(
        fileURL: URL? = nil,
        environment: [String: String] = ProcessInfo.processInfo.environment,
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser,
        fileManager: FileManager = .default
    ) throws -> EmailNotificationConfig? {
        let explicitConfigURL = fileURL
            ?? environment[configPathEnvironmentKey].flatMap { expandedFileURL(from: $0, homeDirectory: homeDirectory) }
        let configURL = explicitConfigURL ?? defaultConfigURL(homeDirectory: homeDirectory)

        guard fileManager.fileExists(atPath: configURL.path) else {
            if explicitConfigURL != nil {
                throw EmailNotificationConfigError.configFileNotFound(configURL.path)
            }
            return nil
        }

        let data = try Data(contentsOf: configURL)
        let config = try JSONDecoder().decode(RawEmailNotificationConfig.self, from: data).resolved()

        guard config.isEnabled else {
            return nil
        }

        let password = environment[passwordEnvironmentKey].flatMap(normalizedNonEmpty)
        let passwordCommand = environment[passwordCommandEnvironmentKey].flatMap(normalizedNonEmpty)
        return try config.toPublicConfig(password: password, passwordCommand: passwordCommand)
    }

    private static func expandedFileURL(from path: String, homeDirectory: URL) -> URL? {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return nil
        }

        if trimmed == "~" {
            return homeDirectory
        }

        if trimmed.hasPrefix("~/") {
            return homeDirectory.appendingPathComponent(String(trimmed.dropFirst(2)))
        }

        return URL(fileURLWithPath: trimmed)
    }

    private static func normalizedNonEmpty(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

private struct RawEmailNotificationConfig: Decodable {
    var enabled: Bool?
    var smtpURL: String?
    var username: String?
    var password: String?
    var passwordCommand: String?
    var from: String?
    var to: OneOrManyStrings?
    var subject: String?
    var requiresTLS: Bool?
    var curlPath: String?
    var timeoutSeconds: TimeInterval?

    func resolved() -> ResolvedEmailNotificationConfig {
        ResolvedEmailNotificationConfig(
            isEnabled: enabled ?? true,
            smtpURL: smtpURL,
            username: username,
            password: password,
            passwordCommand: passwordCommand,
            from: from,
            to: to?.values ?? [],
            subject: subject ?? "oneMenu: all AI work finished",
            requiresTLS: requiresTLS ?? true,
            curlPath: curlPath ?? "/usr/bin/curl",
            timeoutSeconds: timeoutSeconds ?? 60
        )
    }
}

private struct ResolvedEmailNotificationConfig {
    var isEnabled: Bool
    var smtpURL: String?
    var username: String?
    var password: String?
    var passwordCommand: String?
    var from: String?
    var to: [String]
    var subject: String
    var requiresTLS: Bool
    var curlPath: String
    var timeoutSeconds: TimeInterval

    func toPublicConfig(password passwordOverride: String?, passwordCommand commandOverride: String?) throws -> EmailNotificationConfig {
        let smtpURL = try required(smtpURL, field: "smtpURL")
        try validateSMTPURL(smtpURL)

        let recipients = to
            .compactMap(Self.normalizedNonEmpty)
        guard !recipients.isEmpty else {
            throw EmailNotificationConfigError.missingRequiredField("to")
        }

        return EmailNotificationConfig(
            smtpURL: smtpURL,
            username: Self.normalizedNonEmpty(username),
            password: passwordOverride ?? Self.normalizedNonEmpty(password),
            passwordCommand: commandOverride ?? Self.normalizedNonEmpty(passwordCommand),
            from: try required(from, field: "from"),
            to: recipients,
            subject: try required(subject, field: "subject"),
            requiresTLS: requiresTLS,
            curlPath: try required(curlPath, field: "curlPath"),
            timeoutSeconds: max(1, timeoutSeconds)
        )
    }

    private func required(_ value: String?, field: String) throws -> String {
        guard let normalized = Self.normalizedNonEmpty(value) else {
            throw EmailNotificationConfigError.missingRequiredField(field)
        }

        return normalized
    }

    private func validateSMTPURL(_ value: String) throws {
        guard let components = URLComponents(string: value),
              let scheme = components.scheme?.lowercased(),
              ["smtp", "smtps"].contains(scheme),
              components.host != nil
        else {
            throw EmailNotificationConfigError.invalidSMTPURL(value)
        }
    }

    private static func normalizedNonEmpty(_ value: String?) -> String? {
        guard let value else {
            return nil
        }

        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

private struct OneOrManyStrings: Decodable {
    let values: [String]

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let singleValue = try? container.decode(String.self) {
            values = [singleValue]
            return
        }

        values = try container.decode([String].self)
    }
}

public enum EmailNotificationConfigError: Error, LocalizedError, Equatable {
    case configFileNotFound(String)
    case missingRequiredField(String)
    case invalidSMTPURL(String)

    public var errorDescription: String? {
        switch self {
        case let .configFileNotFound(path):
            return "邮件配置文件不存在：\(path)"
        case let .missingRequiredField(field):
            return "邮件配置缺少必填字段：\(field)"
        case let .invalidSMTPURL(value):
            return "邮件配置 smtpURL 无效：\(value)"
        }
    }
}
