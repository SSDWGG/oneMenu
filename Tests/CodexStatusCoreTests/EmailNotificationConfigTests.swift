@testable import CodexStatusCore
import XCTest

final class EmailNotificationConfigTests: XCTestCase {
    func testLoadsConfigFromExplicitPathWithEnvironmentPasswordOverride() throws {
        let root = try makeTemporaryDirectory()
        let configURL = root.appendingPathComponent("email.json")
        try """
        {
          "smtpURL": "smtps://smtp.example.com:465",
          "username": "sender@example.com",
          "password": "file-password",
          "from": "sender@example.com",
          "to": "recipient@example.com",
          "subject": "oneMenu finished"
        }
        """.write(to: configURL, atomically: true, encoding: .utf8)

        let config = try EmailNotificationConfigLoader.load(
            environment: [
                EmailNotificationConfigLoader.configPathEnvironmentKey: configURL.path,
                EmailNotificationConfigLoader.passwordEnvironmentKey: "environment-password"
            ],
            homeDirectory: root
        )

        XCTAssertEqual(config?.smtpURL, "smtps://smtp.example.com:465")
        XCTAssertEqual(config?.username, "sender@example.com")
        XCTAssertEqual(config?.password, "environment-password")
        XCTAssertEqual(config?.from, "sender@example.com")
        XCTAssertEqual(config?.to, ["recipient@example.com"])
        XCTAssertEqual(config?.subject, "oneMenu finished")
        XCTAssertEqual(config?.requiresTLS, true)
        XCTAssertEqual(config?.curlPath, "/usr/bin/curl")
    }

    func testDisabledConfigReturnsNil() throws {
        let root = try makeTemporaryDirectory()
        let configURL = root.appendingPathComponent("email.json")
        try """
        {
          "enabled": false,
          "smtpURL": "smtps://smtp.example.com:465",
          "from": "sender@example.com",
          "to": ["recipient@example.com"]
        }
        """.write(to: configURL, atomically: true, encoding: .utf8)

        let config = try EmailNotificationConfigLoader.load(
            environment: [EmailNotificationConfigLoader.configPathEnvironmentKey: configURL.path],
            homeDirectory: root
        )

        XCTAssertNil(config)
    }

    func testEnabledStatusReadsDisabledConfigWithoutRequiringSMTPFields() throws {
        let root = try makeTemporaryDirectory()
        let configURL = root.appendingPathComponent("email.json")
        try """
        {
          "enabled": false
        }
        """.write(to: configURL, atomically: true, encoding: .utf8)

        let status = try EmailNotificationConfigLoader.enabledStatus(
            environment: [EmailNotificationConfigLoader.configPathEnvironmentKey: configURL.path],
            homeDirectory: root
        )

        XCTAssertEqual(status, .disabled)
    }

    func testEnabledStatusReportsMissingDefaultConfig() throws {
        let root = try makeTemporaryDirectory()

        let status = try EmailNotificationConfigLoader.enabledStatus(
            environment: [:],
            homeDirectory: root
        )

        XCTAssertEqual(status, .notConfigured)
    }

    func testInvalidSMTPURLThrows() throws {
        let root = try makeTemporaryDirectory()
        let configURL = root.appendingPathComponent("email.json")
        try """
        {
          "smtpURL": "https://smtp.example.com",
          "from": "sender@example.com",
          "to": ["recipient@example.com"]
        }
        """.write(to: configURL, atomically: true, encoding: .utf8)

        XCTAssertThrowsError(
            try EmailNotificationConfigLoader.load(
                environment: [EmailNotificationConfigLoader.configPathEnvironmentKey: configURL.path],
                homeDirectory: root
            )
        )
    }

    func testMissingDefaultConfigReturnsNilButExplicitMissingConfigThrows() throws {
        let root = try makeTemporaryDirectory()

        XCTAssertNil(try EmailNotificationConfigLoader.load(environment: [:], homeDirectory: root))
        XCTAssertThrowsError(
            try EmailNotificationConfigLoader.load(
                environment: [
                    EmailNotificationConfigLoader.configPathEnvironmentKey: root.appendingPathComponent("missing.json").path
                ],
                homeDirectory: root
            )
        )
    }

    private func makeTemporaryDirectory() throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: root)
        }
        return root
    }
}
