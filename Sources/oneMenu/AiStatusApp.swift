import AppKit
import CodexStatusCore
import Foundation
import IOKit.pwr_mgt
import UserNotifications

@main
final class OneMenuApp: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    private let gptMonitor = CodexStatusMonitor()
    private let claudeMonitor = ClaudeStatusMonitor()
    private let colorPreferences = StatusLightColorPreferences()
    private let appearancePreferences = AppAppearancePreferences()
    private let sleepPreventionPreferences = SleepPreventionPreferences()
    private let sessionNotificationPreferences = SessionNotificationPreferences()
    private let statusBarDisplayPreferences = StatusBarDisplayPreferences()
    private let hardwareStatusBarPreferences = HardwareStatusBarPreferences()
    private let countdownPreferences = CountdownTimerPreferences()
    private let targetTimeCountdownPreferences = TargetTimeCountdownPreferences()
    private let systemReminderPreferences = SystemReminderPreferences()
    private lazy var countdownTimer = CountdownTimerController(preferences: countdownPreferences)
    private let sleepPreventer = SleepPreventer()
    private let weatherService = WeatherForecastService()
    private let hardwareMonitor = HardwareStatusMonitor()
    private let hardwareQueue = DispatchQueue(label: "oneMenu.hardwareMonitor", qos: .utility)
    private let monitorQueue = DispatchQueue(label: "oneMenu.sessionMonitors", qos: .utility)
    private let countdownQueue = DispatchQueue(label: "oneMenu.countdownTimer", qos: .userInteractive)
    private let allWorkEmailNotifier = AllWorkEmailNotifier()
    private let notificationCenter = UNUserNotificationCenter.current()
    private let statusItem = NSStatusBar.system.statusItem(withLength: 24)
    private let claudeStatusItem = NSStatusBar.system.statusItem(withLength: 24)
    private let weatherStatusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let hardwareStatusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let countdownStatusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let targetTimeCountdownStatusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let systemReminderStatusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let sleepStatusItem = NSStatusBar.system.statusItem(withLength: 24)
    private let hoverWindowController = StatusHoverWindowController()
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
    private let weatherSummaryMenuItem = NSMenuItem(title: "天气：定位中", action: nil, keyEquivalent: "")
    private let weatherUpdatedMenuItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let hourlyForecastMenu = NSMenu(title: "未来 8 小时")
    private let dailyForecastMenu = NSMenu(title: "7 天预报")
    private let weatherHourlyForecastMenuItem = NSMenuItem(title: "未来 8 小时", action: nil, keyEquivalent: "")
    private let weatherDailyForecastMenuItem = NSMenuItem(title: "7 天预报", action: nil, keyEquivalent: "")
    private let hardwareSummaryMenuItem = NSMenuItem(title: "硬件：检测中", action: nil, keyEquivalent: "")
    private let hardwareCPUMenuItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let hardwareMemoryMenuItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let hardwareBatteryMenuItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let hardwareThermalMenuItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let hardwareGPUMenuItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let hardwareTemperaturesMenuItem = NSMenuItem(title: "温度传感器", action: nil, keyEquivalent: "")
    private let hardwareFansMenuItem = NSMenuItem(title: "风扇转速", action: nil, keyEquivalent: "")
    private let hardwareTemperaturesMenu = NSMenu(title: "温度传感器")
    private let hardwareFansMenu = NSMenu(title: "风扇转速")
    private let preventSleepMenuItem = NSMenuItem(title: "保持 Mac 活跃（防休眠）", action: #selector(toggleSleepPrevention(_:)), keyEquivalent: "")
    private var emailConfigWindowController: EmailConfigWindowController?
    private var settingsWindowController: SettingsWindowController?

    private var timer: Timer?
    private var countdownTickSource: DispatchSourceTimer?
    private var powerAssertionErrorMessage: String?
    private var notificationErrorMessage: String?
    private var statusBarDisplayErrorMessage: String?
    private var gptSnapshot: CodexStatusSnapshot?
    private var claudeSnapshot: ClaudeStatusSnapshot?
    private var isSessionRefreshInFlight = false
    private var hardwareSnapshot: HardwareStatusSnapshot?
    private var lastHardwareRefreshAt: Date?
    private var isHardwareRefreshInFlight = false
    private let hardwareRefreshInterval: TimeInterval = 3
    private var pendingStatusClickWorkItem: DispatchWorkItem?
    private var pendingHoverWorkItem: DispatchWorkItem?
    private var hoveredModule: StatusBarModule?
    private var isStatusHoverPinnedByClick = false
    private var statusHoverGlobalDismissMonitor: Any?
    private var statusHoverLocalDismissMonitor: Any?
    private var emailStatus: EmailStatus = .notConfigured
    private var lastEmailConfigModDate: Date?
    private var activeWorkTransitionTracker = ActiveWorkTransitionTracker()
    private var previousActiveSessionsByID: [String: TrackedSession]?
    private let systemReminderRequestIdentifier = "aistatus.systemReminder"
    private var systemReminderRegistrationStatusText = "未注册"

    static func main() {
        let app = NSApplication.shared
        let delegate = OneMenuApp()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        weatherService.onSnapshotChange = { [weak self] _ in
            self?.settingsWindowController?.updateWeatherSnapshot(self?.weatherService.snapshot ?? .idle)
            self?.refresh()
        }
        countdownTimer.onChange = { [weak self] snapshot in
            DispatchQueue.main.async {
                self?.settingsWindowController?.updateCountdownSnapshot(snapshot)
                self?.updateCountdownDisplay(snapshot)
                self?.syncStatusBarItemsVisibility()
                self?.refreshHoverWindowIfNeeded()
            }
        }
        applyAppearancePreference()
        configureStatusItem()
        configureMenu()
        installStatusHoverDismissMonitors()
        configureNotifications()
        applySleepPreventionPreference()
        weatherService.start()
        refreshSessionMonitors(force: true)
        refreshHardwareIfNeeded(force: true)
        refresh()

        let timer = Timer(timeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.weatherService.refreshIfNeeded()
            self?.refreshSessionMonitors()
            self?.refreshHardwareIfNeeded()
            self?.refresh()
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer

        startCountdownTickSource()
    }

    func applicationWillTerminate(_ notification: Notification) {
        timer?.invalidate()
        countdownTickSource?.cancel()
        hideStatusHover()
        removeStatusHoverDismissMonitors()
        weatherService.stop()
        sleepPreventer.disable()
    }

    func applicationDidResignActive(_ notification: Notification) {
        hideStatusHover()
    }

    private func startCountdownTickSource() {
        let source = DispatchSource.makeTimerSource(queue: countdownQueue)
        source.schedule(deadline: .now() + 1, repeating: 1, leeway: .milliseconds(20))
        source.setEventHandler { [weak self] in
            self?.countdownTimer.tick()
        }
        source.resume()
        countdownTickSource = source
    }

    private func performCountdownAction(_ action: @escaping (CountdownTimerController) -> Void) {
        countdownQueue.async { [weak self] in
            guard let self else {
                return
            }
            action(self.countdownTimer)
        }
    }

    private func currentCountdownSnapshot() -> CountdownSnapshot {
        countdownQueue.sync {
            countdownTimer.snapshot()
        }
    }

    private func configureStatusItem() {
        if let button = statusItem.button {
            button.imagePosition = .imageOnly
            button.imageScaling = .scaleProportionallyDown
            button.toolTip = "Codex/GPT：检测中"
            configureStatusButton(button, module: .gpt)
        }

        if let claudeButton = claudeStatusItem.button {
            claudeButton.imagePosition = .imageOnly
            claudeButton.imageScaling = .scaleProportionallyDown
            claudeButton.toolTip = "Claude：检测中"
            configureStatusButton(claudeButton, module: .claude)
        }

        if let weatherButton = weatherStatusItem.button {
            weatherButton.imagePosition = .imageLeading
            weatherButton.imageScaling = .scaleProportionallyDown
            weatherButton.font = NSFont.monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
            weatherButton.toolTip = "天气：定位中"
            configureStatusButton(weatherButton, module: .weather)
        }

        if let hardwareButton = hardwareStatusItem.button {
            hardwareButton.imagePosition = .imageLeading
            hardwareButton.imageScaling = .scaleProportionallyDown
            hardwareButton.font = NSFont.monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
            hardwareButton.toolTip = "硬件：检测中"
            configureStatusButton(hardwareButton, module: .hardware)
        }

        if let countdownButton = countdownStatusItem.button {
            countdownButton.imagePosition = .imageLeading
            countdownButton.imageScaling = .scaleProportionallyDown
            countdownButton.font = NSFont.monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
            countdownButton.wantsLayer = true
            countdownButton.layer?.cornerRadius = 5
            countdownButton.layer?.masksToBounds = true
            countdownButton.toolTip = "倒计时：未开始"
            configureStatusButton(countdownButton, module: .countdown)
        }

        if let targetCountdownButton = targetTimeCountdownStatusItem.button {
            targetCountdownButton.imagePosition = .imageLeading
            targetCountdownButton.imageScaling = .scaleProportionallyDown
            targetCountdownButton.font = NSFont.monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
            targetCountdownButton.wantsLayer = true
            targetCountdownButton.layer?.cornerRadius = 5
            targetCountdownButton.layer?.masksToBounds = true
            targetCountdownButton.toolTip = "目标倒计：检测中"
            configureStatusButton(targetCountdownButton, module: .targetTimeCountdown)
        }

        if let reminderButton = systemReminderStatusItem.button {
            reminderButton.imagePosition = .imageLeading
            reminderButton.imageScaling = .scaleProportionallyDown
            reminderButton.font = NSFont.monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
            reminderButton.toolTip = "系统提醒：未启用"
            configureStatusButton(reminderButton, module: .systemReminder)
        }

        if let sleepButton = sleepStatusItem.button {
            sleepButton.imagePosition = .imageOnly
            sleepButton.imageScaling = .scaleProportionallyDown
            sleepButton.toolTip = "防休眠：关闭"
            configureStatusButton(sleepButton, module: .sleep)
        }

        syncStatusBarItemsVisibility()
    }

    private func configureStatusButton(_ button: NSStatusBarButton, module: StatusBarModule) {
        button.target = self
        button.action = #selector(statusBarButtonClicked(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        button.identifier = NSUserInterfaceItemIdentifier(module.rawValue)
        addHoverTrackingArea(to: button, module: module)
    }

    private func addHoverTrackingArea(to button: NSStatusBarButton, module: StatusBarModule) {
        let trackingArea = NSTrackingArea(
            rect: .zero,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: ["module": module.rawValue]
        )
        button.addTrackingArea(trackingArea)
    }

    private func configureMenu() {
        [
            stateMenuItem,
            gptStateMenuItem,
            claudeStateMenuItem,
            errorMenuItem,
            gptIdleSessionsMenuItem,
            claudeIdleSessionsMenuItem,
            weatherSummaryMenuItem,
            weatherUpdatedMenuItem,
            hardwareSummaryMenuItem,
            hardwareCPUMenuItem,
            hardwareMemoryMenuItem,
            hardwareBatteryMenuItem,
            hardwareThermalMenuItem,
            hardwareGPUMenuItem
        ].forEach {
            $0.isEnabled = false
        }

        gptStateMenuItem.submenu = gptActiveMenu
        claudeStateMenuItem.submenu = claudeActiveMenu
        gptIdleSessionsMenuItem.submenu = gptIdleMenu
        claudeIdleSessionsMenuItem.submenu = claudeIdleMenu
        weatherHourlyForecastMenuItem.submenu = hourlyForecastMenu
        weatherDailyForecastMenuItem.submenu = dailyForecastMenu
        hardwareTemperaturesMenuItem.submenu = hardwareTemperaturesMenu
        hardwareFansMenuItem.submenu = hardwareFansMenu
        emailStatusMenuItem.isEnabled = false

        let settingsItem = NSMenuItem(title: "设置...", action: #selector(openSettings(_:)), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        let refreshItem = NSMenuItem(title: "立即刷新", action: #selector(refreshNow(_:)), keyEquivalent: "r")
        refreshItem.target = self
        menu.addItem(refreshItem)

        preventSleepMenuItem.target = self
        menu.addItem(preventSleepMenuItem)
        menu.addItem(.separator())

        let openCodexItem = NSMenuItem(title: "打开 ~/.codex", action: #selector(openCodexFolder(_:)), keyEquivalent: "")
        openCodexItem.target = self
        menu.addItem(openCodexItem)

        let openClaudeItem = NSMenuItem(title: "打开 ~/.claude", action: #selector(openClaudeFolder(_:)), keyEquivalent: "")
        openClaudeItem.target = self
        menu.addItem(openClaudeItem)

        menu.addItem(.separator())

        let versionString = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0"
        let buildString = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
        let versionItem = NSMenuItem(title: "版本 \(versionString) (\(buildString))", action: nil, keyEquivalent: "")
        versionItem.isEnabled = false
        menu.addItem(versionItem)

        let quitItem = NSMenuItem(title: "退出 oneMenu", action: #selector(quit(_:)), keyEquivalent: "")
        quitItem.target = self
        menu.addItem(quitItem)
    }

    @objc private func refreshNow(_ sender: Any?) {
        weatherService.refreshIfNeeded(force: true)
        refreshSessionMonitors(force: true)
        refreshHardwareIfNeeded(force: true)
        refresh()
    }

    @objc private func refreshWeatherNow(_ sender: Any?) {
        weatherService.refreshIfNeeded(force: true)
        refresh()
    }

    @objc private func openLocationPrivacySettings(_ sender: Any?) {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_LocationServices") else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    @objc private func statusBarButtonClicked(_ sender: NSStatusBarButton) {
        guard let rawValue = sender.identifier?.rawValue,
              let module = StatusBarModule(rawValue: rawValue)
        else {
            return
        }

        if isSecondaryClickEvent(NSApp.currentEvent) {
            pendingStatusClickWorkItem?.cancel()
            pendingStatusClickWorkItem = nil
            hideStatusHover()
            menu.popUp(positioning: nil, at: .zero, in: sender)
            return
        }

        if (NSApp.currentEvent?.clickCount ?? 1) >= 2 {
            pendingStatusClickWorkItem?.cancel()
            pendingStatusClickWorkItem = nil
            hideStatusHover()
            openSettings(for: module, sender: sender)
            return
        }

        pendingStatusClickWorkItem?.cancel()
        if isStatusHoverPinnedByClick,
           hoveredModule == module,
           hoverWindowController.isVisible {
            hideStatusHover()
            return
        }

        let workItem = DispatchWorkItem { [weak self] in
            self?.showStatusHover(for: module, pinnedByClick: true)
        }
        pendingStatusClickWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16, execute: workItem)
    }

    private func isSecondaryClickEvent(_ event: NSEvent?) -> Bool {
        guard let event else {
            return false
        }

        switch event.type {
        case .rightMouseDown, .rightMouseUp:
            return true
        case .otherMouseDown, .otherMouseUp:
            return event.buttonNumber == 1
        default:
            return false
        }
    }

    @objc private func mouseEntered(with event: NSEvent) {
        guard let rawValue = event.trackingArea?.userInfo?["module"] as? String,
              let module = StatusBarModule(rawValue: rawValue)
        else {
            return
        }

        guard !isStatusHoverPinnedByClick else {
            return
        }

        hoveredModule = module
        pendingHoverWorkItem?.cancel()

        let workItem = DispatchWorkItem { [weak self] in
            self?.showStatusHover(for: module, pinnedByClick: false)
        }
        pendingHoverWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12, execute: workItem)
    }

    @objc private func mouseExited(with event: NSEvent) {
        guard let rawValue = event.trackingArea?.userInfo?["module"] as? String,
              let module = StatusBarModule(rawValue: rawValue),
              hoveredModule == module
        else {
            return
        }

        guard !isStatusHoverPinnedByClick else {
            return
        }

        hideStatusHover()
    }

    private func showStatusHover(for module: StatusBarModule, pinnedByClick: Bool) {
        if pinnedByClick {
            isStatusHoverPinnedByClick = true
            hoveredModule = module
        } else if isStatusHoverPinnedByClick {
            return
        }

        guard hoveredModule == module,
              let button = statusButton(for: module),
              let info = hoverInfo(for: module)
        else {
            return
        }

        hoverWindowController.show(info: info, anchoredTo: button)
    }

    private func hideStatusHover() {
        pendingHoverWorkItem?.cancel()
        pendingHoverWorkItem = nil
        isStatusHoverPinnedByClick = false
        hoveredModule = nil
        hoverWindowController.hide()
    }

    private func installStatusHoverDismissMonitors() {
        guard statusHoverGlobalDismissMonitor == nil,
              statusHoverLocalDismissMonitor == nil
        else {
            return
        }

        let mask: NSEvent.EventTypeMask = [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        statusHoverGlobalDismissMonitor = NSEvent.addGlobalMonitorForEvents(matching: mask) { [weak self] _ in
            DispatchQueue.main.async {
                self?.hideStatusHover()
            }
        }

        statusHoverLocalDismissMonitor = NSEvent.addLocalMonitorForEvents(matching: mask) { [weak self] event in
            guard let self else {
                return event
            }

            if self.isEventOnStatusButton(event) {
                return event
            }

            self.hideStatusHover()
            return event
        }
    }

    private func removeStatusHoverDismissMonitors() {
        if let statusHoverGlobalDismissMonitor {
            NSEvent.removeMonitor(statusHoverGlobalDismissMonitor)
            self.statusHoverGlobalDismissMonitor = nil
        }

        if let statusHoverLocalDismissMonitor {
            NSEvent.removeMonitor(statusHoverLocalDismissMonitor)
            self.statusHoverLocalDismissMonitor = nil
        }
    }

    private func isEventOnStatusButton(_ event: NSEvent) -> Bool {
        guard let eventWindow = event.window else {
            return false
        }

        for module in StatusBarModule.allCases {
            guard let button = statusButton(for: module),
                  button.window === eventWindow
            else {
                continue
            }

            let point = button.convert(event.locationInWindow, from: nil)
            if button.bounds.contains(point) {
                return true
            }
        }

        return false
    }

    private func refreshHoverWindowIfNeeded() {
        guard let module = hoveredModule,
              hoverWindowController.isVisible,
              let button = statusButton(for: module),
              let info = hoverInfo(for: module)
        else {
            return
        }

        hoverWindowController.show(info: info, anchoredTo: button)
    }

    private func popUpPublicMenu(for module: StatusBarModule) {
        guard let button = statusButton(for: module) else {
            return
        }
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height + 3), in: button)
    }

    private func statusButton(for module: StatusBarModule) -> NSStatusBarButton? {
        switch module {
        case .gpt:
            return statusItem.button
        case .claude:
            return claudeStatusItem.button
        case .weather:
            return weatherStatusItem.button
        case .hardware:
            return hardwareStatusItem.button
        case .countdown:
            return countdownStatusItem.button
        case .targetTimeCountdown:
            return targetTimeCountdownStatusItem.button
        case .systemReminder:
            return systemReminderStatusItem.button
        case .sleep:
            return sleepStatusItem.button
        }
    }

    @objc private func toggleSleepPrevention(_ sender: NSMenuItem) {
        sleepPreventionPreferences.isEnabled.toggle()
        applySleepPreventionPreference()
        refresh()
    }

    @objc private func openEmailConfig(_ sender: Any?) {
        if emailConfigWindowController == nil || emailConfigWindowController?.window == nil {
            emailConfigWindowController = EmailConfigWindowController()
        }
        emailConfigWindowController?.window?.appearance = appearancePreferences.appearance
        emailConfigWindowController?.showWindow(sender)
        emailConfigWindowController?.window?.makeKey()
    }

    @objc private func openSettings(_ sender: Any?) {
        openSettings(for: nil, sender: sender)
    }

    private func openSettings(for module: StatusBarModule?, sender: Any?) {
        if settingsWindowController == nil || settingsWindowController?.window == nil {
            settingsWindowController = SettingsWindowController(
                colorPreferences: colorPreferences,
                appearancePreferences: appearancePreferences,
                sleepPreventionPreferences: sleepPreventionPreferences,
                sessionNotificationPreferences: sessionNotificationPreferences,
                statusBarDisplayPreferences: statusBarDisplayPreferences,
                hardwareStatusBarPreferences: hardwareStatusBarPreferences,
                countdownPreferences: countdownPreferences,
                targetTimeCountdownPreferences: targetTimeCountdownPreferences,
                systemReminderPreferences: systemReminderPreferences,
                systemReminderRegistrationStatus: systemReminderRegistrationStatusText,
                countdownSnapshot: currentCountdownSnapshot(),
                weatherSnapshot: weatherService.snapshot,
                hardwareSnapshot: hardwareSnapshot,
                onChange: { [weak self] in
                    self?.statusBarDisplayErrorMessage = nil
                    self?.refresh()
                },
                onAppearanceChange: { [weak self] in
                    self?.applyAppearancePreference()
                },
                onSleepPreferenceChange: { [weak self] in
                    self?.applySleepPreventionPreference()
                    self?.settingsWindowController?.updateSleepState(isEnabled: self?.sleepPreventer.isEnabled ?? false)
                    self?.refresh()
                },
                onWeatherRefresh: { [weak self] in
                    self?.weatherService.refreshIfNeeded(force: true)
                    self?.refresh()
                },
                onHardwareRefresh: { [weak self] in
                    self?.refreshHardwareIfNeeded(force: true)
                },
                onCountdownDurationChange: { [weak self] in
                    self?.performCountdownAction { $0.durationDidChange() }
                },
                onCountdownStart: { [weak self] in
                    self?.performCountdownAction { $0.start() }
                },
                onCountdownPause: { [weak self] in
                    self?.performCountdownAction { $0.pause() }
                },
                onCountdownResume: { [weak self] in
                    self?.performCountdownAction { $0.resume() }
                },
                onCountdownReset: { [weak self] in
                    self?.performCountdownAction { $0.reset() }
                },
                onCountdownReminderChange: { [weak self] in
                    self?.updateCountdownDisplay()
                    self?.refreshHoverWindowIfNeeded()
                },
                onTargetTimeCountdownChange: { [weak self] in
                    self?.updateTargetTimeCountdownDisplay()
                    self?.refreshHoverWindowIfNeeded()
                },
                onSystemReminderChange: { [weak self] in
                    self?.scheduleSystemReminderNotification()
                    self?.updateSystemReminderDisplay()
                    self?.refreshHoverWindowIfNeeded()
                },
                onSystemReminderTest: { [weak self] in
                    self?.sendSystemReminderTestNotification()
                },
                onOpenLocationSettings: { [weak self] in
                    self?.openLocationPrivacySettings(nil)
                },
                onOpenCodexFolder: { [weak self] in
                    self?.openCodexFolder(nil)
                },
                onOpenClaudeFolder: { [weak self] in
                    self?.openClaudeFolder(nil)
                },
                onOpenEmailSettings: { [weak self] in
                    self?.openEmailConfig(nil)
                }
            )
        }

        settingsWindowController?.updateWeatherSnapshot(weatherService.snapshot)
        settingsWindowController?.updateHardwareSnapshot(hardwareSnapshot)
        settingsWindowController?.updateCountdownSnapshot(currentCountdownSnapshot())
        settingsWindowController?.updateTargetTimeCountdownStatus()
        settingsWindowController?.updateSystemReminderStatus(registrationStatus: systemReminderRegistrationStatusText)
        settingsWindowController?.updateSleepState(isEnabled: sleepPreventer.isEnabled)
        settingsWindowController?.updateAppearanceMode()
        if let module {
            settingsWindowController?.selectModule(module)
        }
        settingsWindowController?.window?.appearance = appearancePreferences.appearance
        settingsWindowController?.showWindow(sender)
        settingsWindowController?.window?.makeKeyAndOrderFront(sender)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func applyAppearancePreference() {
        let appearance = appearancePreferences.appearance
        NSApp.appearance = appearance
        settingsWindowController?.window?.appearance = appearance
        settingsWindowController?.updateAppearanceMode()
        emailConfigWindowController?.window?.appearance = appearance
        hoverWindowController.window?.appearance = appearance
        refreshHoverWindowIfNeeded()
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

    private func refreshSessionMonitors(force: Bool = false) {
        guard !isSessionRefreshInFlight else {
            return
        }

        isSessionRefreshInFlight = true
        monitorQueue.async { [weak self] in
            guard let self else {
                return
            }

            let gptSnapshot = self.gptMonitor.snapshot()
            let claudeSnapshot = self.claudeMonitor.snapshot()

            DispatchQueue.main.async {
                self.gptSnapshot = gptSnapshot
                self.claudeSnapshot = claudeSnapshot
                self.isSessionRefreshInFlight = false
                self.refresh()
            }
        }
    }

    private func refresh() {
        guard let gptSnapshot, let claudeSnapshot else {
            updatePendingSessionDisplay()
            refreshEmailConfiguredState()
            updateEmailStatusDisplay()
            updateWeatherDisplay()
            if let hardwareSnapshot {
                updateHardwareDisplay(with: hardwareSnapshot)
            } else {
                updateHardwarePendingDisplay()
            }
            updateCountdownDisplay()
            updateTargetTimeCountdownDisplay()
            updateSystemReminderDisplay()
            updateSleepStatusItem()
            syncStatusBarItemsVisibility()
            updateErrorDisplay(gptError: nil, claudeError: nil)
            refreshHoverWindowIfNeeded()
            return
        }

        let activeNames = [
            gptSnapshot.isThinking ? "GPT" : nil,
            claudeSnapshot.isThinking ? "Claude" : nil
        ].compactMap { $0 }
        let isActive = !activeNames.isEmpty
        let gptColor = gptSnapshot.isThinking ? colorPreferences.runningColor : colorPreferences.idleColor
        let claudeColor = claudeSnapshot.isThinking ? colorPreferences.runningColor : colorPreferences.idleColor
        let stateText = isActive
            ? "\(colorPreferences.runningColorTitle)灯，\(activeNames.joined(separator: " + ")) 正在使用"
            : "\(colorPreferences.idleColorTitle)灯，GPT / Claude 空闲"
        let gptStateText = gptSnapshot.isThinking
            ? "\(colorPreferences.runningColorTitle)灯，GPT 正在使用"
            : "\(colorPreferences.idleColorTitle)灯，GPT 空闲"
        let claudeStateText = claudeSnapshot.isThinking
            ? "\(colorPreferences.runningColorTitle)灯，Claude 正在使用"
            : "\(colorPreferences.idleColorTitle)灯，Claude 空闲"

        if let button = statusItem.button {
            button.image = StatusDotImage.make(color: gptColor, provider: .gpt, isActive: gptSnapshot.isThinking)
            button.toolTip = "Codex/GPT：\(gptStateText)"
            button.setAccessibilityLabel("Codex/GPT \(gptStateText)")
        }

        if let button = claudeStatusItem.button {
            button.image = StatusDotImage.make(color: claudeColor, provider: .claude, isActive: claudeSnapshot.isThinking)
            button.toolTip = "Claude：\(claudeStateText)"
            button.setAccessibilityLabel("Claude \(claudeStateText)")
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
        updateWeatherDisplay()
        if let hardwareSnapshot {
            updateHardwareDisplay(with: hardwareSnapshot)
        } else {
            updateHardwarePendingDisplay()
        }
        updateCountdownDisplay()
        updateTargetTimeCountdownDisplay()
        updateSystemReminderDisplay()
        updateSleepStatusItem()
        syncStatusBarItemsVisibility()
        updateErrorDisplay(gptError: gptSnapshot.errorMessage, claudeError: claudeSnapshot.errorMessage)
        refreshHoverWindowIfNeeded()
    }

    private func updatePendingSessionDisplay() {
        stateMenuItem.title = "状态：检测中"
        gptStateMenuItem.title = "GPT：检测中"
        claudeStateMenuItem.title = "Claude：检测中"
        gptIdleSessionsMenuItem.title = "GPT 闲置会话 --"
        claudeIdleSessionsMenuItem.title = "Claude 闲置会话 --"
        populateSessionMenu(gptActiveMenu, titles: [])
        populateSessionMenu(claudeActiveMenu, titles: [])
        populateSessionMenu(gptIdleMenu, titles: [])
        populateSessionMenu(claudeIdleMenu, titles: [])

        if let button = statusItem.button {
            button.image = StatusDotImage.make(color: colorPreferences.idleColor, provider: .gpt, isActive: false)
            button.toolTip = "Codex/GPT：检测中"
            button.setAccessibilityLabel("Codex/GPT 检测中")
        }

        if let button = claudeStatusItem.button {
            button.image = StatusDotImage.make(color: colorPreferences.idleColor, provider: .claude, isActive: false)
            button.toolTip = "Claude：检测中"
            button.setAccessibilityLabel("Claude 检测中")
        }
    }

    private func updateErrorDisplay(gptError: String?, claudeError: String?) {
        let errors = [
            gptError,
            claudeError,
            powerAssertionErrorMessage,
            notificationErrorMessage,
            statusBarDisplayErrorMessage
        ].compactMap { $0 }

        if !errors.isEmpty {
            errorMenuItem.title = "提示：\(errors.joined(separator: "；"))"
            errorMenuItem.isHidden = false
        } else {
            errorMenuItem.isHidden = true
        }
    }

    private func hoverInfo(for module: StatusBarModule) -> StatusHoverInfo? {
        switch module {
        case .gpt:
            return gptHoverInfo()
        case .claude:
            return claudeHoverInfo()
        case .weather:
            return weatherHoverInfo()
        case .hardware:
            return hardwareHoverInfo()
        case .countdown:
            return countdownHoverInfo()
        case .targetTimeCountdown:
            return targetTimeCountdownHoverInfo()
        case .systemReminder:
            return systemReminderHoverInfo()
        case .sleep:
            return sleepHoverInfo()
        }
    }

    private func gptHoverInfo() -> StatusHoverInfo {
        guard let snapshot = gptSnapshot else {
            return StatusHoverInfo(
                title: "Codex/GPT",
                subtitle: "检测中",
                symbolName: "bolt.horizontal.circle.fill",
                rows: [StatusHoverRow(label: "状态", value: "正在读取会话文件")]
            )
        }

        return sessionHoverInfo(
            title: "Codex/GPT",
            symbolName: "bolt.horizontal.circle.fill",
            providerName: "GPT",
            isActive: snapshot.isThinking,
            activeSessions: snapshot.activeSessions,
            idleSessions: snapshot.idleSessions,
            scannedFileCount: snapshot.scannedFileCount,
            latestEventAt: snapshot.latestEventAt,
            errorMessage: snapshot.errorMessage
        )
    }

    private func claudeHoverInfo() -> StatusHoverInfo {
        guard let snapshot = claudeSnapshot else {
            return StatusHoverInfo(
                title: "Claude",
                subtitle: "检测中",
                symbolName: "sparkles",
                rows: [StatusHoverRow(label: "状态", value: "正在读取会话文件")]
            )
        }

        return sessionHoverInfo(
            title: "Claude",
            symbolName: "sparkles",
            providerName: "Claude",
            isActive: snapshot.isThinking,
            activeSessions: snapshot.activeSessions,
            idleSessions: snapshot.idleSessions,
            scannedFileCount: snapshot.scannedFileCount,
            latestEventAt: snapshot.latestEventAt,
            errorMessage: snapshot.errorMessage
        )
    }

    private func sessionHoverInfo(
        title: String,
        symbolName: String,
        providerName: String,
        isActive: Bool,
        activeSessions: [StatusSessionSummary],
        idleSessions: [StatusSessionSummary],
        scannedFileCount: Int,
        latestEventAt: Date?,
        errorMessage: String?
    ) -> StatusHoverInfo {
        var rows = [
            StatusHoverRow(label: "状态", value: isActive ? "运行中" : "空闲"),
            StatusHoverRow(label: "活跃会话", value: "\(activeSessions.count)"),
            StatusHoverRow(label: "闲置会话", value: "\(idleSessions.count)"),
            StatusHoverRow(label: "扫描文件", value: "\(scannedFileCount)")
        ]

        if let latestEventAt {
            rows.append(StatusHoverRow(label: "最近事件", value: shortDateTimeText(latestEventAt)))
        }

        appendSessionRows(prefix: "活跃", sessions: activeSessions, to: &rows)
        appendSessionRows(prefix: "闲置", sessions: idleSessions, to: &rows)

        if let errorMessage {
            rows.append(StatusHoverRow(label: "提示", value: errorMessage))
        }

        return StatusHoverInfo(
            title: title,
            subtitle: isActive ? "\(providerName) 正在处理任务" : "\(providerName) 当前空闲",
            symbolName: symbolName,
            rows: rows
        )
    }

    private func appendSessionRows(
        prefix: String,
        sessions: [StatusSessionSummary],
        to rows: inout [StatusHoverRow]
    ) {
        guard !sessions.isEmpty else {
            rows.append(StatusHoverRow(label: "\(prefix)详情", value: "无"))
            return
        }

        for (index, session) in sessions.prefix(3).enumerated() {
            rows.append(StatusHoverRow(label: "\(prefix) \(index + 1)", value: sessionHoverText(for: session)))
        }

        if sessions.count > 3 {
            rows.append(StatusHoverRow(label: "\(prefix)更多", value: "还有 \(sessions.count - 3) 个会话"))
        }
    }

    private func sessionHoverText(for session: StatusSessionSummary) -> String {
        guard let lastAnswer = session.lastAnswer?.trimmingCharacters(in: .whitespacesAndNewlines),
              !lastAnswer.isEmpty,
              lastAnswer != session.title
        else {
            return session.title
        }

        return "\(session.title) · \(lastAnswer)"
    }

    private func weatherHoverInfo() -> StatusHoverInfo {
        let snapshot = weatherService.snapshot
        guard let forecast = snapshot.forecast else {
            return StatusHoverInfo(
                title: "天气",
                subtitle: weatherSnapshotStatusText(snapshot),
                symbolName: "cloud.sun.fill",
                rows: [StatusHoverRow(label: "状态", value: weatherSnapshotStatusText(snapshot))]
            )
        }

        let current = forecast.current
        var rows = [
            StatusHoverRow(label: "当前", value: "\(current.condition.title) \(temperatureText(current.temperature))"),
            StatusHoverRow(label: "体感", value: current.apparentTemperature.map(temperatureText) ?? "--"),
            StatusHoverRow(label: "湿度", value: current.humidity.map { "\(Int(round($0)))%" } ?? "--"),
            StatusHoverRow(label: "风速", value: current.windSpeed.map { "\(Int(round($0))) km/h" } ?? "--"),
            StatusHoverRow(label: "更新", value: shortTimeText(forecast.fetchedAt))
        ]

        for hour in forecast.hourly.prefix(3) {
            rows.append(
                StatusHoverRow(
                    label: hourLabel(from: hour.time),
                    value: "\(hour.condition.title) \(temperatureText(hour.temperature))"
                )
            )
        }

        return StatusHoverInfo(
            title: "天气",
            subtitle: "\(current.condition.title) \(temperatureText(current.temperature))",
            symbolName: current.condition.symbolName,
            rows: rows
        )
    }

    private func hardwareHoverInfo() -> StatusHoverInfo {
        guard let snapshot = hardwareSnapshot else {
            return StatusHoverInfo(
                title: "硬件状态",
                subtitle: "检测中",
                symbolName: "cpu.fill",
                rows: [StatusHoverRow(label: "状态", value: "等待首次硬件采样")]
            )
        }

        let battery = snapshot.battery.map { "\($0.percent)% · \($0.powerSource.title)" } ?? "未检测到"
        let temperatures = snapshot.temperatures.isEmpty
            ? "不可用"
            : snapshot.temperatures.prefix(3).map { "\($0.name) \(temperatureText($0.celsius))" }.joined(separator: "，")
        let fans = snapshot.fans.isEmpty
            ? "不可用"
            : snapshot.fans.prefix(2).map { "\($0.name) \(Int(round($0.rpm))) RPM" }.joined(separator: "，")

        return StatusHoverInfo(
            title: "硬件状态",
            subtitle: "CPU \(percentText(snapshot.cpuUsagePercent)) · 内存 \(percentText(snapshot.memory.usedPercent))",
            symbolName: "cpu.fill",
            rows: [
                StatusHoverRow(label: "CPU", value: percentText(snapshot.cpuUsagePercent)),
                StatusHoverRow(label: "内存", value: "\(byteText(snapshot.memory.usedBytes)) / \(byteText(snapshot.memory.totalBytes))"),
                StatusHoverRow(label: "电池", value: battery),
                StatusHoverRow(label: "热状态", value: thermalStateText(snapshot.thermalState)),
                StatusHoverRow(label: "GPU", value: snapshot.gpu.name ?? "未识别"),
                StatusHoverRow(label: "温度", value: temperatures),
                StatusHoverRow(label: "风扇", value: fans)
            ],
            footer: "采样于 \(shortTimeText(snapshot.capturedAt))"
        )
    }

    private func countdownHoverInfo() -> StatusHoverInfo {
        let snapshot = currentCountdownSnapshot()
        let reminderColor = CountdownReminderColor.color(for: countdownPreferences.reminderColorID)
        return StatusHoverInfo(
            title: "倒计时",
            subtitle: countdownTooltip(for: snapshot),
            symbolName: countdownSymbolName(for: snapshot.state),
            rows: [
                StatusHoverRow(label: "状态", value: countdownStateText(snapshot.state)),
                StatusHoverRow(label: "剩余", value: countdownTimeText(snapshot.remainingSeconds)),
                StatusHoverRow(label: "总时长", value: countdownTimeText(snapshot.totalSeconds)),
                StatusHoverRow(label: "提醒提前", value: countdownTimeText(countdownPreferences.reminderLeadSeconds)),
                StatusHoverRow(label: "提醒色", value: reminderColor.title)
            ]
        )
    }

    private func targetTimeCountdownHoverInfo() -> StatusHoverInfo {
        let snapshot = targetTimeCountdownPreferences.snapshot()
        let background = TargetTimeCountdownBackgroundColor.color(for: targetTimeCountdownPreferences.backgroundColorID)
        return StatusHoverInfo(
            title: "目标倒计",
            subtitle: targetTimeCountdownSubtitle(for: snapshot),
            symbolName: targetTimeCountdownSymbolName(for: snapshot),
            rows: [
                StatusHoverRow(label: "目标", value: targetTimeCountdownDisplayTitle(for: snapshot)),
                StatusHoverRow(label: "目标时间", value: targetTimeCountdownTimeText(hour: snapshot.targetHour, minute: snapshot.targetMinute)),
                StatusHoverRow(label: "剩余分钟", value: "\(snapshot.minutesRemaining) 分钟"),
                StatusHoverRow(label: "过点处理", value: snapshot.pastBehavior.title),
                StatusHoverRow(label: "背景色", value: background.title),
                StatusHoverRow(label: "图标", value: targetTimeCountdownPreferences.showsIcon ? "显示" : "隐藏"),
                StatusHoverRow(label: "状态", value: snapshot.isPastTodayTarget ? "今天已过目标时间" : "尚未到目标时间")
            ]
        )
    }

    private func systemReminderHoverInfo() -> StatusHoverInfo {
        let snapshot = systemReminderPreferences.snapshot()
        let subtitle = systemReminderStatusSubtitle(for: snapshot)
        var rows = [
            StatusHoverRow(label: "状态", value: snapshot.isEnabled ? "已启用" : "未启用"),
            StatusHoverRow(label: "注册状态", value: systemReminderRegistrationStatusText),
            StatusHoverRow(label: "模式", value: snapshot.mode.title),
            StatusHoverRow(label: "标题", value: snapshot.title)
        ]

        if snapshot.isEnabled {
            rows.append(StatusHoverRow(label: "下次提醒", value: snapshot.nextFireDate.map(systemReminderDateText) ?? "已过期"))
            rows.append(StatusHoverRow(label: "内容", value: snapshot.message))
        } else {
            rows.append(StatusHoverRow(label: "时间", value: systemReminderScheduledText(for: snapshot)))
        }

        return StatusHoverInfo(
            title: "系统提醒",
            subtitle: subtitle,
            symbolName: systemReminderSymbolName(for: snapshot),
            rows: rows
        )
    }

    private func sleepHoverInfo() -> StatusHoverInfo {
        let title = sleepPreventer.isEnabled ? "已开启" : "已关闭"
        let preference = sleepPreventionPreferences.isEnabled ? "开启" : "关闭"
        var rows = [
            StatusHoverRow(label: "运行状态", value: title),
            StatusHoverRow(label: "偏好设置", value: preference)
        ]

        if let powerAssertionErrorMessage {
            rows.append(StatusHoverRow(label: "提示", value: powerAssertionErrorMessage))
        }

        return StatusHoverInfo(
            title: "防休眠",
            subtitle: sleepPreventer.isEnabled ? "正在保持 Mac 活跃" : "未阻止系统睡眠",
            symbolName: sleepPreventer.isEnabled ? "sun.max.fill" : "moon.zzz.fill",
            rows: rows
        )
    }

    private func weatherSnapshotStatusText(_ snapshot: WeatherServiceSnapshot) -> String {
        switch snapshot {
        case .idle:
            return "尚未开始"
        case .waitingForPermission:
            return "等待定位权限"
        case .locating:
            return "定位中"
        case .loading:
            return "更新中"
        case .forecast:
            return "已更新"
        case let .failed(message, _):
            return "更新失败：\(message)"
        case .permissionDenied:
            return "定位权限未开启"
        case let .locationUnavailable(message):
            return message
        }
    }

    private func countdownStateText(_ state: CountdownRunState) -> String {
        switch state {
        case .idle:
            return "未开始"
        case .running:
            return "运行中"
        case .paused:
            return "已暂停"
        case .finished:
            return "已完成"
        }
    }

    private func shortDateTimeText(_ date: Date) -> String {
        DateFormatter.localizedString(from: date, dateStyle: .none, timeStyle: .medium)
    }

    private func shortTimeText(_ date: Date) -> String {
        DateFormatter.localizedString(from: date, dateStyle: .none, timeStyle: .short)
    }

    private func updateCountdownDisplay(_ snapshot: CountdownSnapshot? = nil) {
        guard let button = countdownStatusItem.button else {
            return
        }

        let snapshot = snapshot ?? currentCountdownSnapshot()
        let title = countdownStatusTitle(for: snapshot)
        let tooltip = countdownTooltip(for: snapshot)
        button.title = title
        button.image = statusSymbol(
            named: countdownSymbolName(for: snapshot.state),
            fallback: "timer",
            description: tooltip
        )
        button.toolTip = tooltip
        button.setAccessibilityLabel(tooltip)
        applyCountdownBackground(to: button, snapshot: snapshot)
    }

    private func applyCountdownBackground(to button: NSStatusBarButton, snapshot: CountdownSnapshot) {
        let isReminderActive = countdownPreferences.isReminderActive(for: snapshot)
        button.wantsLayer = true
        button.layer?.cornerRadius = 5
        button.layer?.masksToBounds = true

        if isReminderActive {
            let color = CountdownReminderColor.color(for: countdownPreferences.reminderColorID)
            button.layer?.backgroundColor = color.color.withAlphaComponent(0.82).cgColor
            let font = button.font ?? NSFont.monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
            button.attributedTitle = NSAttributedString(string: button.title, attributes: [
                .font: font,
                .foregroundColor: color.foregroundColor
            ])
        } else {
            button.layer?.backgroundColor = NSColor.clear.cgColor
            button.attributedTitle = NSAttributedString(string: "")
        }
    }

    private func countdownStatusTitle(for snapshot: CountdownSnapshot) -> String {
        switch snapshot.state {
        case .idle, .running:
            return countdownTimeText(snapshot.remainingSeconds)
        case .paused:
            return "暂停 \(countdownTimeText(snapshot.remainingSeconds))"
        case .finished:
            return "完成"
        }
    }

    private func countdownTooltip(for snapshot: CountdownSnapshot) -> String {
        switch snapshot.state {
        case .idle:
            return "倒计时：\(countdownTimeText(snapshot.remainingSeconds))，未开始"
        case .running:
            return "倒计时：剩余 \(countdownTimeText(snapshot.remainingSeconds))"
        case .paused:
            return "倒计时：已暂停，剩余 \(countdownTimeText(snapshot.remainingSeconds))"
        case .finished:
            return "倒计时：已完成"
        }
    }

    private func countdownSymbolName(for state: CountdownRunState) -> String {
        switch state {
        case .idle, .running:
            return "timer"
        case .paused:
            return "pause.circle.fill"
        case .finished:
            return "checkmark.circle.fill"
        }
    }

    private func countdownTimeText(_ seconds: Int) -> String {
        let safeSeconds = max(0, seconds)
        if safeSeconds >= 3_600 {
            return String(format: "%d:%02d:%02d", safeSeconds / 3_600, (safeSeconds % 3_600) / 60, safeSeconds % 60)
        }
        return String(format: "%d:%02d", safeSeconds / 60, safeSeconds % 60)
    }

    private func updateTargetTimeCountdownDisplay() {
        guard let button = targetTimeCountdownStatusItem.button else {
            return
        }

        let snapshot = targetTimeCountdownPreferences.snapshot()
        let tooltip = "目标倒计：\(targetTimeCountdownSubtitle(for: snapshot))"
        let title = targetTimeCountdownStatusTitle(for: snapshot)
        button.title = title
        if targetTimeCountdownPreferences.showsIcon {
            button.imagePosition = .imageLeading
            button.image = statusSymbol(
                named: targetTimeCountdownSymbolName(for: snapshot),
                fallback: "clock.fill",
                description: tooltip
            )
        } else {
            button.imagePosition = .noImage
            button.image = nil
        }
        button.toolTip = tooltip
        button.setAccessibilityLabel(tooltip)
        applyTargetTimeCountdownStyle(to: button, title: title)
        settingsWindowController?.updateTargetTimeCountdownStatus()
    }

    private func applyTargetTimeCountdownStyle(to button: NSStatusBarButton, title: String) {
        let background = TargetTimeCountdownBackgroundColor.color(for: targetTimeCountdownPreferences.backgroundColorID)
        let textColor = TargetTimeCountdownTextColor.color(for: targetTimeCountdownPreferences.textColorID)
        let font = NSFont.monospacedDigitSystemFont(
            ofSize: NSFont.systemFontSize,
            weight: targetTimeCountdownPreferences.textWeight.fontWeight
        )

        button.wantsLayer = true
        button.layer?.cornerRadius = 5
        button.layer?.masksToBounds = true
        button.font = font

        if let color = background.color {
            button.layer?.backgroundColor = color.withAlphaComponent(0.82).cgColor
        } else {
            button.layer?.backgroundColor = NSColor.clear.cgColor
        }

        let foregroundColor = textColor.color ?? background.foregroundColor ?? NSColor.labelColor
        button.attributedTitle = NSAttributedString(string: title, attributes: [
            .font: font,
            .foregroundColor: foregroundColor
        ])
    }

    private func targetTimeCountdownStatusTitle(for snapshot: TargetTimeCountdownSnapshot) -> String {
        let remaining = "\(snapshot.minutesRemaining)分"
        guard !snapshot.title.isEmpty else {
            return remaining
        }
        return "\(snapshot.title) \(remaining)"
    }

    private func targetTimeCountdownDisplayTitle(for snapshot: TargetTimeCountdownSnapshot) -> String {
        snapshot.title.isEmpty ? "未设置名称" : snapshot.title
    }

    private func targetTimeCountdownSubtitle(for snapshot: TargetTimeCountdownSnapshot) -> String {
        let target = targetTimeCountdownTimeText(hour: snapshot.targetHour, minute: snapshot.targetMinute)
        let targetPrefix = snapshot.title.isEmpty ? target : "\(snapshot.title) \(target)"
        if snapshot.isPastTodayTarget, snapshot.pastBehavior == .showZero {
            return "\(targetPrefix) 已过，显示 0 分钟"
        }
        return "距离 \(targetPrefix) 还有 \(snapshot.minutesRemaining) 分钟"
    }

    private func targetTimeCountdownSymbolName(for snapshot: TargetTimeCountdownSnapshot) -> String {
        if snapshot.minutesRemaining == 0 {
            return "checkmark.circle.fill"
        }
        return snapshot.isPastTodayTarget ? "clock.arrow.circlepath" : "clock.fill"
    }

    private func targetTimeCountdownTimeText(hour: Int, minute: Int) -> String {
        String(format: "%02d:%02d", hour, minute)
    }

    private func updateSystemReminderDisplay() {
        guard let button = systemReminderStatusItem.button else {
            return
        }

        let snapshot = systemReminderPreferences.snapshot()
        let tooltip = "系统提醒：\(systemReminderStatusSubtitle(for: snapshot))"
        button.title = systemReminderStatusTitle(for: snapshot)
        button.image = statusSymbol(
            named: systemReminderSymbolName(for: snapshot),
            fallback: "bell.fill",
            description: tooltip
        )
        button.toolTip = tooltip
        button.setAccessibilityLabel(tooltip)
        settingsWindowController?.updateSystemReminderStatus(registrationStatus: systemReminderRegistrationStatusText)
    }

    private func systemReminderStatusTitle(for snapshot: SystemReminderSnapshot) -> String {
        guard snapshot.isEnabled else {
            return "提醒 关闭"
        }
        guard let nextFireDate = snapshot.nextFireDate else {
            return "提醒 过期"
        }

        switch snapshot.mode {
        case .once:
            return "提醒 \(systemReminderStatusDateText(nextFireDate))"
        case .daily:
            return "每日 \(systemReminderTimeText(nextFireDate))"
        }
    }

    private func systemReminderStatusSubtitle(for snapshot: SystemReminderSnapshot) -> String {
        guard snapshot.isEnabled else {
            return "未启用"
        }
        guard let nextFireDate = snapshot.nextFireDate else {
            return "单次提醒时间已过期"
        }

        return "\(snapshot.mode.title) · \(systemReminderDateText(nextFireDate))"
    }

    private func systemReminderScheduledText(for snapshot: SystemReminderSnapshot) -> String {
        switch snapshot.mode {
        case .once:
            return systemReminderDateText(snapshot.scheduledDate)
        case .daily:
            return "每日 \(systemReminderTimeText(snapshot.scheduledDate))"
        }
    }

    private func systemReminderSymbolName(for snapshot: SystemReminderSnapshot) -> String {
        guard snapshot.isEnabled else {
            return "bell.slash.fill"
        }
        if snapshot.nextFireDate == nil {
            return "exclamationmark.bell.fill"
        }
        return snapshot.mode == .daily ? "bell.badge.fill" : "bell.fill"
    }

    private func systemReminderDateText(_ date: Date) -> String {
        DateFormatter.localizedString(from: date, dateStyle: .short, timeStyle: .short)
    }

    private func systemReminderStatusDateText(_ date: Date) -> String {
        if Calendar.current.isDateInToday(date) {
            return systemReminderTimeText(date)
        }
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.dateFormat = "M/d HH:mm"
        return formatter.string(from: date)
    }

    private func systemReminderTimeText(_ date: Date) -> String {
        DateFormatter.localizedString(from: date, dateStyle: .none, timeStyle: .short)
    }

    private func refreshHardwareIfNeeded(force: Bool = false) {
        guard force || shouldRefreshHardware() else {
            return
        }
        guard !isHardwareRefreshInFlight else {
            return
        }

        isHardwareRefreshInFlight = true
        hardwareQueue.async { [weak self] in
            guard let self else {
                return
            }
            let snapshot = self.hardwareMonitor.snapshot()
            DispatchQueue.main.async {
                self.hardwareSnapshot = snapshot
                self.lastHardwareRefreshAt = Date()
                self.isHardwareRefreshInFlight = false
                self.settingsWindowController?.updateHardwareSnapshot(snapshot)
                self.refresh()
            }
        }
    }

    private func shouldRefreshHardware() -> Bool {
        guard let lastHardwareRefreshAt else {
            return true
        }
        return Date().timeIntervalSince(lastHardwareRefreshAt) >= hardwareRefreshInterval
    }

    private func updateWeatherDisplay() {
        let snapshot = weatherService.snapshot
        if let forecast = snapshot.forecast {
            updateWeatherStatusButton(with: forecast)
            populateWeatherMenus(with: forecast)

            let current = forecast.current
            let apparentText = current.apparentTemperature.map { "，体感 \(temperatureText($0))" } ?? ""
            let humidityText = current.humidity.map { "，湿度 \(Int(round($0)))%" } ?? ""
            let windText = current.windSpeed.map { "，风速 \(Int(round($0))) km/h" } ?? ""
            weatherSummaryMenuItem.title = "天气：\(current.condition.title) \(temperatureText(current.temperature))\(apparentText)\(humidityText)\(windText)"
            weatherUpdatedMenuItem.title = weatherUpdatedTitle(for: forecast.fetchedAt, snapshot: snapshot)
            return
        }

        clearWeatherMenus()
        switch snapshot {
        case .idle, .waitingForPermission:
            weatherSummaryMenuItem.title = "天气：等待定位权限"
            weatherUpdatedMenuItem.title = "更新：暂无"
            updateWeatherStatusButton(title: "--°", symbolName: "location.fill", tooltip: "天气：等待定位权限")
        case .locating:
            weatherSummaryMenuItem.title = "天气：定位中"
            weatherUpdatedMenuItem.title = "更新：暂无"
            updateWeatherStatusButton(title: "--°", symbolName: "location.fill", tooltip: "天气：定位中")
        case .loading:
            weatherSummaryMenuItem.title = "天气：更新中"
            weatherUpdatedMenuItem.title = "更新：正在请求天气"
            updateWeatherStatusButton(title: "--°", symbolName: "arrow.clockwise", tooltip: "天气：更新中")
        case .permissionDenied:
            weatherSummaryMenuItem.title = "天气：需要开启定位权限"
            weatherUpdatedMenuItem.title = "更新：暂无"
            updateWeatherStatusButton(title: "--°", symbolName: "location.slash.fill", tooltip: "天气：需要开启定位权限")
        case let .failed(message, _):
            weatherSummaryMenuItem.title = "天气：更新失败 — \(message)"
            weatherUpdatedMenuItem.title = "更新：失败"
            updateWeatherStatusButton(title: "--°", symbolName: "exclamationmark.triangle.fill", tooltip: "天气：更新失败")
        case let .locationUnavailable(message):
            weatherSummaryMenuItem.title = "天气：\(message)"
            weatherUpdatedMenuItem.title = "更新：暂无"
            updateWeatherStatusButton(title: "--°", symbolName: "location.slash.fill", tooltip: "天气：\(message)")
        case .forecast:
            break
        }
    }

    private func updateWeatherStatusButton(with forecast: WeatherForecast) {
        let current = forecast.current
        updateWeatherStatusButton(
            title: "\(Int(round(current.temperature)))°",
            symbolName: current.condition.symbolName,
            tooltip: "天气：\(current.condition.title) \(temperatureText(current.temperature))"
        )
    }

    private func updateWeatherStatusButton(title: String, symbolName: String, tooltip: String) {
        guard let button = weatherStatusItem.button else {
            return
        }

        button.title = title
        button.image = statusSymbol(named: symbolName, fallback: "cloud.fill", description: tooltip)
        button.toolTip = tooltip
        button.setAccessibilityLabel(tooltip)
    }

    private func populateWeatherMenus(with forecast: WeatherForecast) {
        hourlyForecastMenu.removeAllItems()
        if forecast.hourly.isEmpty {
            let item = NSMenuItem(title: "暂无小时预报", action: nil, keyEquivalent: "")
            item.isEnabled = false
            hourlyForecastMenu.addItem(item)
        } else {
            for hour in forecast.hourly {
                let precipitation = hour.precipitationProbability.map { " · 降雨 \($0)%" } ?? ""
                let item = NSMenuItem(
                    title: "\(hourLabel(from: hour.time)) · \(hour.condition.title) · \(temperatureText(hour.temperature))\(precipitation)",
                    action: nil,
                    keyEquivalent: ""
                )
                item.isEnabled = false
                hourlyForecastMenu.addItem(item)
            }
        }

        dailyForecastMenu.removeAllItems()
        if forecast.daily.isEmpty {
            let item = NSMenuItem(title: "暂无 7 天预报", action: nil, keyEquivalent: "")
            item.isEnabled = false
            dailyForecastMenu.addItem(item)
        } else {
            for (index, day) in forecast.daily.enumerated() {
                let precipitation = day.precipitationProbability.map { " · 降雨 \($0)%" } ?? ""
                let item = NSMenuItem(
                    title: "\(dayLabel(from: day.date, index: index)) · \(day.condition.title) · \(temperatureText(day.minTemperature)) / \(temperatureText(day.maxTemperature))\(precipitation)",
                    action: nil,
                    keyEquivalent: ""
                )
                item.isEnabled = false
                dailyForecastMenu.addItem(item)
            }
        }

        weatherHourlyForecastMenuItem.isEnabled = true
        weatherDailyForecastMenuItem.isEnabled = true
    }

    private func clearWeatherMenus() {
        populateEmptyWeatherMenu(hourlyForecastMenu, title: "暂无小时预报")
        populateEmptyWeatherMenu(dailyForecastMenu, title: "暂无 7 天预报")
        weatherHourlyForecastMenuItem.isEnabled = false
        weatherDailyForecastMenuItem.isEnabled = false
    }

    private func populateEmptyWeatherMenu(_ menu: NSMenu, title: String) {
        menu.removeAllItems()
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        menu.addItem(item)
    }

    private func updateHardwareDisplay(with snapshot: HardwareStatusSnapshot) {
        let cpuText = percentText(snapshot.cpuUsagePercent)
        let memoryText = percentText(snapshot.memory.usedPercent)
        let batteryText = snapshot.battery.map { "\($0.percent)%" } ?? "无电池"
        let cpuTempText = snapshot.cpuTemperature.map { temperatureText($0.celsius) } ?? "温度不可用"

        hardwareSummaryMenuItem.title = "硬件：CPU \(cpuText) · 内存 \(memoryText) · 电池 \(batteryText)"
        hardwareCPUMenuItem.title = "CPU：\(cpuText) · \(cpuTempText)"
        hardwareMemoryMenuItem.title = "内存：\(byteText(snapshot.memory.usedBytes)) / \(byteText(snapshot.memory.totalBytes))（\(memoryText)）"
        hardwareBatteryMenuItem.title = batteryMenuTitle(snapshot.battery)
        hardwareThermalMenuItem.title = "热状态：\(thermalStateText(snapshot.thermalState))"
        hardwareGPUMenuItem.title = gpuMenuTitle(snapshot.gpu, temperature: snapshot.gpuTemperature)

        populateHardwareTemperatures(snapshot.temperatures)
        populateHardwareFans(snapshot.fans)
        updateHardwareStatusButton(with: snapshot)
    }

    private func updateHardwarePendingDisplay() {
        hardwareSummaryMenuItem.title = "硬件：检测中"
        hardwareCPUMenuItem.title = "CPU：检测中"
        hardwareMemoryMenuItem.title = "内存：检测中"
        hardwareBatteryMenuItem.title = "电池：检测中"
        hardwareThermalMenuItem.title = "热状态：检测中"
        hardwareGPUMenuItem.title = "GPU：检测中"
        populateHardwareTemperatures([])
        populateHardwareFans([])

        guard let button = hardwareStatusItem.button else {
            return
        }
        let metric = hardwareStatusBarPreferences.metric
        button.title = metric.pendingTitle
        button.image = statusSymbol(named: metric.symbolName, fallback: metric.fallbackSymbolName, description: "硬件：检测中")
        button.toolTip = "硬件：检测中"
        button.setAccessibilityLabel("硬件：检测中")
    }

    private func updateHardwareStatusButton(with snapshot: HardwareStatusSnapshot) {
        guard let button = hardwareStatusItem.button else {
            return
        }

        let metric = hardwareStatusBarPreferences.metric
        let presentation = hardwareStatusBarPresentation(for: snapshot, metric: metric)
        let tooltip = "状态栏：\(metric.title) · \(presentation.title)\n\(fullHardwareTooltip(snapshot))"
        button.title = presentation.title
        button.image = statusSymbol(named: metric.symbolName, fallback: metric.fallbackSymbolName, description: tooltip)
        button.toolTip = tooltip
        button.setAccessibilityLabel(tooltip)
    }

    private func hardwareStatusBarPresentation(
        for snapshot: HardwareStatusSnapshot,
        metric: HardwareStatusBarMetric
    ) -> HardwareStatusBarPresentation {
        switch metric {
        case .cpuUsage:
            return HardwareStatusBarPresentation(title: "CPU \(percentText(snapshot.cpuUsagePercent))")
        case .memoryUsage:
            return HardwareStatusBarPresentation(title: "内存 \(percentText(snapshot.memory.usedPercent))")
        case .batteryLevel:
            let title = snapshot.battery.map { "电池 \($0.percent)%" } ?? "无电池"
            return HardwareStatusBarPresentation(title: title)
        case .thermalState:
            return HardwareStatusBarPresentation(title: "热 \(thermalStateText(snapshot.thermalState))")
        case .cpuTemperature:
            let title = snapshot.cpuTemperature.map { "CPU \(temperatureText($0.celsius))" } ?? "CPU --°"
            return HardwareStatusBarPresentation(title: title)
        case .gpuTemperature:
            let title = snapshot.gpuTemperature.map { "GPU \(temperatureText($0.celsius))" } ?? "GPU --°"
            return HardwareStatusBarPresentation(title: title)
        case .fanSpeed:
            let title = snapshot.fans.first.map { "风扇 \(Int(round($0.rpm)))" } ?? "风扇 --"
            return HardwareStatusBarPresentation(title: title)
        }
    }

    private func populateHardwareTemperatures(_ temperatures: [TemperatureReading]) {
        hardwareTemperaturesMenu.removeAllItems()
        guard !temperatures.isEmpty else {
            let item = NSMenuItem(title: "SMC 温度传感器不可用", action: nil, keyEquivalent: "")
            item.isEnabled = false
            hardwareTemperaturesMenu.addItem(item)
            return
        }

        for reading in temperatures {
            let item = NSMenuItem(title: "\(reading.name)：\(temperatureText(reading.celsius))", action: nil, keyEquivalent: "")
            item.isEnabled = false
            hardwareTemperaturesMenu.addItem(item)
        }
    }

    private func populateHardwareFans(_ fans: [FanStatus]) {
        hardwareFansMenu.removeAllItems()
        guard !fans.isEmpty else {
            let item = NSMenuItem(title: "未检测到风扇或 SMC 风扇数据不可用", action: nil, keyEquivalent: "")
            item.isEnabled = false
            hardwareFansMenu.addItem(item)
            return
        }

        for fan in fans {
            let item = NSMenuItem(title: "\(fan.name)：\(Int(round(fan.rpm))) RPM", action: nil, keyEquivalent: "")
            item.isEnabled = false
            hardwareFansMenu.addItem(item)
        }
    }

    private func batteryMenuTitle(_ battery: BatteryStatus?) -> String {
        guard let battery else {
            return "电池：未检测到"
        }

        let charging = battery.isCharging ? "，正在充电" : ""
        let remaining = battery.timeRemainingMinutes.map { "，剩余 \(durationText(minutes: $0))" } ?? ""
        return "电池：\(battery.percent)% · \(battery.powerSource.title)\(charging)\(remaining)"
    }

    private func gpuMenuTitle(_ gpu: GPUStatus, temperature: TemperatureReading?) -> String {
        let name = gpu.name ?? "GPU"
        let temp = temperature.map { " · \(temperatureText($0.celsius))" } ?? ""
        let usage = gpu.usagePercent.map { " · 使用率 \(percentText($0))" } ?? ""
        return "GPU：\(name)\(usage)\(temp)"
    }

    private func thermalStateText(_ state: ProcessInfo.ThermalState) -> String {
        switch state {
        case .nominal:
            return "正常"
        case .fair:
            return "偏热"
        case .serious:
            return "较热"
        case .critical:
            return "严重"
        @unknown default:
            return "未知"
        }
    }

    private func percentText(_ value: Double?) -> String {
        guard let value else {
            return "--%"
        }
        return "\(Int(round(value)))%"
    }

    private func byteText(_ bytes: UInt64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB]
        formatter.countStyle = .memory
        return formatter.string(fromByteCount: Int64(bytes))
    }

    private func durationText(minutes: Int) -> String {
        if minutes >= 60 {
            return "\(minutes / 60) 小时 \(minutes % 60) 分钟"
        }
        return "\(minutes) 分钟"
    }

    private func fullHardwareTooltip(_ snapshot: HardwareStatusSnapshot) -> String {
        var lines = [
            "硬件状态",
            "CPU：\(percentText(snapshot.cpuUsagePercent))" + (snapshot.cpuTemperature.map { " · \(temperatureText($0.celsius))" } ?? ""),
            "内存：\(byteText(snapshot.memory.usedBytes)) / \(byteText(snapshot.memory.totalBytes))（\(percentText(snapshot.memory.usedPercent))）",
            batteryMenuTitle(snapshot.battery),
            "热状态：\(thermalStateText(snapshot.thermalState))",
            gpuMenuTitle(snapshot.gpu, temperature: snapshot.gpuTemperature)
        ]

        if snapshot.temperatures.isEmpty {
            lines.append("温度：SMC 传感器不可用")
        } else {
            lines.append("温度：" + snapshot.temperatures.map { "\($0.name) \(temperatureText($0.celsius))" }.joined(separator: "，"))
        }

        if snapshot.fans.isEmpty {
            lines.append("风扇：未检测到或不可用")
        } else {
            lines.append("风扇：" + snapshot.fans.map { "\($0.name) \(Int(round($0.rpm))) RPM" }.joined(separator: "，"))
        }

        return lines.joined(separator: "\n")
    }

    private func updateSleepStatusItem() {
        guard let button = sleepStatusItem.button else {
            return
        }

        let title = sleepPreventer.isEnabled ? "防休眠：已开启" : "防休眠：已关闭"
        button.image = statusSymbol(
            named: sleepPreventer.isEnabled ? "sun.max.fill" : "moon.zzz.fill",
            fallback: "power",
            description: title
        )
        button.toolTip = title
        button.setAccessibilityLabel(title)
    }

    private func syncStatusBarItemsVisibility() {
        if !statusBarDisplayPreferences.hasVisibleModule {
            statusBarDisplayPreferences.setVisible(true, for: .gpt)
            statusBarDisplayErrorMessage = "至少保留一个状态栏项目"
        }

        statusItem.isVisible = statusBarDisplayPreferences.isVisible(.gpt)
        claudeStatusItem.isVisible = statusBarDisplayPreferences.isVisible(.claude)
        weatherStatusItem.isVisible = statusBarDisplayPreferences.isVisible(.weather)
        hardwareStatusItem.isVisible = statusBarDisplayPreferences.isVisible(.hardware)
        countdownStatusItem.isVisible = statusBarDisplayPreferences.isVisible(.countdown)
        targetTimeCountdownStatusItem.isVisible = statusBarDisplayPreferences.isVisible(.targetTimeCountdown)
        systemReminderStatusItem.isVisible = statusBarDisplayPreferences.isVisible(.systemReminder)
        sleepStatusItem.isVisible = statusBarDisplayPreferences.isVisible(.sleep)
    }

    private func statusSymbol(named name: String, fallback: String, description: String) -> NSImage? {
        let image = NSImage(systemSymbolName: name, accessibilityDescription: description)
            ?? NSImage(systemSymbolName: fallback, accessibilityDescription: description)
        image?.isTemplate = true
        return image
    }

    private func weatherUpdatedTitle(for date: Date, snapshot: WeatherServiceSnapshot) -> String {
        let time = DateFormatter.localizedString(from: date, dateStyle: .none, timeStyle: .short)
        switch snapshot {
        case .loading:
            return "更新：\(time)，正在刷新"
        case let .failed(message, _):
            return "更新：\(time)，刷新失败 — \(message)"
        default:
            return "更新：\(time)"
        }
    }

    private func temperatureText(_ value: Double) -> String {
        "\(Int(round(value)))°C"
    }

    private func hourLabel(from time: String) -> String {
        guard let timePart = time.split(separator: "T").last else {
            return time
        }
        return String(timePart.prefix(5))
    }

    private func dayLabel(from date: String, index: Int) -> String {
        if index == 0 {
            return "今天"
        }
        if index == 1 {
            return "明天"
        }

        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy-MM-dd"

        guard let parsedDate = formatter.date(from: date) else {
            return date
        }

        formatter.dateFormat = "EEEE"
        return formatter.string(from: parsedDate)
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
                    self?.systemReminderRegistrationStatusText = "通知权限请求失败"
                } else if !granted {
                    self?.notificationErrorMessage = "没有通知权限，无法发送系统提醒或会话结束提示"
                    self?.systemReminderRegistrationStatusText = "未授权通知"
                } else {
                    self?.notificationErrorMessage = nil
                    if self?.systemReminderPreferences.isEnabled == true {
                        self?.scheduleSystemReminderNotification()
                    } else {
                        self?.systemReminderRegistrationStatusText = "未启用"
                    }
                }
                self?.refresh()
            }
        }
    }

    private func scheduleSystemReminderNotification() {
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [systemReminderRequestIdentifier])
        guard systemReminderPreferences.isEnabled else {
            systemReminderRegistrationStatusText = "未启用"
            settingsWindowController?.updateSystemReminderStatus(registrationStatus: systemReminderRegistrationStatusText)
            return
        }

        systemReminderRegistrationStatusText = "正在注册"
        settingsWindowController?.updateSystemReminderStatus(registrationStatus: systemReminderRegistrationStatusText)

        notificationCenter.getNotificationSettings { [weak self] settings in
            guard let self else {
                return
            }

            switch settings.authorizationStatus {
            case .notDetermined:
                self.notificationCenter.requestAuthorization(options: [.alert, .sound]) { granted, error in
                    DispatchQueue.main.async {
                        if let error {
                            self.notificationErrorMessage = "通知权限请求失败：\(error.localizedDescription)"
                            self.systemReminderRegistrationStatusText = "通知权限请求失败"
                            self.refresh()
                        } else if granted {
                            self.addSystemReminderNotification()
                        } else {
                            self.notificationErrorMessage = "没有通知权限，无法发送系统提醒"
                            self.systemReminderRegistrationStatusText = "未授权通知"
                            self.refresh()
                        }
                    }
                }
            case .authorized, .provisional:
                DispatchQueue.main.async {
                    self.addSystemReminderNotification()
                }
            case .denied:
                DispatchQueue.main.async {
                    self.notificationErrorMessage = "没有通知权限，无法发送系统提醒"
                    self.systemReminderRegistrationStatusText = "未授权通知"
                    self.refresh()
                }
            @unknown default:
                DispatchQueue.main.async {
                    self.notificationErrorMessage = "当前通知权限状态不支持发送系统提醒"
                    self.systemReminderRegistrationStatusText = "通知权限状态异常"
                    self.refresh()
                }
            }
        }
    }

    private func addSystemReminderNotification() {
        guard let request = systemReminderNotificationRequest() else {
            notificationErrorMessage = "系统提醒时间已过期，请重新选择未来时间"
            systemReminderRegistrationStatusText = "提醒时间已过期"
            refresh()
            return
        }

        notificationCenter.add(request) { [weak self] error in
            DispatchQueue.main.async {
                if let error {
                    self?.notificationErrorMessage = "系统提醒设置失败：\(error.localizedDescription)"
                    self?.systemReminderRegistrationStatusText = "注册失败"
                    self?.refresh()
                    return
                }

                self?.verifySystemReminderRegistration(for: request)
            }
        }
    }

    private func verifySystemReminderRegistration(for request: UNNotificationRequest) {
        notificationCenter.getPendingNotificationRequests { [weak self] requests in
            guard let self else {
                return
            }

            let isRegistered = requests.contains { $0.identifier == request.identifier }
            let status = isRegistered
                ? self.systemReminderRegisteredText(for: request)
                : "未在系统待发送列表中"

            DispatchQueue.main.async {
                self.systemReminderRegistrationStatusText = status
                if isRegistered, self.notificationErrorMessage?.hasPrefix("系统提醒") == true {
                    self.notificationErrorMessage = nil
                }
                self.refresh()
            }
        }
    }

    private func systemReminderNotificationRequest() -> UNNotificationRequest? {
        let snapshot = systemReminderPreferences.snapshot()
        guard snapshot.isEnabled else {
            return nil
        }

        let trigger: UNNotificationTrigger
        switch snapshot.mode {
        case .once:
            guard let nextFireDate = snapshot.nextFireDate else {
                return nil
            }
            let interval = max(1, nextFireDate.timeIntervalSinceNow)
            trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        case .daily:
            var components = Calendar.current.dateComponents([.hour, .minute], from: snapshot.scheduledDate)
            components.second = 0
            trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        }

        let content = UNMutableNotificationContent()
        content.title = snapshot.title
        content.body = snapshot.message
        content.sound = .default
        content.userInfo = [
            "mode": snapshot.mode.rawValue,
            "scheduledDate": snapshot.scheduledDate.timeIntervalSince1970
        ]

        return UNNotificationRequest(
            identifier: systemReminderRequestIdentifier,
            content: content,
            trigger: trigger
        )
    }

    private func systemReminderRegisteredText(for request: UNNotificationRequest) -> String {
        let nextDate: Date?
        if let trigger = request.trigger as? UNTimeIntervalNotificationTrigger {
            nextDate = trigger.nextTriggerDate()
        } else if let trigger = request.trigger as? UNCalendarNotificationTrigger {
            nextDate = trigger.nextTriggerDate()
        } else {
            nextDate = nil
        }

        if let nextDate {
            return "已注册，\(systemReminderDateText(nextDate)) 触发"
        }
        return "已注册"
    }

    private func sendSystemReminderTestNotification() {
        notificationCenter.getNotificationSettings { [weak self] settings in
            guard let self else {
                return
            }

            switch settings.authorizationStatus {
            case .notDetermined:
                self.notificationCenter.requestAuthorization(options: [.alert, .sound]) { granted, error in
                    DispatchQueue.main.async {
                        if let error {
                            self.notificationErrorMessage = "通知权限请求失败：\(error.localizedDescription)"
                            self.refresh()
                        } else if granted {
                            self.addImmediateSystemReminderTestNotification()
                        } else {
                            self.notificationErrorMessage = "没有通知权限，无法发送系统提醒测试"
                            self.systemReminderRegistrationStatusText = "未授权通知"
                            self.refresh()
                        }
                    }
                }
            case .authorized, .provisional:
                DispatchQueue.main.async {
                    self.addImmediateSystemReminderTestNotification()
                }
            case .denied:
                DispatchQueue.main.async {
                    self.notificationErrorMessage = "没有通知权限，无法发送系统提醒测试"
                    self.systemReminderRegistrationStatusText = "未授权通知"
                    self.refresh()
                }
            @unknown default:
                DispatchQueue.main.async {
                    self.notificationErrorMessage = "当前通知权限状态不支持发送系统提醒测试"
                    self.refresh()
                }
            }
        }
    }

    private func addImmediateSystemReminderTestNotification() {
        let content = UNMutableNotificationContent()
        content.title = "oneMenu 测试提醒"
        content.body = "如果看到这条通知，说明系统提醒权限和通知展示正常。"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "aistatus.systemReminder.test.\(UUID().uuidString)",
            content: content,
            trigger: nil
        )

        notificationCenter.add(request) { [weak self] error in
            DispatchQueue.main.async {
                if let error {
                    self?.notificationErrorMessage = "系统提醒测试失败：\(error.localizedDescription)"
                } else if self?.notificationErrorMessage?.hasPrefix("系统提醒测试") == true {
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

    private func updateSleepPreventionMenuCheck() {
        preventSleepMenuItem.state = sleepPreventer.isEnabled ? .on : .off
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

private struct StatusHoverInfo {
    let title: String
    let subtitle: String
    let symbolName: String
    let rows: [StatusHoverRow]
    var footer: String?
}

private struct StatusHoverRow {
    let label: String
    let value: String
}

private final class StatusHoverWindowController: NSWindowController {
    private let contentWidth: CGFloat = 320

    var isVisible: Bool {
        window?.isVisible == true
    }

    init() {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 180),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.hidesOnDeactivate = false
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .transient, .fullScreenAuxiliary, .ignoresCycle]
        super.init(window: panel)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show(info: StatusHoverInfo, anchoredTo button: NSStatusBarButton) {
        guard let panel = window,
              let buttonWindow = button.window
        else {
            return
        }

        let contentView = StatusHoverContentView(info: info, width: contentWidth)
        let size = contentView.preferredContentSize(width: contentWidth)
        panel.contentView = contentView
        panel.setContentSize(size)
        contentView.frame = NSRect(origin: .zero, size: size)
        panel.setFrameOrigin(frameOrigin(for: size, button: button, buttonWindow: buttonWindow))
        panel.orderFrontRegardless()
    }

    func hide() {
        window?.orderOut(nil)
    }

    private func frameOrigin(
        for size: NSSize,
        button: NSStatusBarButton,
        buttonWindow: NSWindow
    ) -> NSPoint {
        let buttonRect = button.convert(button.bounds, to: nil)
        let screenRect = buttonWindow.convertToScreen(buttonRect)
        let visibleFrame = (buttonWindow.screen ?? NSScreen.main)?.visibleFrame ?? screenRect

        let x = min(
            max(screenRect.midX - size.width / 2, visibleFrame.minX + 8),
            visibleFrame.maxX - size.width - 8
        )
        var y = screenRect.minY - size.height - 8
        if y < visibleFrame.minY + 8 {
            y = screenRect.maxY + 8
        }
        return NSPoint(x: x, y: y)
    }
}

private final class StatusHoverContentView: NSVisualEffectView {
    private enum Layout {
        static let horizontalInset: CGFloat = 16
        static let verticalInset: CGFloat = 14
        static let rowLabelWidth: CGFloat = 72
        static let maxHeight: CGFloat = 420
    }

    private let stack = NSStackView()

    init(info: StatusHoverInfo, width: CGFloat) {
        super.init(frame: NSRect(x: 0, y: 0, width: width, height: 1))
        material = .popover
        blendingMode = .behindWindow
        state = .active
        wantsLayer = true
        layer?.cornerRadius = 10
        layer?.masksToBounds = true

        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 9
        stack.edgeInsets = NSEdgeInsets(
            top: Layout.verticalInset,
            left: Layout.horizontalInset,
            bottom: Layout.verticalInset,
            right: Layout.horizontalInset
        )

        stack.addArrangedSubview(headerView(for: info, width: width))
        stack.setCustomSpacing(10, after: stack.arrangedSubviews.last!)
        for row in info.rows {
            stack.addArrangedSubview(rowView(row, width: width))
        }

        if let footer = info.footer {
            let footerLabel = secondaryLabel(footer, fontSize: 11)
            footerLabel.preferredMaxLayoutWidth = width - Layout.horizontalInset * 2
            footerLabel.widthAnchor.constraint(equalToConstant: width - Layout.horizontalInset * 2).isActive = true
            stack.setCustomSpacing(10, after: stack.arrangedSubviews.last!)
            stack.addArrangedSubview(footerLabel)
        }

        addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func preferredContentSize(width: CGFloat) -> NSSize {
        frame.size = NSSize(width: width, height: Layout.maxHeight)
        layoutSubtreeIfNeeded()
        let height = min(Layout.maxHeight, ceil(stack.fittingSize.height))
        return NSSize(width: width, height: max(86, height))
    }

    private func headerView(for info: StatusHoverInfo, width: CGFloat) -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 10
        row.widthAnchor.constraint(equalToConstant: width - Layout.horizontalInset * 2).isActive = true

        let imageView = NSImageView()
        let image = NSImage(systemSymbolName: info.symbolName, accessibilityDescription: info.title)
        image?.isTemplate = true
        imageView.image = image
        imageView.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 16, weight: .semibold)
        imageView.contentTintColor = .controlAccentColor
        imageView.widthAnchor.constraint(equalToConstant: 20).isActive = true
        imageView.heightAnchor.constraint(equalToConstant: 20).isActive = true

        let textStack = NSStackView()
        textStack.orientation = .vertical
        textStack.alignment = .leading
        textStack.spacing = 2

        let titleLabel = NSTextField(labelWithString: info.title)
        titleLabel.font = NSFont.systemFont(ofSize: 14, weight: .semibold)
        titleLabel.textColor = .labelColor
        titleLabel.lineBreakMode = .byTruncatingTail

        let subtitleLabel = secondaryLabel(info.subtitle, fontSize: 11.5)
        subtitleLabel.maximumNumberOfLines = 2

        textStack.addArrangedSubview(titleLabel)
        textStack.addArrangedSubview(subtitleLabel)
        textStack.setContentHuggingPriority(.defaultLow, for: .horizontal)

        row.addArrangedSubview(imageView)
        row.addArrangedSubview(textStack)
        return row
    }

    private func rowView(_ row: StatusHoverRow, width: CGFloat) -> NSView {
        let stack = NSStackView()
        stack.orientation = .horizontal
        stack.alignment = .top
        stack.spacing = 10
        stack.widthAnchor.constraint(equalToConstant: width - Layout.horizontalInset * 2).isActive = true

        let label = secondaryLabel(row.label, fontSize: 11)
        label.widthAnchor.constraint(equalToConstant: Layout.rowLabelWidth).isActive = true

        let value = NSTextField(labelWithString: row.value)
        value.font = NSFont.systemFont(ofSize: 12, weight: .regular)
        value.textColor = .labelColor
        value.lineBreakMode = .byTruncatingTail
        value.maximumNumberOfLines = 2
        value.preferredMaxLayoutWidth = width - Layout.horizontalInset * 2 - Layout.rowLabelWidth - 10
        value.setContentHuggingPriority(.defaultLow, for: .horizontal)

        stack.addArrangedSubview(label)
        stack.addArrangedSubview(value)
        return stack
    }

    private func secondaryLabel(_ text: String, fontSize: CGFloat) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = NSFont.systemFont(ofSize: fontSize)
        label.textColor = .secondaryLabelColor
        label.lineBreakMode = .byTruncatingTail
        return label
    }
}

private enum EmailStatus: Equatable {
    case notConfigured
    case disabled
    case configured
    case sent(Date)
    case failed(String)
}

private final class AllWorkEmailNotifier {
    private let queue = DispatchQueue(label: "oneMenu.emailNotifier")

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
                          oneMenu &#x68C0;&#x6D4B;&#x5230; GPT / Claude &#x5747;&#x5DF2;&#x7A7A;&#x95F2;&#xFF0C;<strong>&#x6240;&#x6709; AI &#x5DE5;&#x4F5C;&#x5DF2;&#x7ECF;&#x7ED3;&#x675F;</strong>&#x3002;
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
                          oneMenu
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
                    Sent by oneMenu &#xB7; macOS Menu Bar Monitor
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

final class StatusLightColorPreferences {
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

final class SleepPreventionPreferences {
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

final class SessionNotificationPreferences {
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

enum StatusBarModule: String, CaseIterable, Hashable {
    case gpt
    case claude
    case weather
    case hardware
    case countdown
    case targetTimeCountdown
    case systemReminder
    case sleep

    var defaultsKey: String {
        "statusBarDisplay.\(rawValue)"
    }

    var defaultVisibility: Bool {
        switch self {
        case .gpt, .claude, .weather, .hardware, .countdown, .targetTimeCountdown, .systemReminder:
            return true
        case .sleep:
            return false
        }
    }
}

final class StatusBarDisplayPreferences {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func isVisible(_ module: StatusBarModule) -> Bool {
        if defaults.object(forKey: module.defaultsKey) == nil {
            return module.defaultVisibility
        }
        return defaults.bool(forKey: module.defaultsKey)
    }

    func setVisible(_ isVisible: Bool, for module: StatusBarModule) {
        defaults.set(isVisible, forKey: module.defaultsKey)
    }

    var hasVisibleModule: Bool {
        StatusBarModule.allCases.contains { isVisible($0) }
    }
}

enum HardwareStatusBarMetric: String, CaseIterable, Hashable {
    case cpuUsage
    case memoryUsage
    case batteryLevel
    case thermalState
    case cpuTemperature
    case gpuTemperature
    case fanSpeed

    var title: String {
        switch self {
        case .cpuUsage:
            return "CPU 使用率"
        case .memoryUsage:
            return "内存使用率"
        case .batteryLevel:
            return "电池电量"
        case .thermalState:
            return "热状态"
        case .cpuTemperature:
            return "CPU 温度"
        case .gpuTemperature:
            return "GPU 温度"
        case .fanSpeed:
            return "风扇转速"
        }
    }

    var pendingTitle: String {
        switch self {
        case .cpuUsage:
            return "CPU --%"
        case .memoryUsage:
            return "内存 --%"
        case .batteryLevel:
            return "电池 --%"
        case .thermalState:
            return "热 --"
        case .cpuTemperature:
            return "CPU --°"
        case .gpuTemperature:
            return "GPU --°"
        case .fanSpeed:
            return "风扇 --"
        }
    }

    var symbolName: String {
        switch self {
        case .cpuUsage:
            return "cpu.fill"
        case .memoryUsage:
            return "memorychip.fill"
        case .batteryLevel:
            return "battery.100"
        case .thermalState:
            return "thermometer.medium"
        case .cpuTemperature:
            return "thermometer.medium"
        case .gpuTemperature:
            return "display"
        case .fanSpeed:
            return "fanblades.fill"
        }
    }

    var fallbackSymbolName: String {
        switch self {
        case .cpuUsage:
            return "gauge.medium"
        case .memoryUsage:
            return "memorychip"
        case .batteryLevel:
            return "battery.75"
        case .thermalState, .cpuTemperature, .gpuTemperature:
            return "thermometer"
        case .fanSpeed:
            return "fanblades"
        }
    }
}

final class HardwareStatusBarPreferences {
    private enum Key {
        static let metric = "hardwareStatusBarMetric"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var metric: HardwareStatusBarMetric {
        get {
            guard let rawValue = defaults.string(forKey: Key.metric),
                  let metric = HardwareStatusBarMetric(rawValue: rawValue)
            else {
                return .cpuUsage
            }
            return metric
        }
        set {
            defaults.set(newValue.rawValue, forKey: Key.metric)
        }
    }
}

private struct HardwareStatusBarPresentation {
    let title: String
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
            name: "oneMenu Prevent Idle System Sleep",
            assertionID: &systemSleepAssertionID
        )
        guard systemSleepResult == kIOReturnSuccess else {
            isEnabled = false
            return "无法开启防休眠（系统空闲睡眠 IOKit \(systemSleepResult)）"
        }

        let displaySleepResult = createAssertion(
            type: kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
            name: "oneMenu Prevent Idle Display Sleep",
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

struct StatusLightColor {
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

struct CountdownReminderColor {
    let id: String
    let title: String
    let color: NSColor
    let foregroundColor: NSColor

    static let available: [CountdownReminderColor] = [
        CountdownReminderColor(id: "red", title: "红色", color: .systemRed, foregroundColor: .white),
        CountdownReminderColor(id: "orange", title: "橙色", color: .systemOrange, foregroundColor: .white),
        CountdownReminderColor(id: "yellow", title: "黄色", color: .systemYellow, foregroundColor: .black),
        CountdownReminderColor(id: "pink", title: "粉色", color: .systemPink, foregroundColor: .white),
        CountdownReminderColor(id: "purple", title: "紫色", color: .systemPurple, foregroundColor: .white),
        CountdownReminderColor(id: "blue", title: "蓝色", color: .systemBlue, foregroundColor: .white)
    ]

    static func color(for id: String) -> CountdownReminderColor {
        available.first { $0.id == id } ?? available[0]
    }
}

struct TargetTimeCountdownBackgroundColor {
    let id: String
    let title: String
    let color: NSColor?
    let foregroundColor: NSColor?

    static let available: [TargetTimeCountdownBackgroundColor] = [
        TargetTimeCountdownBackgroundColor(id: "none", title: "默认透明", color: nil, foregroundColor: nil),
        TargetTimeCountdownBackgroundColor(id: "blue", title: "蓝色", color: .systemBlue, foregroundColor: .white),
        TargetTimeCountdownBackgroundColor(id: "green", title: "绿色", color: .systemGreen, foregroundColor: .white),
        TargetTimeCountdownBackgroundColor(id: "teal", title: "青色", color: .systemTeal, foregroundColor: .black),
        TargetTimeCountdownBackgroundColor(id: "purple", title: "紫色", color: .systemPurple, foregroundColor: .white),
        TargetTimeCountdownBackgroundColor(id: "orange", title: "橙色", color: .systemOrange, foregroundColor: .white),
        TargetTimeCountdownBackgroundColor(id: "yellow", title: "黄色", color: .systemYellow, foregroundColor: .black),
        TargetTimeCountdownBackgroundColor(id: "red", title: "红色", color: .systemRed, foregroundColor: .white),
        TargetTimeCountdownBackgroundColor(id: "gray", title: "灰色", color: .systemGray, foregroundColor: .white)
    ]

    static func color(for id: String) -> TargetTimeCountdownBackgroundColor {
        available.first { $0.id == id } ?? available[0]
    }
}

struct TargetTimeCountdownTextColor {
    let id: String
    let title: String
    let color: NSColor?

    static let available: [TargetTimeCountdownTextColor] = [
        TargetTimeCountdownTextColor(id: "automatic", title: "自动适配", color: nil),
        TargetTimeCountdownTextColor(id: "label", title: "系统文字", color: .labelColor),
        TargetTimeCountdownTextColor(id: "white", title: "白色", color: .white),
        TargetTimeCountdownTextColor(id: "black", title: "黑色", color: .black),
        TargetTimeCountdownTextColor(id: "blue", title: "蓝色", color: .systemBlue),
        TargetTimeCountdownTextColor(id: "green", title: "绿色", color: .systemGreen),
        TargetTimeCountdownTextColor(id: "orange", title: "橙色", color: .systemOrange),
        TargetTimeCountdownTextColor(id: "red", title: "红色", color: .systemRed),
        TargetTimeCountdownTextColor(id: "purple", title: "紫色", color: .systemPurple)
    ]

    static func color(for id: String) -> TargetTimeCountdownTextColor {
        available.first { $0.id == id } ?? available[0]
    }
}

private extension TargetTimeCountdownTextWeight {
    var fontWeight: NSFont.Weight {
        switch self {
        case .regular:
            return .regular
        case .medium:
            return .medium
        case .semibold:
            return .semibold
        case .bold:
            return .bold
        }
    }
}

private enum StatusProviderIcon {
    case gpt
    case claude

    var fileName: String {
        switch self {
        case .gpt:
            return "openai"
        case .claude:
            return "claude-color"
        }
    }

    var fallbackTitle: String {
        switch self {
        case .gpt:
            return "GPT"
        case .claude:
            return "C"
        }
    }

    var currentColor: NSColor {
        switch self {
        case .gpt:
            return .labelColor
        case .claude:
            return .labelColor
        }
    }
}

private enum StatusDotImage {
    static func make(color: NSColor, provider: StatusProviderIcon, isActive: Bool) -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size)
        image.lockFocus()

        let bounds = NSRect(origin: .zero, size: size)
        NSColor.clear.setFill()
        bounds.fill()

        if isActive {
            color.withAlphaComponent(0.22).setFill()
            NSBezierPath(ovalIn: bounds.insetBy(dx: 0.4, dy: 0.4)).fill()
        }

        drawProviderIcon(provider, isActive: isActive)
        drawStatusMarker(color: color, isActive: isActive)

        image.unlockFocus()
        image.isTemplate = false
        return image
    }

    private static func drawProviderIcon(_ provider: StatusProviderIcon, isActive: Bool) {
        guard let icon = SVGIconLoader.icon(for: provider) else {
            drawFallbackIcon(provider, isActive: isActive)
            return
        }

        let alpha: CGFloat = isActive ? 1 : 0.72
        let iconRect = NSRect(x: 2.3, y: 2.8, width: 13.4, height: 13.4)
        for shape in icon.shapes {
            guard let path = SVGPathParser.path(from: shape.pathData)?.copy() as? NSBezierPath else {
                continue
            }
            let fillColor = shape.fillColor ?? (shape.usesCurrentColor ? provider.currentColor : icon.defaultFillColor)
            fillColor.withAlphaComponent(alpha).setFill()
            SVGPathParser.draw(path, viewBox: icon.viewBox, in: iconRect)
        }
    }

    private static func drawFallbackIcon(_ provider: StatusProviderIcon, isActive: Bool) {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        let fontSize: CGFloat = provider == .gpt ? 5.1 : 8.4
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: fontSize, weight: .bold),
            .foregroundColor: NSColor.labelColor.withAlphaComponent(isActive ? 1 : 0.72),
            .paragraphStyle: paragraphStyle
        ]
        provider.fallbackTitle.draw(
            in: NSRect(x: 1.6, y: 5.8, width: 14.8, height: 7),
            withAttributes: attributes
        )
    }

    private static func drawStatusMarker(color: NSColor, isActive: Bool) {
        let markerSize: CGFloat = isActive ? 5.4 : 4.6
        let markerRect = NSRect(x: 11.7, y: 1.4, width: markerSize, height: markerSize)
        NSColor.windowBackgroundColor.withAlphaComponent(0.96).setFill()
        NSBezierPath(ovalIn: markerRect.insetBy(dx: -0.9, dy: -0.9)).fill()
        color.withAlphaComponent(isActive ? 1 : 0.74).setFill()
        NSBezierPath(ovalIn: markerRect).fill()
    }
}

private struct SVGIcon {
    let viewBox: CGRect
    let defaultFillColor: NSColor
    let shapes: [SVGIconShape]
}

private struct SVGIconShape {
    let pathData: String
    let fillColor: NSColor?
    let usesCurrentColor: Bool
}

private enum SVGIconLoader {
    private static var cache: [StatusProviderIcon: SVGIcon] = [:]
    private static let lock = NSLock()

    static func icon(for provider: StatusProviderIcon) -> SVGIcon? {
        lock.lock()
        if let icon = cache[provider] {
            lock.unlock()
            return icon
        }
        lock.unlock()

        guard let url = iconURL(for: provider),
              let data = try? String(contentsOf: url, encoding: .utf8),
              let icon = parse(data, currentColor: provider.currentColor)
        else {
            return nil
        }

        lock.lock()
        cache[provider] = icon
        lock.unlock()
        return icon
    }

    private static func iconURL(for provider: StatusProviderIcon) -> URL? {
        let resourceName = provider.fileName
        let fileName = "\(resourceName).svg"
        let fileManager = FileManager.default
        let cwd = URL(fileURLWithPath: fileManager.currentDirectoryPath)
        let candidates: [URL?] = [
            Bundle.main.url(forResource: resourceName, withExtension: "svg"),
            Bundle.main.resourceURL?.appendingPathComponent(fileName),
            cwd.appendingPathComponent(fileName),
            cwd.appendingPathComponent("Resources").appendingPathComponent(fileName),
            Bundle.main.executableURL?.deletingLastPathComponent().appendingPathComponent(fileName),
            Bundle.main.executableURL?.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent(fileName)
        ]

        return candidates.compactMap { $0 }.first { fileManager.fileExists(atPath: $0.path) }
    }

    private static func parse(_ svg: String, currentColor: NSColor) -> SVGIcon? {
        guard let viewBox = attribute("viewBox", in: svg).flatMap(parseViewBox) else {
            return nil
        }

        let rootFill = attribute("fill", in: svg).flatMap { fillColor($0, currentColor: currentColor) }
        let rootUsesCurrentColor = attribute("fill", in: svg) == "currentColor"
        let pathTags = matches(pattern: #"<path\b[^>]*>"#, in: svg)
        let shapes = pathTags.compactMap { tag -> SVGIconShape? in
            guard let pathData = attribute("d", in: tag) else {
                return nil
            }
            let fillValue = attribute("fill", in: tag)
            if fillValue == "none" {
                return nil
            }
            return SVGIconShape(
                pathData: pathData,
                fillColor: fillValue.flatMap { fillColor($0, currentColor: currentColor) } ?? rootFill,
                usesCurrentColor: fillValue == "currentColor" || (fillValue == nil && rootUsesCurrentColor)
            )
        }

        guard !shapes.isEmpty else {
            return nil
        }
        return SVGIcon(viewBox: viewBox, defaultFillColor: rootFill ?? currentColor, shapes: shapes)
    }

    private static func parseViewBox(_ value: String) -> CGRect? {
        let values = value
            .split { $0 == " " || $0 == "," || $0 == "\n" || $0 == "\t" }
            .compactMap { Double($0) }
        guard values.count == 4 else {
            return nil
        }
        return CGRect(x: values[0], y: values[1], width: values[2], height: values[3])
    }

    private static func attribute(_ name: String, in text: String) -> String? {
        let escapedName = NSRegularExpression.escapedPattern(for: name)
        let pattern = #"\b\#(escapedName)\s*=\s*["']([^"']+)["']"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let range = Range(match.range(at: 1), in: text)
        else {
            return nil
        }
        return String(text[range])
    }

    private static func matches(pattern: String, in text: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return []
        }
        let range = NSRange(text.startIndex..., in: text)
        return regex.matches(in: text, range: range).compactMap { match in
            Range(match.range, in: text).map { String(text[$0]) }
        }
    }

    private static func fillColor(_ value: String, currentColor: NSColor) -> NSColor? {
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if normalized == "currentColor" {
            return currentColor
        }
        if normalized == "none" {
            return nil
        }
        if normalized.hasPrefix("#") {
            return color(hex: String(normalized.dropFirst()))
        }

        switch normalized.lowercased() {
        case "black":
            return .black
        case "white":
            return .white
        default:
            return nil
        }
    }

    private static func color(hex: String) -> NSColor? {
        let scanner = Scanner(string: hex)
        var value: UInt64 = 0
        guard scanner.scanHexInt64(&value) else {
            return nil
        }

        let red: CGFloat
        let green: CGFloat
        let blue: CGFloat
        switch hex.count {
        case 3:
            red = CGFloat((value >> 8) & 0xF) / 15
            green = CGFloat((value >> 4) & 0xF) / 15
            blue = CGFloat(value & 0xF) / 15
        case 6:
            red = CGFloat((value >> 16) & 0xFF) / 255
            green = CGFloat((value >> 8) & 0xFF) / 255
            blue = CGFloat(value & 0xFF) / 255
        default:
            return nil
        }
        return NSColor(calibratedRed: red, green: green, blue: blue, alpha: 1)
    }
}

private enum SVGPathParser {
    private enum Token {
        case command(Character)
        case number(CGFloat)
    }

    static func path(from data: String) -> NSBezierPath? {
        var parser = Parser(tokens: tokenize(data))
        return parser.parse()
    }

    static func draw(_ path: NSBezierPath, viewBox: CGRect, in rect: NSRect) {
        let scale = min(rect.width / viewBox.width, rect.height / viewBox.height)
        let drawSize = NSSize(width: viewBox.width * scale, height: viewBox.height * scale)
        let drawRect = NSRect(
            x: rect.midX - drawSize.width / 2,
            y: rect.midY - drawSize.height / 2,
            width: drawSize.width,
            height: drawSize.height
        )
        let transform = AffineTransform(
            m11: scale,
            m12: 0,
            m21: 0,
            m22: -scale,
            tX: drawRect.minX - viewBox.minX * scale,
            tY: drawRect.maxY + viewBox.minY * scale
        )
        path.transform(using: transform)
        path.fill()
    }

    private static func tokenize(_ data: String) -> [Token] {
        var tokens: [Token] = []
        var number = ""

        func flushNumber() {
            guard !number.isEmpty else {
                return
            }
            if let value = Double(number) {
                tokens.append(.number(CGFloat(value)))
            }
            number = ""
        }

        for scalar in data.unicodeScalars {
            if isPathCommand(scalar) {
                flushNumber()
                tokens.append(.command(Character(scalar)))
            } else if isNumberSeparator(scalar) {
                flushNumber()
            } else if scalar == "-" || scalar == "+" {
                if !number.isEmpty, !number.hasSuffix("e"), !number.hasSuffix("E") {
                    flushNumber()
                }
                number.append(Character(scalar))
            } else {
                number.append(Character(scalar))
            }
        }
        flushNumber()
        return tokens
    }

    private static func isPathCommand(_ scalar: UnicodeScalar) -> Bool {
        let value = scalar.value
        guard (65...90).contains(value) || (97...122).contains(value) else {
            return false
        }
        return scalar != "e" && scalar != "E"
    }

    private static func isNumberSeparator(_ scalar: UnicodeScalar) -> Bool {
        scalar == "," || scalar == " " || scalar == "\n" || scalar == "\t" || scalar == "\r"
    }

    private struct Parser {
        var tokens: [Token]
        var index = 0
        var activeCommand: Character?
        var current = NSPoint.zero
        var subpathStart = NSPoint.zero

        mutating func parse() -> NSBezierPath? {
            let path = NSBezierPath()
            while index < tokens.count {
                if case let .command(command) = tokens[index] {
                    activeCommand = command
                    index += 1
                }

                guard let command = activeCommand else {
                    return nil
                }

                let relative = String(command) == String(command).lowercased()
                switch Character(String(command).lowercased()) {
                case "m":
                    parseMove(path: path, relative: relative)
                case "l":
                    parseLine(path: path, relative: relative)
                case "h":
                    parseHorizontal(path: path, relative: relative)
                case "v":
                    parseVertical(path: path, relative: relative)
                case "c":
                    parseCubic(path: path, relative: relative)
                case "q":
                    parseQuadratic(path: path, relative: relative)
                case "a":
                    parseArc(path: path, relative: relative)
                case "z":
                    path.close()
                    current = subpathStart
                    activeCommand = nil
                default:
                    skipUnsupportedCommand()
                }
            }
            return path
        }

        private mutating func parseMove(path: NSBezierPath, relative: Bool) {
            guard let point = readPoint(relative: relative) else {
                return
            }
            path.move(to: point)
            current = point
            subpathStart = point

            while hasNumber, let linePoint = readPoint(relative: relative) {
                path.line(to: linePoint)
                current = linePoint
            }
        }

        private mutating func parseLine(path: NSBezierPath, relative: Bool) {
            while hasNumber, let point = readPoint(relative: relative) {
                path.line(to: point)
                current = point
            }
        }

        private mutating func parseHorizontal(path: NSBezierPath, relative: Bool) {
            while hasNumber, let x = readNumber() {
                let next = NSPoint(x: relative ? current.x + x : x, y: current.y)
                path.line(to: next)
                current = next
            }
        }

        private mutating func parseVertical(path: NSBezierPath, relative: Bool) {
            while hasNumber, let y = readNumber() {
                let next = NSPoint(x: current.x, y: relative ? current.y + y : y)
                path.line(to: next)
                current = next
            }
        }

        private mutating func parseCubic(path: NSBezierPath, relative: Bool) {
            while hasNumber,
                  let control1 = readPoint(relative: relative),
                  let control2 = readPoint(relative: relative),
                  let end = readPoint(relative: relative) {
                path.curve(to: end, controlPoint1: control1, controlPoint2: control2)
                current = end
            }
        }

        private mutating func parseQuadratic(path: NSBezierPath, relative: Bool) {
            while hasNumber,
                  let control = readPoint(relative: relative),
                  let end = readPoint(relative: relative) {
                let control1 = NSPoint(
                    x: current.x + (control.x - current.x) * 2 / 3,
                    y: current.y + (control.y - current.y) * 2 / 3
                )
                let control2 = NSPoint(
                    x: end.x + (control.x - end.x) * 2 / 3,
                    y: end.y + (control.y - end.y) * 2 / 3
                )
                path.curve(to: end, controlPoint1: control1, controlPoint2: control2)
                current = end
            }
        }

        private mutating func parseArc(path: NSBezierPath, relative: Bool) {
            while hasNumber,
                  let radiusX = readNumber(),
                  let radiusY = readNumber(),
                  let rotation = readNumber(),
                  let largeArcFlag = readNumber(),
                  let sweepFlag = readNumber(),
                  let rawEnd = readRawPoint() {
                let end = relative
                    ? NSPoint(x: current.x + rawEnd.x, y: current.y + rawEnd.y)
                    : rawEnd
                appendArc(
                    to: path,
                    from: current,
                    to: end,
                    radiusX: radiusX,
                    radiusY: radiusY,
                    rotation: rotation,
                    largeArc: largeArcFlag != 0,
                    sweep: sweepFlag != 0
                )
                current = end
            }
        }

        private mutating func skipUnsupportedCommand() {
            while hasNumber {
                _ = readNumber()
            }
        }

        private var hasNumber: Bool {
            guard index < tokens.count else {
                return false
            }
            if case .number = tokens[index] {
                return true
            }
            return false
        }

        private mutating func readNumber() -> CGFloat? {
            guard index < tokens.count,
                  case let .number(value) = tokens[index]
            else {
                return nil
            }
            index += 1
            return value
        }

        private mutating func readRawPoint() -> NSPoint? {
            guard let x = readNumber(), let y = readNumber() else {
                return nil
            }
            return NSPoint(x: x, y: y)
        }

        private mutating func readPoint(relative: Bool) -> NSPoint? {
            guard let point = readRawPoint() else {
                return nil
            }
            if relative {
                return NSPoint(x: current.x + point.x, y: current.y + point.y)
            }
            return point
        }

        private func appendArc(
            to path: NSBezierPath,
            from start: NSPoint,
            to end: NSPoint,
            radiusX rawRadiusX: CGFloat,
            radiusY rawRadiusY: CGFloat,
            rotation: CGFloat,
            largeArc: Bool,
            sweep: Bool
        ) {
            var rx = abs(Double(rawRadiusX))
            var ry = abs(Double(rawRadiusY))
            guard rx > 0, ry > 0, start != end else {
                path.line(to: end)
                return
            }

            let x1 = Double(start.x)
            let y1 = Double(start.y)
            let x2 = Double(end.x)
            let y2 = Double(end.y)
            let phi = Double(rotation) * Double.pi / 180
            let cosPhi = cos(phi)
            let sinPhi = sin(phi)
            let dx = (x1 - x2) / 2
            let dy = (y1 - y2) / 2
            let x1Prime = cosPhi * dx + sinPhi * dy
            let y1Prime = -sinPhi * dx + cosPhi * dy
            let radiusScale = (x1Prime * x1Prime) / (rx * rx) + (y1Prime * y1Prime) / (ry * ry)

            if radiusScale > 1 {
                let scale = sqrt(radiusScale)
                rx *= scale
                ry *= scale
            }

            let rxSquared = rx * rx
            let rySquared = ry * ry
            let x1PrimeSquared = x1Prime * x1Prime
            let y1PrimeSquared = y1Prime * y1Prime
            let denominator = rxSquared * y1PrimeSquared + rySquared * x1PrimeSquared

            guard denominator > 0 else {
                path.line(to: end)
                return
            }

            let sign = largeArc == sweep ? -1.0 : 1.0
            let numerator = max(0, rxSquared * rySquared - rxSquared * y1PrimeSquared - rySquared * x1PrimeSquared)
            let coefficient = sign * sqrt(numerator / denominator)
            let centerXPrime = coefficient * (rx * y1Prime / ry)
            let centerYPrime = coefficient * (-ry * x1Prime / rx)
            let centerX = cosPhi * centerXPrime - sinPhi * centerYPrime + (x1 + x2) / 2
            let centerY = sinPhi * centerXPrime + cosPhi * centerYPrime + (y1 + y2) / 2
            let vector1 = ((x1Prime - centerXPrime) / rx, (y1Prime - centerYPrime) / ry)
            let vector2 = ((-x1Prime - centerXPrime) / rx, (-y1Prime - centerYPrime) / ry)
            let startAngle = angle(from: (1, 0), to: vector1)
            var angleDelta = angle(from: vector1, to: vector2)

            if !sweep, angleDelta > 0 {
                angleDelta -= Double.pi * 2
            } else if sweep, angleDelta < 0 {
                angleDelta += Double.pi * 2
            }

            let segmentCount = max(1, Int(ceil(abs(angleDelta) / (Double.pi / 2))))
            let segmentDelta = angleDelta / Double(segmentCount)

            for segmentIndex in 0..<segmentCount {
                let theta1 = startAngle + Double(segmentIndex) * segmentDelta
                let theta2 = theta1 + segmentDelta
                appendArcSegment(
                    to: path,
                    centerX: centerX,
                    centerY: centerY,
                    radiusX: rx,
                    radiusY: ry,
                    cosPhi: cosPhi,
                    sinPhi: sinPhi,
                    startAngle: theta1,
                    endAngle: theta2
                )
            }
        }

        private func appendArcSegment(
            to path: NSBezierPath,
            centerX: Double,
            centerY: Double,
            radiusX: Double,
            radiusY: Double,
            cosPhi: Double,
            sinPhi: Double,
            startAngle: Double,
            endAngle: Double
        ) {
            let alpha = 4 / 3 * tan((endAngle - startAngle) / 4)
            let startUnit = (cos(startAngle), sin(startAngle))
            let endUnit = (cos(endAngle), sin(endAngle))
            let control1Unit = (startUnit.0 - alpha * startUnit.1, startUnit.1 + alpha * startUnit.0)
            let control2Unit = (endUnit.0 + alpha * endUnit.1, endUnit.1 - alpha * endUnit.0)

            path.curve(
                to: transformArcPoint(endUnit, centerX: centerX, centerY: centerY, radiusX: radiusX, radiusY: radiusY, cosPhi: cosPhi, sinPhi: sinPhi),
                controlPoint1: transformArcPoint(control1Unit, centerX: centerX, centerY: centerY, radiusX: radiusX, radiusY: radiusY, cosPhi: cosPhi, sinPhi: sinPhi),
                controlPoint2: transformArcPoint(control2Unit, centerX: centerX, centerY: centerY, radiusX: radiusX, radiusY: radiusY, cosPhi: cosPhi, sinPhi: sinPhi)
            )
        }

        private func transformArcPoint(
            _ point: (Double, Double),
            centerX: Double,
            centerY: Double,
            radiusX: Double,
            radiusY: Double,
            cosPhi: Double,
            sinPhi: Double
        ) -> NSPoint {
            let x = centerX + radiusX * point.0 * cosPhi - radiusY * point.1 * sinPhi
            let y = centerY + radiusX * point.0 * sinPhi + radiusY * point.1 * cosPhi
            return NSPoint(x: CGFloat(x), y: CGFloat(y))
        }

        private func angle(from start: (Double, Double), to end: (Double, Double)) -> Double {
            let dot = start.0 * end.0 + start.1 * end.1
            let determinant = start.0 * end.1 - start.1 * end.0
            return atan2(determinant, dot)
        }
    }
}
