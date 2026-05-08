import Foundation

public struct EmailMessage: Equatable {
    public let from: String
    public let to: [String]
    public let subject: String
    public let body: String
    public let date: Date
    public let isHTML: Bool

    public init(
        from: String,
        to: [String],
        subject: String,
        body: String,
        date: Date = Date(),
        isHTML: Bool = false
    ) {
        self.from = from
        self.to = to
        self.subject = subject
        self.body = body
        self.date = date
        self.isHTML = isHTML
    }

    public func rfc5322Data(messageID: String = "<\(UUID().uuidString)@onemenu.local>") -> Data {
        let contentType = isHTML
            ? "Content-Type: text/html; charset=utf-8"
            : "Content-Type: text/plain; charset=utf-8"
        let headers = [
            "From: \(from)",
            "To: \(to.joined(separator: ", "))",
            "Subject: \(Self.encodedHeader(subject))",
            "Date: \(Self.rfc5322DateFormatter.string(from: date))",
            "Message-ID: \(messageID)",
            "MIME-Version: 1.0",
            contentType,
            "Content-Transfer-Encoding: 8bit"
        ]

        return (headers.joined(separator: "\r\n") + "\r\n\r\n" + body + "\r\n")
            .data(using: .utf8) ?? Data()
    }

    private static let rfc5322DateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"
        return formatter
    }()

    private static func encodedHeader(_ value: String) -> String {
        let canUsePlainHeader = value.unicodeScalars.allSatisfy { scalar in
            scalar.isASCII && scalar.value >= 32 && scalar.value != 127
        }

        guard !canUsePlainHeader,
              let data = value.data(using: .utf8)
        else {
            return value
        }

        return "=?UTF-8?B?\(data.base64EncodedString())?="
    }
}

public final class SMTPEmailSender {
    private let config: EmailNotificationConfig
    private let fileManager: FileManager

    public init(
        config: EmailNotificationConfig,
        fileManager: FileManager = .default
    ) {
        self.config = config
        self.fileManager = fileManager
    }

    public func send(message: EmailMessage) throws {
        let tempDirectory = fileManager.temporaryDirectory
            .appendingPathComponent("oneMenuEmail-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(
            at: tempDirectory,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        defer {
            try? fileManager.removeItem(at: tempDirectory)
        }

        let messageURL = tempDirectory.appendingPathComponent("message.eml")
        let curlConfigURL = tempDirectory.appendingPathComponent("curl.conf")
        try message.rfc5322Data().write(to: messageURL, options: .atomic)
        try fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: messageURL.path)

        let curlConfig = try curlConfiguration(uploadFile: messageURL)
        try curlConfig.write(to: curlConfigURL, atomically: true, encoding: .utf8)
        try fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: curlConfigURL.path)

        try runCurl(configURL: curlConfigURL)
    }

    private func curlConfiguration(uploadFile: URL) throws -> String {
        var lines = [
            "silent",
            "show-error",
            configLine("url", config.smtpURL),
            configLine("mail-from", config.from),
            configLine("upload-file", uploadFile.path),
            configLine("connect-timeout", "20"),
            configLine("max-time", String(Int(config.timeoutSeconds.rounded(.up))))
        ]

        for recipient in config.to {
            lines.append(configLine("mail-rcpt", recipient))
        }

        if let username = config.username {
            let password = try resolvedPassword()
            lines.append(configLine("user", "\(username):\(password)"))
            lines.append(configLine("login-options", "AUTH=LOGIN"))
        }

        if config.requiresTLS {
            lines.append("ssl-reqd")
        }

        return lines.joined(separator: "\n").appending("\n")
    }

    private func resolvedPassword() throws -> String {
        if let password = config.password {
            return password
        }

        if let passwordCommand = config.passwordCommand {
            return try runPasswordCommand(passwordCommand)
        }

        return ""
    }

    private func runPasswordCommand(_ command: String) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-lc", command]

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        try process.run()
        process.waitUntilExit()

        let output = String(data: outputPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let errorOutput = String(data: errorPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        guard process.terminationStatus == 0 else {
            throw SMTPEmailSenderError.passwordCommandFailed(errorOutput.trimmingCharacters(in: .whitespacesAndNewlines))
        }

        let password = output.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !password.isEmpty else {
            throw SMTPEmailSenderError.emptyPasswordCommandOutput
        }

        return password
    }

    private func runCurl(configURL: URL) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: config.curlPath)
        process.arguments = ["--config", configURL.path]

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        try process.run()
        process.waitUntilExit()

        let output = String(data: outputPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let errorOutput = String(data: errorPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        guard process.terminationStatus == 0 else {
            let detail = [errorOutput, output]
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .joined(separator: "\n")
            throw SMTPEmailSenderError.curlFailed(status: process.terminationStatus, detail: detail)
        }
    }

    private func configLine(_ key: String, _ value: String) -> String {
        "\(key) = \"\(escapedCurlConfigValue(value))\""
    }

    private func escapedCurlConfigValue(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\r", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
    }
}

public enum SMTPEmailSenderError: Error, LocalizedError, Equatable {
    case passwordCommandFailed(String)
    case emptyPasswordCommandOutput
    case curlFailed(status: Int32, detail: String)

    public var errorDescription: String? {
        switch self {
        case let .passwordCommandFailed(detail):
            return detail.isEmpty ? "邮件密码命令执行失败" : "邮件密码命令执行失败：\(detail)"
        case .emptyPasswordCommandOutput:
            return "邮件密码命令没有输出密码"
        case let .curlFailed(status, detail):
            let reason = Self.curlExitCodeDescription(status)
            if detail.isEmpty {
                return "邮件发送失败 — \(reason)"
            }
            return "邮件发送失败 — \(reason)（\(detail)）"
        }
    }

    private static func curlExitCodeDescription(_ code: Int32) -> String {
        switch code {
        case 1: return "不支持的协议"
        case 5: return "无法解析代理主机"
        case 6: return "无法解析主机名，请检查 SMTP 地址"
        case 7: return "无法连接到 SMTP 服务器，请检查地址和端口"
        case 28: return "连接超时，请检查 SMTP 地址和网络"
        case 35: return "TLS 握手失败，请检查 TLS 设置"
        case 51: return "服务器不支持 STARTTLS"
        case 55: return "发送数据失败，网络异常"
        case 60: return "SSL 证书验证失败"
        case 67: return "登录被拒绝，请检查授权码是否正确、SMTP 服务是否已开启"
        default: return "curl 退出码 \(code)"
        }
    }
}
