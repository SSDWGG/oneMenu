import AppKit
import CodexStatusCore
import Foundation
import IOKit.pwr_mgt
import UserNotifications

@main
final class AiStatusApp: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    private let gptMonitor = CodexStatusMonitor()
    private let claudeMonitor = ClaudeStatusMonitor()
    private let colorPreferences = StatusLightColorPreferences()
    private let sleepPreventionPreferences = SleepPreventionPreferences()
    private let sessionNotificationPreferences = SessionNotificationPreferences()
    private let sleepPreventer = SleepPreventer()
    private let allWorkEmailNotifier = AllWorkEmailNotifier()
    private let notificationCenter = UNUserNotificationCenter.current()
    private let statusItem = NSStatusBar.system.statusItem(withLength: 24)
    private let menu = NSMenu()
    private let stateMenuItem = NSMenuItem(title: "状态：检测中", action: nil, keyEquivalent: "")
    private let gptStateMenuItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let claudeStateMenuItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let gptIdleSessionsMenuItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let claudeIdleSessionsMenuItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let gptActiveMenu = NSMenu(title: "GPT 活跃会话")
    private let gptIdleMenu = NSMenu(title: "GPT 闲置会话")
    private let claudeActiveMenu = NSMenu(title: "Claude 活跃会话")
    private let claudeIdleMenu = NSMenu(title: "Claude 闲置会话")
    private let emailStatusMenuItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let errorMenuItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let runningColorMenu = NSMenu(title: "运行时灯颜色")
    private let idleColorMenu = NSMenu(title: "空闲时灯颜色")
    private let preventSleepMenuItem = NSMenuItem(title: "保持 Mac 活跃（防休眠）", action: #selector(toggleSleepPrevention(_:)), keyEquivalent: "")
    private let sessionNotificationMenuItem = NSMenuItem(title: "会话结束通知", action: #selector(toggleSessionNotification(_:)), keyEquivalent: "")
    private var emailConfigWindowController: EmailConfigWindowController?

    private var timer: Timer?
    private var powerAssertionErrorMessage: String?
    private var notificationErrorMessage: String?
    private var emailStatus: EmailStatus = .notConfigured
    private var lastEmailConfigModDate: Date?
    private var activeWorkTransitionTracker = ActiveWorkTransitionTracker()
    private var previousActiveSessionsByID: [String: TrackedSession]?

    static func main() {
        let app = NSApplication.shared
        let delegate = AiStatusApp()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        configureStatusItem()
        configureMenu()
        configureNotifications()
        applySleepPreventionPreference()
        updateSessionNotificationMenuCheck()
        refresh()

        let timer = Timer(timeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.refresh()
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func applicationWillTerminate(_ notification: Notification) {
        timer?.invalidate()
        sleepPreventer.disable()
    }

    private func configureStatusItem() {
        guard let button = statusItem.button else {
            return
        }

        button.imagePosition = .imageOnly
        button.imageScaling = .scaleProportionallyDown
        button.toolTip = "AiStatus"
        statusItem.menu = menu
    }

    private func configureMenu() {
        [stateMenuItem, gptStateMenuItem, claudeStateMenuItem, errorMenuItem, gptIdleSessionsMenuItem, claudeIdleSessionsMenuItem].forEach {
            $0.isEnabled = false
        }

        gptStateMenuItem.submenu = gptActiveMenu
        claudeStateMenuItem.submenu = claudeActiveMenu
        gptIdleSessionsMenuItem.submenu = gptIdleMenu
        claudeIdleSessionsMenuItem.submenu = claudeIdleMenu
        emailStatusMenuItem.isEnabled = false

        menu.addItem(stateMenuItem)
        menu.addItem(.separator())
        menu.addItem(gptStateMenuItem)
        menu.addItem(gptIdleSessionsMenuItem)
        menu.addItem(claudeStateMenuItem)
        menu.addItem(claudeIdleSessionsMenuItem)
        menu.addItem(.separator())
        menu.addItem(emailStatusMenuItem)
        menu.addItem(errorMenuItem)
        menu.addItem(.separator())
        preventSleepMenuItem.target = self
        sessionNotificationMenuItem.target = self
        menu.addItem(preventSleepMenuItem)
        menu.addItem(sessionNotificationMenuItem)
        menu.addItem(.separator())

        let emailConfigItem = NSMenuItem(title: "邮件通知设置...", action: #selector(openEmailConfig(_:)), keyEquivalent: "")
        emailConfigItem.target = self
        menu.addItem(emailConfigItem)

        menu.addItem(.separator())
        addColorMenus()
        menu.addItem(.separator())

        let refreshItem = NSMenuItem(title: "立即刷新", action: #selector(refreshNow(_:)), keyEquivalent: "r")
        refreshItem.target = self
        menu.addItem(refreshItem)

        let openCodexItem = NSMenuItem(title: "打开 ~/.codex", action: #selector(openCodexFolder(_:)), keyEquivalent: "")
        openCodexItem.target = self
        menu.addItem(openCodexItem)

        let openClaudeItem = NSMenuItem(title: "打开 ~/.claude", action: #selector(openClaudeFolder(_:)), keyEquivalent: "")
        openClaudeItem.target = self
        menu.addItem(openClaudeItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "退出 AiStatus", action: #selector(quit(_:)), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
    }

    private func addColorMenus() {
        let runningItem = NSMenuItem(title: "运行时灯颜色", action: nil, keyEquivalent: "")
        runningItem.submenu = runningColorMenu
        menu.addItem(runningItem)

        let idleItem = NSMenuItem(title: "空闲时灯颜色", action: nil, keyEquivalent: "")
        idleItem.submenu = idleColorMenu
        menu.addItem(idleItem)

        for color in StatusLightColor.available {
            let runningColorItem = NSMenuItem(title: color.title, action: #selector(selectRunningColor(_:)), keyEquivalent: "")
            runningColorItem.target = self
            runningColorItem.representedObject = color.id
            runningColorMenu.addItem(runningColorItem)

            let idleColorItem = NSMenuItem(title: color.title, action: #selector(selectIdleColor(_:)), keyEquivalent: "")
            idleColorItem.target = self
            idleColorItem.representedObject = color.id
            idleColorMenu.addItem(idleColorItem)
        }

        updateColorMenuChecks()
    }

    @objc private func refreshNow(_ sender: Any?) {
        refresh()
    }

    @objc private func selectRunningColor(_ sender: NSMenuItem) {
        guard let colorID = sender.representedObject as? String else {
            return
        }
        colorPreferences.runningColorID = colorID
        updateColorMenuChecks()
        refresh()
    }

    @objc private func selectIdleColor(_ sender: NSMenuItem) {
        guard let colorID = sender.representedObject as? String else {
            return
        }
        colorPreferences.idleColorID = colorID
        updateColorMenuChecks()
        refresh()
    }

    @objc private func toggleSleepPrevention(_ sender: NSMenuItem) {
        sleepPreventionPreferences.isEnabled.toggle()
        applySleepPreventionPreference()
        refresh()
    }

    @objc private func toggleSessionNotification(_ sender: NSMenuItem) {
        sessionNotificationPreferences.isEnabled.toggle()
        updateSessionNotificationMenuCheck()
        refresh()
    }

    @objc private func openEmailConfig(_ sender: Any?) {
        if emailConfigWindowController == nil || emailConfigWindowController?.window == nil {
            emailConfigWindowController = EmailConfigWindowController()
        }
        emailConfigWindowController?.showWindow(sender)
        emailConfigWindowController?.window?.makeKey()
    }

    @objc private func openCodexFolder(_ sender: Any?) {
        NSWorkspace.shared.open(gptMonitor.codexHome)
    }

    @objc private func openClaudeFolder(_ sender: Any?) {
        NSWorkspace.shared.open(claudeMonitor.claudeHome)
    }

    @objc private func quit(_ sender: Any?) {
        NSApp.terminate(nil)
    }

    private func refresh() {
        let gptSnapshot = gptMonitor.snapshot()
        let claudeSnapshot = claudeMonitor.snapshot()
        let activeNames = [
            gptSnapshot.isThinking ? "GPT" : nil,
            claudeSnapshot.isThinking ? "Claude" : nil
        ].compactMap { $0 }
        let isActive = !activeNames.isEmpty
        let color = isActive ? colorPreferences.runningColor : colorPreferences.idleColor
        let stateText = isActive
            ? "\(colorPreferences.runningColorTitle)灯，\(activeNames.joined(separator: " + ")) 正在使用"
            : "\(colorPreferences.idleColorTitle)灯，GPT / Claude 空闲"

        if let button = statusItem.button {
            button.image = StatusDotImage.make(color: color, gptActive: gptSnapshot.isThinking, claudeActive: claudeSnapshot.isThinking)
            button.toolTip = "AiStatus：\(stateText)"
            button.setAccessibilityLabel("AiStatus \(stateText)")
        }

        stateMenuItem.title = "状态：\(stateText)"

        // GPT: state line doubles as active sessions menu
        gptStateMenuItem.title = providerStateTitle(name: "GPT", isThinking: gptSnapshot.isThinking, activeCount: gptSnapshot.activeSessionCount)
        populateSessionMenu(gptActiveMenu, titles: gptSnapshot.activeSessionTitles)
        gptIdleSessionsMenuItem.title = "GPT 闲置会话 \(gptSnapshot.idleSessionTitles.count)"
        populateSessionMenu(gptIdleMenu, titles: gptSnapshot.idleSessionTitles)

        // Claude: state line doubles as active sessions menu
        claudeStateMenuItem.title = providerStateTitle(name: "Claude", isThinking: claudeSnapshot.isThinking, activeCount: claudeSnapshot.activeSessionCount)
        populateSessionMenu(claudeActiveMenu, titles: claudeSnapshot.activeSessionTitles)
        claudeIdleSessionsMenuItem.title = "Claude 闲置会话 \(claudeSnapshot.idleSessionTitles.count)"
        populateSessionMenu(claudeIdleMenu, titles: claudeSnapshot.idleSessionTitles)

        refreshEmailConfiguredState()
        updateSessionTransitionNotifications(gptSnapshot: gptSnapshot, claudeSnapshot: claudeSnapshot)
        updateEmailStatusDisplay()

        // Errors
        let errors = [
            gptSnapshot.errorMessage,
            claudeSnapshot.errorMessage,
            powerAssertionErrorMessage,
            notificationErrorMessage
        ].compactMap { $0 }
        if !errors.isEmpty {
            errorMenuItem.title = "提示：\(errors.joined(separator: "；"))"
            errorMenuItem.isHidden = false
        } else {
            errorMenuItem.isHidden = true
        }
    }

    private func updateEmailStatusDisplay() {
        switch emailStatus {
        case .notConfigured:
            emailStatusMenuItem.title = "邮件：未配置"
        case .disabled:
            emailStatusMenuItem.title = "邮件：已关闭"
        case .configured:
            emailStatusMenuItem.title = "邮件：已配置，等待所有会话结束"
        case let .sent(date):
            let time = DateFormatter.localizedString(from: date, dateStyle: .none, timeStyle: .short)
            emailStatusMenuItem.title = "邮件：已发送 \(time)"
        case let .failed(error):
            emailStatusMenuItem.title = "邮件：发送失败 — \(error)"
        }
    }

    private func configureNotifications() {
        notificationCenter.delegate = self
        notificationCenter.requestAuthorization(options: [.alert, .sound]) { [weak self] granted, error in
            DispatchQueue.main.async {
                if let error {
                    self?.notificationErrorMessage = "通知权限请求失败：\(error.localizedDescription)"
                } else if !granted {
                    self?.notificationErrorMessage = "没有通知权限，无法提示会话结束"
                } else {
                    self?.notificationErrorMessage = nil
                }
                self?.refresh()
            }
        }
    }

    private func updateSessionTransitionNotifications(
        gptSnapshot: CodexStatusSnapshot,
        claudeSnapshot: ClaudeStatusSnapshot
    ) {
        guard gptSnapshot.errorMessage == nil, claudeSnapshot.errorMessage == nil else {
            return
        }

        let currentActiveSessions = trackedSessions(
            provider: "GPT",
            sessions: gptSnapshot.activeSessions
        ).merging(
            trackedSessions(provider: "Claude", sessions: claudeSnapshot.activeSessions),
            uniquingKeysWith: { current, _ in current }
        )
        let didFinishAllWork = activeWorkTransitionTracker.update(activeSessionCount: currentActiveSessions.count)

        guard let previousActiveSessionsByID else {
            self.previousActiveSessionsByID = currentActiveSessions
            return
        }

        for (id, session) in previousActiveSessionsByID where currentActiveSessions[id] == nil {
            sendSessionEndedNotification(for: session)
        }
        if didFinishAllWork {
            sendAllWorkFinishedEmail(endedSessions: Array(previousActiveSessionsByID.values))
        }

        self.previousActiveSessionsByID = currentActiveSessions
    }

    private func refreshEmailConfiguredState() {
        let configURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".aistatus", isDirectory: true)
            .appendingPathComponent("email.json")

        let currentModDate = (try? configURL.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate

        // If config file hasn't changed, preserve transient states
        if currentModDate == lastEmailConfigModDate {
            if case .sent = emailStatus { return }
            if case .failed = emailStatus { return }
        }
        lastEmailConfigModDate = currentModDate

        let fileExists = FileManager.default.fileExists(atPath: configURL.path)

        guard fileExists else {
            if case .notConfigured = emailStatus { return }
            emailStatus = .notConfigured
            return
        }

        do {
            if try EmailNotificationConfigLoader.load() != nil {
                if case .configured = emailStatus { return }
                emailStatus = .configured
            } else {
                if case .disabled = emailStatus { return }
                emailStatus = .disabled
            }
        } catch {
            if case let .failed(err) = emailStatus, err == error.localizedDescription { return }
            emailStatus = .failed(error.localizedDescription)
        }
    }

    private func trackedSessions(
        provider: String,
        sessions: [StatusSessionSummary]
    ) -> [String: TrackedSession] {
        Dictionary(
            uniqueKeysWithValues: sessions.map { session in
                let id = "\(provider):\(session.id)"
                return (id, TrackedSession(id: id, provider: provider, title: session.title, lastAnswer: session.lastAnswer))
            }
        )
    }

    private func sendSessionEndedNotification(for session: TrackedSession) {
        guard sessionNotificationPreferences.isEnabled else {
            return
        }

        let content = UNMutableNotificationContent()
        content.title = "\(session.provider) 会话已结束"
        content.body = session.title
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "session-ended-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )

        notificationCenter.add(request) { [weak self] error in
            guard let error else {
                return
            }

            DispatchQueue.main.async {
                self?.notificationErrorMessage = "发送通知失败：\(error.localizedDescription)"
                self?.refresh()
            }
        }
    }

    private func sendAllWorkFinishedEmail(endedSessions: [TrackedSession]) {
        allWorkEmailNotifier.send(endedSessions: endedSessions) { [weak self] errorMessage in
            if let errorMessage {
                self?.emailStatus = .failed(errorMessage)
            } else {
                self?.emailStatus = .sent(Date())
            }
            self?.refresh()
        }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    private func applySleepPreventionPreference() {
        if sleepPreventionPreferences.isEnabled {
            powerAssertionErrorMessage = sleepPreventer.enable()
            if powerAssertionErrorMessage != nil {
                sleepPreventionPreferences.isEnabled = false
                sleepPreventer.disable()
            }
        } else {
            powerAssertionErrorMessage = nil
            sleepPreventer.disable()
        }

        updateSleepPreventionMenuCheck()
    }

    private func updateColorMenuChecks() {
        for item in runningColorMenu.items {
            item.state = (item.representedObject as? String) == colorPreferences.runningColorID ? .on : .off
        }
        for item in idleColorMenu.items {
            item.state = (item.representedObject as? String) == colorPreferences.idleColorID ? .on : .off
        }
    }

    private func updateSleepPreventionMenuCheck() {
        preventSleepMenuItem.state = sleepPreventer.isEnabled ? .on : .off
    }

    private func updateSessionNotificationMenuCheck() {
        sessionNotificationMenuItem.state = sessionNotificationPreferences.isEnabled ? .on : .off
    }

    private func providerStateTitle(name: String, isThinking: Bool, activeCount: Int) -> String {
        let stateText = isThinking ? "运行中" : "空闲"
        return "\(name)：\(stateText) · 活跃会话 \(activeCount)"
    }

    private func populateSessionMenu(_ menu: NSMenu, titles: [String]) {
        menu.removeAllItems()

        guard !titles.isEmpty else {
            let emptyItem = NSMenuItem(title: "无", action: nil, keyEquivalent: "")
            emptyItem.isEnabled = false
            menu.addItem(emptyItem)
            return
        }

        for title in titles {
            let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
            item.isEnabled = false
            menu.addItem(item)
        }
    }
}

private struct TrackedSession: Equatable {
    let id: String
    let provider: String
    let title: String
    let lastAnswer: String?
}

private enum EmailStatus: Equatable {
    case notConfigured
    case disabled
    case configured
    case sent(Date)
    case failed(String)
}

private final class AllWorkEmailNotifier {
    private let queue = DispatchQueue(label: "AiStatus.emailNotifier")

    func send(
        endedSessions: [TrackedSession],
        completion: @escaping (String?) -> Void
    ) {
        let finishedAt = Date()
        queue.async {
            do {
                guard let config = try EmailNotificationConfigLoader.load() else {
                    DispatchQueue.main.async {
                        completion("邮件通知未启用")
                    }
                    return
                }

                let message = EmailMessage(
                    from: config.from,
                    to: config.to,
                    subject: config.subject,
                    body: Self.htmlBody(endedSessions: endedSessions, finishedAt: finishedAt),
                    date: finishedAt,
                    isHTML: true
                )
                try SMTPEmailSender(config: config).send(message: message)
                DispatchQueue.main.async {
                    completion(nil)
                }
            } catch {
                DispatchQueue.main.async {
                    completion(error.localizedDescription)
                }
            }
        }
    }

    private static func htmlBody(endedSessions: [TrackedSession], finishedAt: Date) -> String {
        let sorted = endedSessions.sorted { lhs, rhs in
            lhs.provider == rhs.provider ? lhs.title < rhs.title : lhs.provider < rhs.provider
        }
        let sessionRows = sorted.map { session in
            let badgeColor = session.provider == "GPT" ? "#10b981" : "#d97706"
            let answerText = session.lastAnswer.map { escapedHTML($0) } ?? escapedHTML(session.title)
            let titleLine = session.lastAnswer != nil
                ? "<div style=\"font-size:11px;color:#9ca3af;margin-top:4px;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif\">\(escapedHTML(session.title))</div>"
                : ""
            return """
            <tr>
              <td style="padding:12px 0;border-bottom:1px solid #f0f0f0">
                <span style="display:inline-block;background:\(badgeColor);color:#fff;font-size:11px;font-weight:600;padding:2px 8px;border-radius:4px;margin-right:10px;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif">\(session.provider)</span>
                <span style="color:#374151;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;font-size:14px;line-height:1.6">\(answerText)</span>
                \(titleLine)
              </td>
            </tr>
            """
        }.joined()

        let sessionSection: String
        if sorted.isEmpty {
            sessionSection = """
            <tr>
              <td style="padding:10px 0;color:#9ca3af;font-size:14px;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif">无会话详情</td>
            </tr>
            """
        } else {
            sessionSection = sessionRows
        }

        let timeStr = DateFormatter.localizedString(from: finishedAt, dateStyle: .medium, timeStyle: .medium)

        return """
        <!DOCTYPE html>
        <html lang="zh-CN">
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width,initial-scale=1">
        </head>
        <body style="margin:0;padding:0;background:#f5f5f5">
        <table role="presentation" cellpadding="0" cellspacing="0" border="0" width="100%" style="background:#f5f5f5;padding:30px 0">
          <tr>
            <td align="center">
              <table role="presentation" cellpadding="0" cellspacing="0" border="0" width="520" style="background:#ffffff;border-radius:12px;overflow:hidden;box-shadow:0 2px 16px rgba(0,0,0,0.06)">

                <!-- Header -->
                <tr>
                  <td style="background:linear-gradient(135deg,#1e1e2e,#2d2d44);padding:32px 36px;text-align:center">
                    <table role="presentation" cellpadding="0" cellspacing="0" border="0" width="100%">
                      <tr>
                        <td style="padding-bottom:16px">
                          <span style="display:inline-block;width:40px;height:40px;background:rgba(16,185,129,0.15);border-radius:50%;text-align:center;line-height:40px">
                            <span style="font-size:20px">&#x2705;</span>
                          </span>
                        </td>
                      </tr>
                      <tr>
                        <td style="font-size:20px;font-weight:700;color:#ffffff;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;letter-spacing:0.5px">
                          AI &#xB7; Work Complete
                        </td>
                      </tr>
                      <tr>
                        <td style="font-size:13px;color:rgba(255,255,255,0.55);font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;padding-top:6px">
                          All AI sessions have finished
                        </td>
                      </tr>
                    </table>
                  </td>
                </tr>

                <!-- Body -->
                <tr>
                  <td style="padding:36px">

                    <!-- Message -->
                    <table role="presentation" cellpadding="0" cellspacing="0" border="0" width="100%">
                      <tr>
                        <td style="font-size:15px;color:#374151;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;line-height:1.7;padding-bottom:24px">
                          AiStatus &#x68C0;&#x6D4B;&#x5230; GPT / Claude &#x5747;&#x5DF2;&#x7A7A;&#x95F2;&#xFF0C;<strong>&#x6240;&#x6709; AI &#x5DE5;&#x4F5C;&#x5DF2;&#x7ECF;&#x7ED3;&#x675F;</strong>&#x3002;
                        </td>
                      </tr>

                      <!-- Divider -->
                      <tr>
                        <td style="border-top:1px solid #f0f0f0;padding-top:20px">
                          <span style="font-size:12px;font-weight:600;color:#9ca3af;text-transform:uppercase;letter-spacing:1px;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif">Last Response</span>
                        </td>
                      </tr>

                      \(sessionSection)
                    </table>

                  </td>
                </tr>

                <!-- Footer -->
                <tr>
                  <td style="background:#fafafa;padding:20px 36px;border-top:1px solid #f0f0f0">
                    <table role="presentation" cellpadding="0" cellspacing="0" border="0" width="100%">
                      <tr>
                        <td style="font-size:12px;color:#9ca3af;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif">
                          AiStatus
                        </td>
                        <td style="font-size:12px;color:#9ca3af;text-align:right;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif">
                          \(escapedHTML(timeStr))
                        </td>
                      </tr>
                    </table>
                  </td>
                </tr>

              </table>

              <!-- Fine print -->
              <table role="presentation" cellpadding="0" cellspacing="0" border="0" width="520">
                <tr>
                  <td style="padding:16px 0;text-align:center;font-size:11px;color:#c0c0c0;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif">
                    Sent by AiStatus &#xB7; macOS Menu Bar Monitor
                  </td>
                </tr>
              </table>

            </td>
          </tr>
        </table>
        </body>
        </html>
        """
    }

    private static func escapedHTML(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }
}

private final class StatusLightColorPreferences {
    private enum Key {
        static let runningColorID = "runningColorID"
        static let idleColorID = "idleColorID"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var runningColorID: String {
        get { colorID(forKey: Key.runningColorID, defaultID: "blue") }
        set { defaults.set(newValue, forKey: Key.runningColorID) }
    }

    var idleColorID: String {
        get { colorID(forKey: Key.idleColorID, defaultID: "green") }
        set { defaults.set(newValue, forKey: Key.idleColorID) }
    }

    var runningColor: NSColor {
        StatusLightColor.color(for: runningColorID).color
    }

    var idleColor: NSColor {
        StatusLightColor.color(for: idleColorID).color
    }

    var runningColorTitle: String {
        StatusLightColor.color(for: runningColorID).title
    }

    var idleColorTitle: String {
        StatusLightColor.color(for: idleColorID).title
    }

    private func colorID(forKey key: String, defaultID: String) -> String {
        guard let storedID = defaults.string(forKey: key),
              StatusLightColor.available.contains(where: { $0.id == storedID })
        else {
            return defaultID
        }
        return storedID
    }
}

private final class SleepPreventionPreferences {
    private enum Key {
        static let isEnabled = "preventSystemSleep"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var isEnabled: Bool {
        get { defaults.bool(forKey: Key.isEnabled) }
        set { defaults.set(newValue, forKey: Key.isEnabled) }
    }
}

private final class SessionNotificationPreferences {
    private enum Key {
        static let isEnabled = "sessionEndNotificationEnabled"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var isEnabled: Bool {
        get {
            if defaults.object(forKey: Key.isEnabled) == nil {
                return true // default on
            }
            return defaults.bool(forKey: Key.isEnabled)
        }
        set { defaults.set(newValue, forKey: Key.isEnabled) }
    }
}

private final class SleepPreventer {
    private var systemSleepAssertionID = IOPMAssertionID(kIOPMNullAssertionID)
    private var displaySleepAssertionID = IOPMAssertionID(kIOPMNullAssertionID)

    private(set) var isEnabled = false

    func enable() -> String? {
        guard !hasActiveAssertions else {
            isEnabled = true
            return nil
        }

        disable()

        let systemSleepResult = createAssertion(
            type: kIOPMAssertionTypePreventUserIdleSystemSleep as CFString,
            name: "AiStatus Prevent Idle System Sleep",
            assertionID: &systemSleepAssertionID
        )
        guard systemSleepResult == kIOReturnSuccess else {
            isEnabled = false
            return "无法开启防休眠（系统空闲睡眠 IOKit \(systemSleepResult)）"
        }

        let displaySleepResult = createAssertion(
            type: kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
            name: "AiStatus Prevent Idle Display Sleep",
            assertionID: &displaySleepAssertionID
        )
        guard displaySleepResult == kIOReturnSuccess else {
            disable()
            return "无法开启防休眠（显示器空闲睡眠 IOKit \(displaySleepResult)）"
        }

        isEnabled = true
        return nil
    }

    func disable() {
        releaseAssertion(&displaySleepAssertionID)
        releaseAssertion(&systemSleepAssertionID)
        isEnabled = false
    }

    deinit {
        disable()
    }

    private var hasActiveAssertions: Bool {
        systemSleepAssertionID != kIOPMNullAssertionID &&
            displaySleepAssertionID != kIOPMNullAssertionID
    }

    private func createAssertion(
        type: CFString,
        name: String,
        assertionID: inout IOPMAssertionID
    ) -> IOReturn {
        IOPMAssertionCreateWithName(
            type,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            name as CFString,
            &assertionID
        )
    }

    private func releaseAssertion(_ assertionID: inout IOPMAssertionID) {
        guard assertionID != kIOPMNullAssertionID else {
            return
        }

        IOPMAssertionRelease(assertionID)
        assertionID = IOPMAssertionID(kIOPMNullAssertionID)
    }
}

private struct StatusLightColor {
    let id: String
    let title: String
    let color: NSColor

    static let available: [StatusLightColor] = [
        StatusLightColor(id: "blue", title: "蓝色", color: .systemBlue),
        StatusLightColor(id: "green", title: "绿色", color: .systemGreen),
        StatusLightColor(id: "teal", title: "青色", color: .systemTeal),
        StatusLightColor(id: "purple", title: "紫色", color: .systemPurple),
        StatusLightColor(id: "orange", title: "橙色", color: .systemOrange),
        StatusLightColor(id: "yellow", title: "黄色", color: .systemYellow),
        StatusLightColor(id: "red", title: "红色", color: .systemRed),
        StatusLightColor(id: "gray", title: "灰色", color: .systemGray)
    ]

    static func color(for id: String) -> StatusLightColor {
        available.first { $0.id == id } ?? available[0]
    }
}

private enum StatusDotImage {
    static func make(color: NSColor, gptActive: Bool, claudeActive: Bool) -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size)
        image.lockFocus()

        let bounds = NSRect(origin: .zero, size: size)
        NSColor.clear.setFill()
        bounds.fill()

        let glowRect = NSRect(x: 2, y: 2, width: 14, height: 14)
        color.withAlphaComponent(0.20).setFill()
        NSBezierPath(ovalIn: glowRect).fill()

        let dotRect = NSRect(x: 5, y: 5, width: 8, height: 8)
        color.setFill()
        NSBezierPath(ovalIn: dotRect).fill()

        NSColor.white.withAlphaComponent(0.55).setFill()
        NSBezierPath(ovalIn: NSRect(x: 7, y: 10, width: 3, height: 3)).fill()

        drawProviderMarkers(gptActive: gptActive, claudeActive: claudeActive)

        image.unlockFocus()
        image.isTemplate = false
        return image
    }

    private static func drawProviderMarkers(gptActive: Bool, claudeActive: Bool) {
        guard gptActive || claudeActive else {
            return
        }

        let markerColor = NSColor.white.withAlphaComponent(0.90)
        markerColor.setFill()

        if gptActive && claudeActive {
            NSBezierPath(ovalIn: NSRect(x: 4, y: 3, width: 3, height: 3)).fill()
            NSBezierPath(ovalIn: NSRect(x: 11, y: 3, width: 3, height: 3)).fill()
        } else if gptActive {
            NSBezierPath(ovalIn: NSRect(x: 5, y: 3, width: 3, height: 3)).fill()
        } else if claudeActive {
            NSBezierPath(ovalIn: NSRect(x: 10, y: 3, width: 3, height: 3)).fill()
        }
    }
}
