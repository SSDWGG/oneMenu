@testable import CodexStatusCore
import XCTest

final class EmailMessageTests: XCTestCase {
    func testBuildsUTF8RFC5322Message() throws {
        let date = ISO8601DateFormatter().date(from: "2026-04-29T03:10:00Z")!
        let message = EmailMessage(
            from: "sender@example.com",
            to: ["recipient@example.com"],
            subject: "所有 AI 工作已结束",
            body: "GPT / Claude 均已空闲",
            date: date
        )

        let text = try XCTUnwrap(String(data: message.rfc5322Data(messageID: "<test@onemenu.local>"), encoding: .utf8))

        XCTAssertTrue(text.contains("From: sender@example.com\r\n"))
        XCTAssertTrue(text.contains("To: recipient@example.com\r\n"))
        XCTAssertTrue(text.contains("Subject: =?UTF-8?B?"))
        XCTAssertTrue(text.contains("Date: Wed, 29 Apr 2026 03:10:00 +0000\r\n"))
        XCTAssertTrue(text.contains("Message-ID: <test@onemenu.local>\r\n"))
        XCTAssertTrue(text.contains("\r\n\r\nGPT / Claude 均已空闲\r\n"))
    }
}
