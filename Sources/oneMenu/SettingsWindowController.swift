import AppKit
import CodexStatusCore

final class SettingsWindowController: NSWindowController, NSTextFieldDelegate {
    private enum Section: Int, CaseIterable, Hashable {
        case codex
        case claude
        case weather
        case hardware
        case countdown
        case targetTimeCountdown
        case systemReminder
        case sleep
        case appearance
        case notifications

        var title: String {
            switch self {
            case .codex:
                return "Codex/GPT"
            case .claude:
                return "Claude"
            case .weather:
                return "天气"
            case .hardware:
                return "硬件"
            case .countdown:
                return "倒计时"
            case .targetTimeCountdown:
                return "目标倒计"
            case .systemReminder:
                return "系统提醒"
            case .sleep:
                return "防休眠"
            case .appearance:
                return "外观"
            case .notifications:
                return "通知"
            }
        }

        var subtitle: String {
            switch self {
            case .codex:
                return "活跃检测"
            case .claude:
                return "活跃检测"
            case .weather:
                return "预报与定位"
            case .hardware:
                return "系统状态"
            case .countdown:
                return "秒与分钟"
            case .targetTimeCountdown:
                return "到点分钟"
            case .systemReminder:
                return "单次 / 每日"
            case .sleep:
                return "保持 Mac 活跃"
            case .appearance:
                return "亮暗色模式"
            case .notifications:
                return "桌面与邮件"
            }
        }

        var symbolName: String {
            switch self {
            case .codex:
                return "bolt.horizontal.circle.fill"
            case .claude:
                return "sparkles"
            case .weather:
                return "cloud.sun.fill"
            case .hardware:
                return "cpu.fill"
            case .countdown:
                return "timer"
            case .targetTimeCountdown:
                return "clock.fill"
            case .systemReminder:
                return "bell.badge.fill"
            case .sleep:
                return "moon.zzz.fill"
            case .appearance:
                return "circle.lefthalf.filled"
            case .notifications:
                return "bell.badge.fill"
            }
        }
    }

    private enum Layout {
        static let sidebarWidth: CGFloat = 226
        static let sidebarInset: CGFloat = 10
        static let sidebarItemHeight: CGFloat = 38
        static let pageTopInset: CGFloat = 30
        static let pageHorizontalInset: CGFloat = 34
        static let contentWidth: CGFloat = 510
    }

    private let colorPreferences: StatusLightColorPreferences
    private let appearancePreferences: AppAppearancePreferences
    private let sleepPreventionPreferences: SleepPreventionPreferences
    private let sessionNotificationPreferences: SessionNotificationPreferences
    private let statusBarDisplayPreferences: StatusBarDisplayPreferences
    private let hardwareStatusBarPreferences: HardwareStatusBarPreferences
    private let countdownPreferences: CountdownTimerPreferences
    private let targetTimeCountdownPreferences: TargetTimeCountdownPreferences
    private let systemReminderPreferences: SystemReminderPreferences
    private var systemReminderRegistrationStatus: String
    private let onChange: () -> Void
    private let onAppearanceChange: () -> Void
    private let onSleepPreferenceChange: () -> Void
    private let onWeatherRefresh: () -> Void
    private let onHardwareRefresh: () -> Void
    private let onCountdownDurationChange: () -> Void
    private let onCountdownStart: () -> Void
    private let onCountdownPause: () -> Void
    private let onCountdownResume: () -> Void
    private let onCountdownReset: () -> Void
    private let onCountdownReminderChange: () -> Void
    private let onTargetTimeCountdownChange: () -> Void
    private let onSystemReminderChange: () -> Void
    private let onSystemReminderTest: () -> Void
    private let onOpenLocationSettings: () -> Void
    private let onOpenCodexFolder: () -> Void
    private let onOpenClaudeFolder: () -> Void
    private let onOpenEmailSettings: () -> Void

    private var weatherSnapshot: WeatherServiceSnapshot
    private var hardwareSnapshot: HardwareStatusSnapshot?
    private var countdownSnapshot: CountdownSnapshot
    private var sleepIsEnabled = false
    private var selectedSection: Section = .codex
    private var sidebarButtons: [Section: SettingsSidebarItemView] = [:]
    private var weatherStatusLabel: NSTextField?
    private var hardwareStatusLabel: NSTextField?
    private var hardwareMetricPopup: NSPopUpButton?
    private var countdownStatusLabel: NSTextField?
    private var countdownValueField: NSTextField?
    private var countdownStepper: NSStepper?
    private var countdownUnitPopup: NSPopUpButton?
    private var countdownReminderValueField: NSTextField?
    private var countdownReminderStepper: NSStepper?
    private var countdownReminderUnitPopup: NSPopUpButton?
    private var countdownReminderColorPopup: NSPopUpButton?
    private var countdownPrimaryButton: NSButton?
    private var countdownResetButton: NSButton?
    private var targetTimeCountdownStatusLabel: NSTextField?
    private var targetTimeCountdownTitleField: NSTextField?
    private var targetTimeCountdownHourField: NSTextField?
    private var targetTimeCountdownHourStepper: NSStepper?
    private var targetTimeCountdownMinuteField: NSTextField?
    private var targetTimeCountdownMinuteStepper: NSStepper?
    private var targetTimeCountdownPastBehaviorPopup: NSPopUpButton?
    private var targetTimeCountdownBackgroundColorPopup: NSPopUpButton?
    private var targetTimeCountdownTextWeightPopup: NSPopUpButton?
    private var targetTimeCountdownTextColorPopup: NSPopUpButton?
    private var targetTimeCountdownIconCheckbox: NSButton?
    private var systemReminderStatusLabel: NSTextField?
    private var systemReminderEnabledCheckbox: NSButton?
    private var systemReminderModePopup: NSPopUpButton?
    private var systemReminderDatePicker: NSDatePicker?
    private var systemReminderTitleField: NSTextField?
    private var systemReminderMessageField: NSTextField?
    private var sleepStateLabel: NSTextField?
    private var sleepToggle: NSButton?
    private var appearanceModePopup: NSPopUpButton?
    private var appearanceStatusLabel: NSTextField?
    private let detailContainer = NSView(frame: .zero)
    private var pageCache: [Section: NSView] = [:]
    private var statusModuleCheckboxes: [StatusBarModule: NSButton] = [:]
    private var colorPopupsByRole: [String: [NSPopUpButton]] = [:]

    init(
        colorPreferences: StatusLightColorPreferences,
        appearancePreferences: AppAppearancePreferences,
        sleepPreventionPreferences: SleepPreventionPreferences,
        sessionNotificationPreferences: SessionNotificationPreferences,
        statusBarDisplayPreferences: StatusBarDisplayPreferences,
        hardwareStatusBarPreferences: HardwareStatusBarPreferences,
        countdownPreferences: CountdownTimerPreferences,
        targetTimeCountdownPreferences: TargetTimeCountdownPreferences,
        systemReminderPreferences: SystemReminderPreferences,
        systemReminderRegistrationStatus: String,
        countdownSnapshot: CountdownSnapshot,
        weatherSnapshot: WeatherServiceSnapshot,
        hardwareSnapshot: HardwareStatusSnapshot?,
        onChange: @escaping () -> Void,
        onAppearanceChange: @escaping () -> Void,
        onSleepPreferenceChange: @escaping () -> Void,
        onWeatherRefresh: @escaping () -> Void,
        onHardwareRefresh: @escaping () -> Void,
        onCountdownDurationChange: @escaping () -> Void,
        onCountdownStart: @escaping () -> Void,
        onCountdownPause: @escaping () -> Void,
        onCountdownResume: @escaping () -> Void,
        onCountdownReset: @escaping () -> Void,
        onCountdownReminderChange: @escaping () -> Void,
        onTargetTimeCountdownChange: @escaping () -> Void,
        onSystemReminderChange: @escaping () -> Void,
        onSystemReminderTest: @escaping () -> Void,
        onOpenLocationSettings: @escaping () -> Void,
        onOpenCodexFolder: @escaping () -> Void,
        onOpenClaudeFolder: @escaping () -> Void,
        onOpenEmailSettings: @escaping () -> Void
    ) {
        self.colorPreferences = colorPreferences
        self.appearancePreferences = appearancePreferences
        self.sleepPreventionPreferences = sleepPreventionPreferences
        self.sessionNotificationPreferences = sessionNotificationPreferences
        self.statusBarDisplayPreferences = statusBarDisplayPreferences
        self.hardwareStatusBarPreferences = hardwareStatusBarPreferences
        self.countdownPreferences = countdownPreferences
        self.targetTimeCountdownPreferences = targetTimeCountdownPreferences
        self.systemReminderPreferences = systemReminderPreferences
        self.systemReminderRegistrationStatus = systemReminderRegistrationStatus
        self.countdownSnapshot = countdownSnapshot
        self.weatherSnapshot = weatherSnapshot
        self.hardwareSnapshot = hardwareSnapshot
        self.onChange = onChange
        self.onAppearanceChange = onAppearanceChange
        self.onSleepPreferenceChange = onSleepPreferenceChange
        self.onWeatherRefresh = onWeatherRefresh
        self.onHardwareRefresh = onHardwareRefresh
        self.onCountdownDurationChange = onCountdownDurationChange
        self.onCountdownStart = onCountdownStart
        self.onCountdownPause = onCountdownPause
        self.onCountdownResume = onCountdownResume
        self.onCountdownReset = onCountdownReset
        self.onCountdownReminderChange = onCountdownReminderChange
        self.onTargetTimeCountdownChange = onTargetTimeCountdownChange
        self.onSystemReminderChange = onSystemReminderChange
        self.onSystemReminderTest = onSystemReminderTest
        self.onOpenLocationSettings = onOpenLocationSettings
        self.onOpenCodexFolder = onOpenCodexFolder
        self.onOpenClaudeFolder = onOpenClaudeFolder
        self.onOpenEmailSettings = onOpenEmailSettings

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 780, height: 520),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "oneMenu 设置"
        window.minSize = NSSize(width: 790, height: 500)
        window.center()

        super.init(window: window)
        buildUI()
        select(section: .codex)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func updateWeatherSnapshot(_ snapshot: WeatherServiceSnapshot) {
        weatherSnapshot = snapshot
        weatherStatusLabel?.stringValue = weatherStatusText(for: snapshot)
    }

    func updateHardwareSnapshot(_ snapshot: HardwareStatusSnapshot?) {
        hardwareSnapshot = snapshot
        hardwareStatusLabel?.stringValue = hardwareStatusText(for: snapshot)
    }

    func updateCountdownSnapshot(_ snapshot: CountdownSnapshot) {
        countdownSnapshot = snapshot
        countdownStatusLabel?.stringValue = countdownStatusText(for: snapshot)
        updateCountdownButtons()
    }

    func updateSystemReminderStatus(registrationStatus: String? = nil) {
        if let registrationStatus {
            systemReminderRegistrationStatus = registrationStatus
        }
        systemReminderStatusLabel?.stringValue = systemReminderStatusText()
    }

    func updateTargetTimeCountdownStatus() {
        targetTimeCountdownStatusLabel?.stringValue = targetTimeCountdownStatusText()
    }

    func updateSleepState(isEnabled: Bool) {
        sleepIsEnabled = isEnabled
        sleepStateLabel?.stringValue = isEnabled ? "当前状态：已开启" : "当前状态：已关闭"
        sleepToggle?.state = isEnabled ? .on : .off
    }

    func updateAppearanceMode() {
        syncAppearanceControls()
    }

    func selectModule(_ module: StatusBarModule) {
        select(section: section(for: module))
    }

    private func buildUI() {
        guard let window else {
            return
        }

        let rootView = NSView(frame: window.contentLayoutRect)
        window.contentView = rootView

        let sidebar = NSVisualEffectView(frame: .zero)
        sidebar.material = .sidebar
        sidebar.state = .active
        sidebar.blendingMode = .withinWindow

        let sidebarStack = NSStackView()
        sidebarStack.orientation = .vertical
        sidebarStack.alignment = .leading
        sidebarStack.spacing = 3
        sidebarStack.edgeInsets = NSEdgeInsets(top: 16, left: Layout.sidebarInset, bottom: 10, right: Layout.sidebarInset)

        let titleLabel = NSTextField(labelWithString: "oneMenu")
        titleLabel.alignment = .left
        titleLabel.font = NSFont.systemFont(ofSize: 18, weight: .semibold)
        titleLabel.widthAnchor.constraint(equalToConstant: Layout.sidebarWidth - Layout.sidebarInset * 2).isActive = true
        sidebarStack.addArrangedSubview(titleLabel)

        let subtitleLabel = NSTextField(labelWithString: "菜单栏模块")
        subtitleLabel.alignment = .left
        subtitleLabel.font = NSFont.systemFont(ofSize: 11, weight: .regular)
        subtitleLabel.textColor = .secondaryLabelColor
        subtitleLabel.widthAnchor.constraint(equalToConstant: Layout.sidebarWidth - Layout.sidebarInset * 2).isActive = true
        sidebarStack.addArrangedSubview(subtitleLabel)
        sidebarStack.setCustomSpacing(10, after: subtitleLabel)

        for section in Section.allCases {
            let button = sidebarButton(for: section)
            sidebarButtons[section] = button
            sidebarStack.addArrangedSubview(button)
        }

        let spacer = NSView()
        sidebarStack.addArrangedSubview(spacer)

        sidebar.addSubview(sidebarStack)
        detailContainer.wantsLayer = true

        rootView.addSubview(sidebar)
        rootView.addSubview(detailContainer)

        sidebar.translatesAutoresizingMaskIntoConstraints = false
        sidebarStack.translatesAutoresizingMaskIntoConstraints = false
        detailContainer.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            sidebar.leadingAnchor.constraint(equalTo: rootView.leadingAnchor),
            sidebar.topAnchor.constraint(equalTo: rootView.topAnchor),
            sidebar.bottomAnchor.constraint(equalTo: rootView.bottomAnchor),
            sidebar.widthAnchor.constraint(equalToConstant: Layout.sidebarWidth),

            sidebarStack.leadingAnchor.constraint(equalTo: sidebar.leadingAnchor),
            sidebarStack.trailingAnchor.constraint(equalTo: sidebar.trailingAnchor),
            sidebarStack.topAnchor.constraint(equalTo: sidebar.topAnchor),
            sidebarStack.bottomAnchor.constraint(equalTo: sidebar.bottomAnchor),

            detailContainer.leadingAnchor.constraint(equalTo: sidebar.trailingAnchor),
            detailContainer.trailingAnchor.constraint(equalTo: rootView.trailingAnchor),
            detailContainer.topAnchor.constraint(equalTo: rootView.topAnchor),
            detailContainer.bottomAnchor.constraint(equalTo: rootView.bottomAnchor)
        ])
    }

    private func sidebarButton(for section: Section) -> SettingsSidebarItemView {
        let button = SettingsSidebarItemView(
            title: section.title,
            subtitle: section.subtitle,
            symbolName: section.symbolName
        )
        button.target = self
        button.action = #selector(sidebarButtonClicked(_:))
        button.tag = section.rawValue
        button.heightAnchor.constraint(equalToConstant: Layout.sidebarItemHeight).isActive = true
        button.widthAnchor.constraint(equalToConstant: Layout.sidebarWidth - Layout.sidebarInset * 2).isActive = true
        return button
    }

    @objc private func sidebarButtonClicked(_ sender: NSControl) {
        guard let section = Section(rawValue: sender.tag) else {
            return
        }
        select(section: section)
    }

    private func select(section: Section) {
        selectedSection = section
        for (candidate, button) in sidebarButtons {
            button.isSelected = candidate == section
        }

        _ = cachedPage(for: section)
        for (candidate, page) in pageCache {
            page.isHidden = candidate != section
        }
        syncCachedControls()
    }

    private func cachedPage(for section: Section) -> NSView {
        if let page = pageCache[section] {
            return page
        }

        let page = makePage(for: section)
        page.isHidden = true
        pageCache[section] = page
        detailContainer.addSubview(page)
        page.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            page.leadingAnchor.constraint(equalTo: detailContainer.leadingAnchor),
            page.trailingAnchor.constraint(equalTo: detailContainer.trailingAnchor),
            page.topAnchor.constraint(equalTo: detailContainer.topAnchor),
            page.bottomAnchor.constraint(equalTo: detailContainer.bottomAnchor)
        ])
        return page
    }

    private func makePage(for section: Section) -> NSView {
        switch section {
        case .codex:
            return makeCodexPage()
        case .claude:
            return makeClaudePage()
        case .weather:
            return makeWeatherPage()
        case .hardware:
            return makeHardwarePage()
        case .countdown:
            return makeCountdownPage()
        case .targetTimeCountdown:
            return makeTargetTimeCountdownPage()
        case .systemReminder:
            return makeSystemReminderPage()
        case .sleep:
            return makeSleepPage()
        case .appearance:
            return makeAppearancePage()
        case .notifications:
            return makeNotificationsPage()
        }
    }

    private func section(for module: StatusBarModule) -> Section {
        switch module {
        case .gpt:
            return .codex
        case .claude:
            return .claude
        case .weather:
            return .weather
        case .hardware:
            return .hardware
        case .countdown:
            return .countdown
        case .targetTimeCountdown:
            return .targetTimeCountdown
        case .systemReminder:
            return .systemReminder
        case .sleep:
            return .sleep
        }
    }

    private func makeCodexPage() -> NSView {
        let stack = basePageStack()
        addHeader(to: stack, title: "Codex/GPT 活跃检测", subtitle: "读取 ~/.codex 会话文件，在菜单栏显示当前是否仍有任务运行。")
        addStatusBarToggle(to: stack, module: .gpt, title: "在顶部状态栏显示 Codex/GPT 状态灯")
        addColorControls(to: stack)
        addActionButton(to: stack, title: "打开 ~/.codex", action: #selector(openCodexFolder))
        return scrollView(for: stack)
    }

    private func makeClaudePage() -> NSView {
        let stack = basePageStack()
        addHeader(to: stack, title: "Claude 活跃检测", subtitle: "读取 ~/.claude/projects 会话事件，独立显示 Claude 是否仍在处理任务。")
        addStatusBarToggle(to: stack, module: .claude, title: "在顶部状态栏显示 Claude 状态灯")
        addColorControls(to: stack)
        addActionButton(to: stack, title: "打开 ~/.claude", action: #selector(openClaudeFolder))
        return scrollView(for: stack)
    }

    private func makeWeatherPage() -> NSView {
        let stack = basePageStack()
        addHeader(to: stack, title: "天气预报", subtitle: "使用当前位置获取 Open-Meteo 预报，在菜单栏显示当前温度和天气图标。")
        addStatusBarToggle(to: stack, module: .weather, title: "在顶部状态栏显示天气")

        weatherStatusLabel = secondaryLabel(weatherStatusText(for: weatherSnapshot))
        addInfoPanel(to: stack, title: "当前天气状态", content: weatherStatusLabel!)

        let buttons = NSStackView()
        buttons.orientation = .horizontal
        buttons.spacing = 8
        buttons.addArrangedSubview(actionButton(title: "更新天气", action: #selector(refreshWeather)))
        buttons.addArrangedSubview(actionButton(title: "打开定位隐私设置", action: #selector(openLocationSettings)))
        buttons.addArrangedSubview(NSView())
        stack.addArrangedSubview(buttons)

        let privacy = secondaryLabel("仅使用经纬度请求天气预报。天气数据每 10 分钟刷新一次，位置变化超过约 10 公里时会重新请求。")
        privacy.maximumNumberOfLines = 0
        stack.addArrangedSubview(privacy)
        return scrollView(for: stack)
    }

    private func makeHardwarePage() -> NSView {
        let stack = basePageStack()
        addHeader(to: stack, title: "硬件状态", subtitle: "查看 CPU、内存、电池、热状态、SMC 温度传感器、风扇转速和 GPU 基本信息。")
        addStatusBarToggle(to: stack, module: .hardware, title: "在顶部状态栏显示硬件状态")
        stack.addArrangedSubview(
            settingRow(
                title: "状态栏展示内容",
                detail: "选择硬件模块在顶部状态栏直接展示的指标；悬浮窗和菜单仍显示完整硬件快照。",
                control: hardwareMetricPopupButton()
            )
        )

        hardwareStatusLabel = secondaryLabel(hardwareStatusText(for: hardwareSnapshot))
        hardwareStatusLabel?.maximumNumberOfLines = 0
        addInfoPanel(to: stack, title: "当前硬件快照", content: hardwareStatusLabel!)

        let buttons = NSStackView()
        buttons.orientation = .horizontal
        buttons.spacing = 8
        buttons.addArrangedSubview(actionButton(title: "刷新硬件状态", action: #selector(refreshHardware)))
        buttons.addArrangedSubview(NSView())
        stack.addArrangedSubview(buttons)

        let note = secondaryLabel("风扇和温度来自 AppleSMC 传感器；部分 Apple Silicon 或无风扇机型可能不会暴露这些数据。GPU 使用率目前不使用不稳定接口，优先展示 GPU 名称和可读温度。")
        note.maximumNumberOfLines = 0
        stack.addArrangedSubview(note)
        return scrollView(for: stack)
    }

    private func makeCountdownPage() -> NSView {
        let stack = basePageStack()
        addHeader(to: stack, title: "倒计时", subtitle: "设置秒或分钟倒计时，在菜单栏实时显示剩余时间。")
        addStatusBarToggle(to: stack, module: .countdown, title: "在顶部状态栏显示倒计时")

        stack.addArrangedSubview(
            settingRow(
                title: "倒计时时长",
                detail: "可以输入秒或分钟；修改时会重置当前倒计时。",
                control: countdownDurationControls()
            )
        )
        stack.addArrangedSubview(
            settingRow(
                title: "临近提醒",
                detail: "剩余时间小于等于该值时，顶部状态栏倒计时会切换为提醒背景色。0 表示只在完成时变色。",
                control: countdownReminderLeadControls()
            )
        )
        stack.addArrangedSubview(
            settingRow(
                title: "提醒背景色",
                detail: "用于倒计时进入临近提醒或完成后的状态栏背景。",
                control: countdownReminderColorControl()
            )
        )

        countdownStatusLabel = secondaryLabel(countdownStatusText(for: countdownSnapshot))
        countdownStatusLabel?.maximumNumberOfLines = 0
        addInfoPanel(to: stack, title: "当前倒计时状态", content: countdownStatusLabel!)

        let buttons = NSStackView()
        buttons.orientation = .horizontal
        buttons.spacing = 8

        let primaryButton = actionButton(title: "开始", action: #selector(countdownPrimaryAction))
        primaryButton.widthAnchor.constraint(equalToConstant: 92).isActive = true
        countdownPrimaryButton = primaryButton
        buttons.addArrangedSubview(primaryButton)

        let resetButton = actionButton(title: "重置", action: #selector(countdownReset))
        resetButton.widthAnchor.constraint(equalToConstant: 92).isActive = true
        countdownResetButton = resetButton
        buttons.addArrangedSubview(resetButton)
        buttons.addArrangedSubview(NSView())
        stack.addArrangedSubview(buttons)

        let note = secondaryLabel("倒计时只保存在本次 App 运行中；重启 oneMenu 后会回到未开始状态，但时长设置会保留。")
        note.maximumNumberOfLines = 0
        stack.addArrangedSubview(note)
        updateCountdownButtons()
        return scrollView(for: stack)
    }

    private func makeTargetTimeCountdownPage() -> NSView {
        let stack = basePageStack()
        addHeader(to: stack, title: "目标时间分钟倒计", subtitle: "设置每天的目标时间，在菜单栏显示当前距离目标还有多少分钟。")
        addStatusBarToggle(to: stack, module: .targetTimeCountdown, title: "在顶部状态栏显示目标倒计")

        stack.addArrangedSubview(
            settingRow(
                title: "目标名称",
                detail: "显示在状态栏里的名称，例如下班、会议、收盘；留空时只显示剩余分钟。",
                control: targetTimeCountdownTitleControl()
            )
        )
        stack.addArrangedSubview(
            settingRow(
                title: "状态栏图标",
                detail: "关闭后目标倒计在顶部状态栏只显示文字，不显示时钟图标。",
                control: targetTimeCountdownIconControl()
            )
        )
        stack.addArrangedSubview(
            settingRow(
                title: "目标时间",
                detail: "以当天时间计算剩余分钟，例如 18:00。",
                control: targetTimeCountdownTimeControls()
            )
        )
        stack.addArrangedSubview(
            settingRow(
                title: "过点处理",
                detail: "默认过了目标时间显示 0，也可以切换为倒计到明天同一时间。",
                control: targetTimeCountdownPastBehaviorControl()
            )
        )
        stack.addArrangedSubview(
            settingRow(
                title: "状态栏背景色",
                detail: "设置目标倒计在顶部状态栏中的背景颜色，也可以保持默认透明。",
                control: targetTimeCountdownBackgroundColorControl()
            )
        )
        stack.addArrangedSubview(
            settingRow(
                title: "状态栏文字粗细",
                detail: "设置目标倒计在顶部状态栏里的文字字重。",
                control: targetTimeCountdownTextWeightControl()
            )
        )
        stack.addArrangedSubview(
            settingRow(
                title: "状态栏文字颜色",
                detail: "默认自动根据背景色选择，也可以指定固定文字颜色。",
                control: targetTimeCountdownTextColorControl()
            )
        )

        targetTimeCountdownStatusLabel = secondaryLabel(targetTimeCountdownStatusText())
        targetTimeCountdownStatusLabel?.maximumNumberOfLines = 0
        addInfoPanel(to: stack, title: "当前目标倒计", content: targetTimeCountdownStatusLabel!)

        let note = secondaryLabel("状态栏显示单位固定为分钟；目标时间前不足 1 分钟时显示 1 分，到了或超过目标时间后按过点处理规则显示。")
        note.maximumNumberOfLines = 0
        stack.addArrangedSubview(note)
        return scrollView(for: stack)
    }

    private func makeSystemReminderPage() -> NSView {
        let stack = basePageStack()
        addHeader(to: stack, title: "系统提醒", subtitle: "设置一个指定时间的 macOS 系统通知，可选择单次提醒或每日重复提醒。")
        addStatusBarToggle(to: stack, module: .systemReminder, title: "在顶部状态栏显示系统提醒")

        let enabledCheckbox = NSButton(checkboxWithTitle: "", target: self, action: #selector(systemReminderEnabledToggled(_:)))
        enabledCheckbox.state = systemReminderPreferences.isEnabled ? .on : .off
        systemReminderEnabledCheckbox = enabledCheckbox
        stack.addArrangedSubview(settingRow(title: "启用提醒", detail: "开启后 oneMenu 会向 macOS 通知中心注册这个提醒。", control: enabledCheckbox))

        stack.addArrangedSubview(
            settingRow(
                title: "提醒模式",
                detail: "单次提醒只触发一次；每日提醒会在每天相同时间触发。",
                control: systemReminderModeControl()
            )
        )
        stack.addArrangedSubview(
            settingRow(
                title: "提醒时间",
                detail: "单次提醒使用日期和时间；每日提醒只使用时间。",
                control: systemReminderDateControl()
            )
        )
        stack.addArrangedSubview(
            settingRow(
                title: "提醒标题",
                detail: "显示在 macOS 通知上的标题。",
                control: systemReminderTextField(
                    text: systemReminderPreferences.title,
                    width: 220,
                    action: #selector(systemReminderTextEdited(_:)),
                    assign: { [weak self] field in self?.systemReminderTitleField = field }
                )
            )
        )
        stack.addArrangedSubview(
            settingRow(
                title: "提醒内容",
                detail: "显示在通知正文中的提示内容。",
                control: systemReminderTextField(
                    text: systemReminderPreferences.message,
                    width: 220,
                    action: #selector(systemReminderTextEdited(_:)),
                    assign: { [weak self] field in self?.systemReminderMessageField = field }
                )
            )
        )

        systemReminderStatusLabel = secondaryLabel(systemReminderStatusText())
        systemReminderStatusLabel?.maximumNumberOfLines = 0
        addInfoPanel(to: stack, title: "当前提醒状态", content: systemReminderStatusLabel!)

        let buttons = NSStackView()
        buttons.orientation = .horizontal
        buttons.spacing = 8
        buttons.addArrangedSubview(actionButton(title: "发送测试提醒", action: #selector(sendSystemReminderTest)))
        buttons.addArrangedSubview(NSView())
        stack.addArrangedSubview(buttons)

        let note = secondaryLabel("首次使用需要允许 oneMenu 发送通知。若测试提醒也没有弹出，请检查系统设置里的 oneMenu 通知权限和专注模式。")
        note.maximumNumberOfLines = 0
        stack.addArrangedSubview(note)
        return scrollView(for: stack)
    }

    private func makeSleepPage() -> NSView {
        let stack = basePageStack()
        addHeader(to: stack, title: "防休眠", subtitle: "通过 macOS 电源断言阻止系统和显示器因空闲进入睡眠。")
        addStatusBarToggle(to: stack, module: .sleep, title: "在顶部状态栏显示防休眠状态（咖啡杯图标）")

        let sleepToggle = NSButton(checkboxWithTitle: "保持 Mac 活跃（防休眠）", target: self, action: #selector(sleepPreventionToggled(_:)))
        sleepToggle.state = sleepPreventionPreferences.isEnabled ? .on : .off
        self.sleepToggle = sleepToggle
        stack.addArrangedSubview(settingRow(title: "运行状态", detail: "开启后会立即创建系统和显示器防休眠断言。", control: sleepToggle))

        // Duration input
        let durationValue = sleepPreventionPreferences.durationMinutes
        let durationField = NSTextField()
        durationField.stringValue = String(durationValue)
        durationField.controlSize = .regular
        durationField.font = NSFont.monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        durationField.alignment = .right
        durationField.target = self
        durationField.action = #selector(sleepDurationChanged(_:))
        NSLayoutConstraint.activate([durationField.widthAnchor.constraint(equalToConstant: 60)])
        stack.addArrangedSubview(settingRow(
            title: "自动关闭时间（分钟）",
            detail: "0 = 一直保持活跃。默认 5 分钟后自动关闭防休眠。",
            control: durationField
        ))

        // Auto-start toggle
        let autoStartToggle = NSButton(checkboxWithTitle: "开机时自动启动 oneMenu", target: self, action: #selector(autoStartToggled(_:)))
        autoStartToggle.state = AutoStartPreferences.isEnabled ? .on : .off
        stack.addArrangedSubview(settingRow(title: "登录自启动", detail: "将 oneMenu 添加为 macOS 登录项（SMAppService）。", control: autoStartToggle))

        sleepStateLabel = secondaryLabel(sleepIsEnabled ? "当前状态：已开启" : "当前状态：已关闭")
        addInfoPanel(to: stack, title: "当前防休眠状态", content: sleepStateLabel!)
        return scrollView(for: stack)
    }

    @objc private func sleepDurationChanged(_ sender: NSTextField) {
        if let value = Int(sender.stringValue) {
            sleepPreventionPreferences.durationMinutes = value
        }
        onSleepPreferenceChange()
    }

    @objc private func autoStartToggled(_ sender: NSButton) {
        let enabled = sender.state == .on
        if enabled {
            AutoStartPreferences.enable()
        } else {
            AutoStartPreferences.disable()
        }
    }

    private func makeAppearancePage() -> NSView {
        let stack = basePageStack()
        addHeader(to: stack, title: "外观", subtitle: "切换 oneMenu 设置窗、悬浮窗和辅助窗口的浅色或深色外观。")

        stack.addArrangedSubview(
            settingRow(
                title: "亮暗色模式",
                detail: "选择跟随 macOS 系统，也可以固定为浅色或深色。",
                control: appearanceModeControl()
            )
        )

        appearanceStatusLabel = secondaryLabel(appearanceStatusText())
        appearanceStatusLabel?.maximumNumberOfLines = 0
        addInfoPanel(to: stack, title: "当前外观设置", content: appearanceStatusLabel!)

        let note = secondaryLabel("选择“跟随系统”时，oneMenu 不强制外观，会随 macOS 系统设置自动切换。")
        note.maximumNumberOfLines = 0
        stack.addArrangedSubview(note)
        return scrollView(for: stack)
    }

    private func makeNotificationsPage() -> NSView {
        let stack = basePageStack()
        addHeader(to: stack, title: "通知", subtitle: "配置会话结束桌面通知和全部 AI 工作结束后的邮件通知。")

        let notificationToggle = NSButton(checkboxWithTitle: "会话结束时发送通知", target: self, action: #selector(sessionNotificationToggled(_:)))
        notificationToggle.state = sessionNotificationPreferences.isEnabled ? .on : .off
        stack.addArrangedSubview(settingRow(title: "桌面 + 邮件通知", detail: "关闭后，所有会话结束通知（桌面横幅和邮件）都不会发送。", control: notificationToggle))

        addActionButton(to: stack, title: "配置邮件通知...", action: #selector(openEmailSettings))
        let emailHint = secondaryLabel("邮件配置会保存在 ~/.onemenu/email.json。邮件通知不占用状态栏项目。上方开关可统一关闭所有通知。")
        emailHint.maximumNumberOfLines = 0
        stack.addArrangedSubview(emailHint)
        return scrollView(for: stack)
    }

    private func basePageStack() -> NSStackView {
        let stack = SettingsPageStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 14
        stack.edgeInsets = NSEdgeInsets(
            top: Layout.pageTopInset,
            left: Layout.pageHorizontalInset,
            bottom: 28,
            right: Layout.pageHorizontalInset
        )
        return stack
    }

    private func scrollView(for stack: NSStackView) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.documentView = stack
        stack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stack.widthAnchor.constraint(equalTo: scrollView.contentView.widthAnchor),
            stack.heightAnchor.constraint(greaterThanOrEqualTo: scrollView.contentView.heightAnchor)
        ])
        return scrollView
    }

    private func addHeader(to stack: NSStackView, title: String, subtitle: String) {
        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.alignment = .left
        titleLabel.font = NSFont.systemFont(ofSize: 24, weight: .semibold)
        titleLabel.lineBreakMode = .byWordWrapping
        titleLabel.maximumNumberOfLines = 0
        titleLabel.preferredMaxLayoutWidth = Layout.contentWidth
        titleLabel.widthAnchor.constraint(equalToConstant: Layout.contentWidth).isActive = true
        stack.addArrangedSubview(titleLabel)

        let subtitleLabel = secondaryLabel(subtitle)
        subtitleLabel.alignment = .left
        subtitleLabel.maximumNumberOfLines = 0
        subtitleLabel.widthAnchor.constraint(equalToConstant: Layout.contentWidth).isActive = true
        stack.addArrangedSubview(subtitleLabel)
        stack.setCustomSpacing(24, after: subtitleLabel)
    }

    private func addStatusBarToggle(to stack: NSStackView, module: StatusBarModule, title: String) {
        let checkbox = NSButton(checkboxWithTitle: "", target: self, action: #selector(statusModuleToggled(_:)))
        checkbox.identifier = NSUserInterfaceItemIdentifier(module.rawValue)
        checkbox.state = statusBarDisplayPreferences.isVisible(module) ? .on : .off
        statusModuleCheckboxes[module] = checkbox
        stack.addArrangedSubview(settingRow(title: title, detail: "控制这个功能是否作为独立项目出现在 macOS 顶部状态栏。", control: checkbox))
    }

    private func addColorControls(to stack: NSStackView) {
        let runningPopup = colorPopup(selectedID: colorPreferences.runningColorID, role: "running")
        let idlePopup = colorPopup(selectedID: colorPreferences.idleColorID, role: "idle")
        stack.addArrangedSubview(settingRow(title: "运行时灯颜色", detail: "用于 Codex/GPT 或 Claude 正在处理任务时。", control: runningPopup))
        stack.addArrangedSubview(settingRow(title: "空闲时灯颜色", detail: "用于没有活跃任务时。", control: idlePopup))
    }

    private func hardwareMetricPopupButton() -> NSPopUpButton {
        let popup = NSPopUpButton(frame: .zero, pullsDown: false)
        popup.target = self
        popup.action = #selector(hardwareMetricChanged(_:))
        hardwareMetricPopup = popup

        for metric in HardwareStatusBarMetric.allCases {
            popup.addItem(withTitle: metric.title)
            popup.lastItem?.representedObject = metric.rawValue
        }

        syncHardwareMetricPopup()
        popup.widthAnchor.constraint(equalToConstant: 150).isActive = true
        return popup
    }

    private func addInfoPanel(to stack: NSStackView, title: String, content: NSTextField) {
        let label = NSTextField(labelWithString: title)
        label.alignment = .left
        label.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        label.widthAnchor.constraint(equalToConstant: Layout.contentWidth).isActive = true
        content.alignment = .left
        content.widthAnchor.constraint(equalToConstant: Layout.contentWidth).isActive = true
        stack.addArrangedSubview(label)
        stack.addArrangedSubview(content)
    }

    private func addActionButton(to stack: NSStackView, title: String, action: Selector) {
        stack.addArrangedSubview(actionButton(title: title, action: action))
    }

    private func settingRow(title: String, detail: String, control: NSView) -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 18

        let textStack = NSStackView()
        textStack.orientation = .vertical
        textStack.alignment = .leading
        textStack.spacing = 3

        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.alignment = .left
        titleLabel.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        let detailLabel = secondaryLabel(detail)
        detailLabel.alignment = .left
        detailLabel.maximumNumberOfLines = 0

        textStack.addArrangedSubview(titleLabel)
        textStack.addArrangedSubview(detailLabel)

        row.addArrangedSubview(textStack)
        row.addArrangedSubview(control)
        textStack.setContentHuggingPriority(.defaultLow, for: .horizontal)
        control.setContentHuggingPriority(.required, for: .horizontal)
        row.widthAnchor.constraint(equalToConstant: Layout.contentWidth).isActive = true
        return row
    }

    private func secondaryLabel(_ text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.alignment = .left
        label.font = NSFont.systemFont(ofSize: 12)
        label.textColor = .secondaryLabelColor
        label.lineBreakMode = .byWordWrapping
        label.preferredMaxLayoutWidth = Layout.contentWidth
        return label
    }

    private func actionButton(title: String, action: Selector) -> NSButton {
        let button = NSButton(title: title, target: self, action: action)
        button.bezelStyle = .rounded
        return button
    }

    private func countdownDurationControls() -> NSView {
        let controls = NSStackView()
        controls.orientation = .horizontal
        controls.alignment = .centerY
        controls.spacing = 8

        let formatter = NumberFormatter()
        formatter.numberStyle = .none
        formatter.minimum = 1
        formatter.maximum = 9_999
        formatter.allowsFloats = false

        let valueField = NSTextField(string: "\(countdownPreferences.durationValue)")
        valueField.alignment = .right
        valueField.font = NSFont.monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        valueField.formatter = formatter
        valueField.target = self
        valueField.action = #selector(countdownDurationEdited(_:))
        valueField.delegate = self
        valueField.widthAnchor.constraint(equalToConstant: 64).isActive = true
        countdownValueField = valueField

        let stepper = NSStepper()
        stepper.minValue = 1
        stepper.maxValue = 9_999
        stepper.increment = 1
        stepper.integerValue = countdownPreferences.durationValue
        stepper.target = self
        stepper.action = #selector(countdownStepperChanged(_:))
        countdownStepper = stepper

        let unitPopup = NSPopUpButton(frame: .zero, pullsDown: false)
        unitPopup.target = self
        unitPopup.action = #selector(countdownUnitChanged(_:))
        for unit in CountdownDurationUnit.allCases {
            unitPopup.addItem(withTitle: unit.title)
            unitPopup.lastItem?.representedObject = unit.rawValue
        }
        if let item = unitPopup.itemArray.first(where: { $0.representedObject as? String == countdownPreferences.durationUnit.rawValue }) {
            unitPopup.select(item)
        }
        unitPopup.widthAnchor.constraint(equalToConstant: 86).isActive = true
        countdownUnitPopup = unitPopup

        controls.addArrangedSubview(valueField)
        controls.addArrangedSubview(stepper)
        controls.addArrangedSubview(unitPopup)
        return controls
    }

    private func countdownReminderLeadControls() -> NSView {
        let controls = NSStackView()
        controls.orientation = .horizontal
        controls.alignment = .centerY
        controls.spacing = 8

        let formatter = NumberFormatter()
        formatter.numberStyle = .none
        formatter.minimum = 0
        formatter.maximum = 9_999
        formatter.allowsFloats = false

        let valueField = NSTextField(string: "\(countdownPreferences.reminderLeadValue)")
        valueField.alignment = .right
        valueField.font = NSFont.monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        valueField.formatter = formatter
        valueField.target = self
        valueField.action = #selector(countdownReminderLeadEdited(_:))
        valueField.delegate = self
        valueField.widthAnchor.constraint(equalToConstant: 64).isActive = true
        countdownReminderValueField = valueField

        let stepper = NSStepper()
        stepper.minValue = 0
        stepper.maxValue = 9_999
        stepper.increment = 1
        stepper.integerValue = countdownPreferences.reminderLeadValue
        stepper.target = self
        stepper.action = #selector(countdownReminderLeadStepperChanged(_:))
        countdownReminderStepper = stepper

        let unitPopup = NSPopUpButton(frame: .zero, pullsDown: false)
        unitPopup.target = self
        unitPopup.action = #selector(countdownReminderLeadUnitChanged(_:))
        for unit in CountdownDurationUnit.allCases {
            unitPopup.addItem(withTitle: unit.title)
            unitPopup.lastItem?.representedObject = unit.rawValue
        }
        if let item = unitPopup.itemArray.first(where: { $0.representedObject as? String == countdownPreferences.reminderLeadUnit.rawValue }) {
            unitPopup.select(item)
        }
        unitPopup.widthAnchor.constraint(equalToConstant: 86).isActive = true
        countdownReminderUnitPopup = unitPopup

        controls.addArrangedSubview(valueField)
        controls.addArrangedSubview(stepper)
        controls.addArrangedSubview(unitPopup)
        return controls
    }

    private func countdownReminderColorControl() -> NSView {
        let popup = NSPopUpButton(frame: .zero, pullsDown: false)
        popup.target = self
        popup.action = #selector(countdownReminderColorChanged(_:))
        for color in CountdownReminderColor.available {
            popup.addItem(withTitle: color.title)
            popup.lastItem?.representedObject = color.id
        }
        if let item = popup.itemArray.first(where: { $0.representedObject as? String == countdownPreferences.reminderColorID }) {
            popup.select(item)
        }
        popup.widthAnchor.constraint(equalToConstant: 130).isActive = true
        countdownReminderColorPopup = popup
        return popup
    }

    private func targetTimeCountdownTitleControl() -> NSView {
        let field = NSTextField(string: targetTimeCountdownPreferences.title)
        field.alignment = .left
        field.target = self
        field.action = #selector(targetTimeCountdownTitleEdited(_:))
        field.delegate = self
        field.widthAnchor.constraint(equalToConstant: 180).isActive = true
        targetTimeCountdownTitleField = field
        return field
    }

    private func targetTimeCountdownIconControl() -> NSView {
        let checkbox = NSButton(checkboxWithTitle: "", target: self, action: #selector(targetTimeCountdownIconToggled(_:)))
        checkbox.state = targetTimeCountdownPreferences.showsIcon ? .on : .off
        targetTimeCountdownIconCheckbox = checkbox
        return checkbox
    }

    private func targetTimeCountdownTimeControls() -> NSView {
        let controls = NSStackView()
        controls.orientation = .horizontal
        controls.alignment = .centerY
        controls.spacing = 6

        let hourField = targetTimeNumberField(
            value: targetTimeCountdownPreferences.targetHour,
            min: 0,
            max: 23,
            action: #selector(targetTimeCountdownHourEdited(_:))
        )
        targetTimeCountdownHourField = hourField

        let hourStepper = NSStepper()
        hourStepper.minValue = 0
        hourStepper.maxValue = 23
        hourStepper.increment = 1
        hourStepper.integerValue = targetTimeCountdownPreferences.targetHour
        hourStepper.target = self
        hourStepper.action = #selector(targetTimeCountdownHourStepperChanged(_:))
        targetTimeCountdownHourStepper = hourStepper

        let colon = NSTextField(labelWithString: ":")
        colon.alignment = .center
        colon.font = NSFont.monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .medium)

        let minuteField = targetTimeNumberField(
            value: targetTimeCountdownPreferences.targetMinute,
            min: 0,
            max: 59,
            action: #selector(targetTimeCountdownMinuteEdited(_:))
        )
        targetTimeCountdownMinuteField = minuteField

        let minuteStepper = NSStepper()
        minuteStepper.minValue = 0
        minuteStepper.maxValue = 59
        minuteStepper.increment = 1
        minuteStepper.integerValue = targetTimeCountdownPreferences.targetMinute
        minuteStepper.target = self
        minuteStepper.action = #selector(targetTimeCountdownMinuteStepperChanged(_:))
        targetTimeCountdownMinuteStepper = minuteStepper

        controls.addArrangedSubview(hourField)
        controls.addArrangedSubview(hourStepper)
        controls.addArrangedSubview(colon)
        controls.addArrangedSubview(minuteField)
        controls.addArrangedSubview(minuteStepper)
        return controls
    }

    private func targetTimeNumberField(value: Int, min: Int, max: Int, action: Selector) -> NSTextField {
        let formatter = NumberFormatter()
        formatter.numberStyle = .none
        formatter.minimum = NSNumber(value: min)
        formatter.maximum = NSNumber(value: max)
        formatter.allowsFloats = false

        let field = NSTextField(string: "\(value)")
        field.alignment = .right
        field.font = NSFont.monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        field.formatter = formatter
        field.target = self
        field.action = action
        field.delegate = self
        field.widthAnchor.constraint(equalToConstant: 44).isActive = true
        return field
    }

    private func targetTimeCountdownPastBehaviorControl() -> NSView {
        let popup = NSPopUpButton(frame: .zero, pullsDown: false)
        popup.target = self
        popup.action = #selector(targetTimeCountdownPastBehaviorChanged(_:))
        for behavior in TargetTimeCountdownPastBehavior.allCases {
            popup.addItem(withTitle: behavior.title)
            popup.lastItem?.representedObject = behavior.rawValue
        }
        if let item = popup.itemArray.first(where: { $0.representedObject as? String == targetTimeCountdownPreferences.pastBehavior.rawValue }) {
            popup.select(item)
        }
        popup.widthAnchor.constraint(equalToConstant: 130).isActive = true
        targetTimeCountdownPastBehaviorPopup = popup
        return popup
    }

    private func targetTimeCountdownBackgroundColorControl() -> NSView {
        let popup = NSPopUpButton(frame: .zero, pullsDown: false)
        popup.target = self
        popup.action = #selector(targetTimeCountdownBackgroundColorChanged(_:))
        for color in TargetTimeCountdownBackgroundColor.available {
            popup.addItem(withTitle: color.title)
            popup.lastItem?.representedObject = color.id
        }
        if let item = popup.itemArray.first(where: { $0.representedObject as? String == targetTimeCountdownPreferences.backgroundColorID }) {
            popup.select(item)
        }
        popup.widthAnchor.constraint(equalToConstant: 130).isActive = true
        targetTimeCountdownBackgroundColorPopup = popup
        return popup
    }

    private func targetTimeCountdownTextWeightControl() -> NSView {
        let popup = NSPopUpButton(frame: .zero, pullsDown: false)
        popup.target = self
        popup.action = #selector(targetTimeCountdownTextWeightChanged(_:))
        for weight in TargetTimeCountdownTextWeight.allCases {
            popup.addItem(withTitle: weight.title)
            popup.lastItem?.representedObject = weight.rawValue
        }
        if let item = popup.itemArray.first(where: { $0.representedObject as? String == targetTimeCountdownPreferences.textWeight.rawValue }) {
            popup.select(item)
        }
        popup.widthAnchor.constraint(equalToConstant: 130).isActive = true
        targetTimeCountdownTextWeightPopup = popup
        return popup
    }

    private func targetTimeCountdownTextColorControl() -> NSView {
        let popup = NSPopUpButton(frame: .zero, pullsDown: false)
        popup.target = self
        popup.action = #selector(targetTimeCountdownTextColorChanged(_:))
        for color in TargetTimeCountdownTextColor.available {
            popup.addItem(withTitle: color.title)
            popup.lastItem?.representedObject = color.id
        }
        if let item = popup.itemArray.first(where: { $0.representedObject as? String == targetTimeCountdownPreferences.textColorID }) {
            popup.select(item)
        }
        popup.widthAnchor.constraint(equalToConstant: 130).isActive = true
        targetTimeCountdownTextColorPopup = popup
        return popup
    }

    private func appearanceModeControl() -> NSView {
        let popup = NSPopUpButton(frame: .zero, pullsDown: false)
        popup.target = self
        popup.action = #selector(appearanceModeChanged(_:))
        for mode in AppAppearanceMode.allCases {
            popup.addItem(withTitle: mode.title)
            popup.lastItem?.representedObject = mode.rawValue
        }
        if let item = popup.itemArray.first(where: { $0.representedObject as? String == appearancePreferences.mode.rawValue }) {
            popup.select(item)
        }
        popup.widthAnchor.constraint(equalToConstant: 130).isActive = true
        appearanceModePopup = popup
        return popup
    }

    private func systemReminderModeControl() -> NSView {
        let popup = NSPopUpButton(frame: .zero, pullsDown: false)
        popup.target = self
        popup.action = #selector(systemReminderModeChanged(_:))
        for mode in SystemReminderMode.allCases {
            popup.addItem(withTitle: mode.title)
            popup.lastItem?.representedObject = mode.rawValue
        }
        if let item = popup.itemArray.first(where: { $0.representedObject as? String == systemReminderPreferences.mode.rawValue }) {
            popup.select(item)
        }
        popup.widthAnchor.constraint(equalToConstant: 130).isActive = true
        systemReminderModePopup = popup
        return popup
    }

    private func systemReminderDateControl() -> NSView {
        let datePicker = NSDatePicker()
        datePicker.datePickerStyle = .textFieldAndStepper
        datePicker.datePickerMode = .single
        datePicker.dateValue = systemReminderPreferences.scheduledDate
        datePicker.target = self
        datePicker.action = #selector(systemReminderDateChanged(_:))
        datePicker.widthAnchor.constraint(equalToConstant: 190).isActive = true
        systemReminderDatePicker = datePicker
        applySystemReminderDatePickerMode()
        return datePicker
    }

    private func systemReminderTextField(
        text: String,
        width: CGFloat,
        action: Selector,
        assign: (NSTextField) -> Void
    ) -> NSTextField {
        let field = NSTextField(string: text)
        field.alignment = .left
        field.target = self
        field.action = action
        field.delegate = self
        field.widthAnchor.constraint(equalToConstant: width).isActive = true
        assign(field)
        return field
    }

    private func syncCountdownDurationControls() {
        countdownValueField?.stringValue = "\(countdownPreferences.durationValue)"
        countdownStepper?.integerValue = countdownPreferences.durationValue

        if let item = countdownUnitPopup?.itemArray.first(where: { $0.representedObject as? String == countdownPreferences.durationUnit.rawValue }) {
            countdownUnitPopup?.select(item)
        }
    }

    private func syncCountdownReminderControls() {
        countdownReminderValueField?.stringValue = "\(countdownPreferences.reminderLeadValue)"
        countdownReminderStepper?.integerValue = countdownPreferences.reminderLeadValue

        if let item = countdownReminderUnitPopup?.itemArray.first(where: { $0.representedObject as? String == countdownPreferences.reminderLeadUnit.rawValue }) {
            countdownReminderUnitPopup?.select(item)
        }

        if let item = countdownReminderColorPopup?.itemArray.first(where: { $0.representedObject as? String == countdownPreferences.reminderColorID }) {
            countdownReminderColorPopup?.select(item)
        }
    }

    private func syncTargetTimeCountdownControls() {
        targetTimeCountdownTitleField?.stringValue = targetTimeCountdownPreferences.title
        targetTimeCountdownIconCheckbox?.state = targetTimeCountdownPreferences.showsIcon ? .on : .off
        targetTimeCountdownHourField?.stringValue = "\(targetTimeCountdownPreferences.targetHour)"
        targetTimeCountdownHourStepper?.integerValue = targetTimeCountdownPreferences.targetHour
        targetTimeCountdownMinuteField?.stringValue = String(format: "%02d", targetTimeCountdownPreferences.targetMinute)
        targetTimeCountdownMinuteStepper?.integerValue = targetTimeCountdownPreferences.targetMinute
        if let item = targetTimeCountdownPastBehaviorPopup?.itemArray.first(where: { $0.representedObject as? String == targetTimeCountdownPreferences.pastBehavior.rawValue }) {
            targetTimeCountdownPastBehaviorPopup?.select(item)
        }
        if let item = targetTimeCountdownBackgroundColorPopup?.itemArray.first(where: { $0.representedObject as? String == targetTimeCountdownPreferences.backgroundColorID }) {
            targetTimeCountdownBackgroundColorPopup?.select(item)
        }
        if let item = targetTimeCountdownTextWeightPopup?.itemArray.first(where: { $0.representedObject as? String == targetTimeCountdownPreferences.textWeight.rawValue }) {
            targetTimeCountdownTextWeightPopup?.select(item)
        }
        if let item = targetTimeCountdownTextColorPopup?.itemArray.first(where: { $0.representedObject as? String == targetTimeCountdownPreferences.textColorID }) {
            targetTimeCountdownTextColorPopup?.select(item)
        }
        updateTargetTimeCountdownStatus()
    }

    private func syncSystemReminderControls() {
        systemReminderEnabledCheckbox?.state = systemReminderPreferences.isEnabled ? .on : .off
        if let item = systemReminderModePopup?.itemArray.first(where: { $0.representedObject as? String == systemReminderPreferences.mode.rawValue }) {
            systemReminderModePopup?.select(item)
        }
        systemReminderDatePicker?.dateValue = systemReminderPreferences.scheduledDate
        systemReminderTitleField?.stringValue = systemReminderPreferences.title
        systemReminderMessageField?.stringValue = systemReminderPreferences.message
        applySystemReminderDatePickerMode()
        updateSystemReminderStatus()
    }

    private func syncAppearanceControls() {
        if let item = appearanceModePopup?.itemArray.first(where: { $0.representedObject as? String == appearancePreferences.mode.rawValue }) {
            appearanceModePopup?.select(item)
        }
        appearanceStatusLabel?.stringValue = appearanceStatusText()
    }

    private func applySystemReminderDatePickerMode() {
        if systemReminderPreferences.mode == .daily {
            systemReminderDatePicker?.datePickerElements = [.hourMinute]
        } else {
            systemReminderDatePicker?.datePickerElements = [.yearMonthDay, .hourMinute]
        }
    }

    private func syncCachedControls() {
        syncStatusModuleCheckboxes()
        syncHardwareMetricPopup()
        syncColorPopups()
        syncCountdownDurationControls()
        syncCountdownReminderControls()
        syncTargetTimeCountdownControls()
        syncSystemReminderControls()
        syncAppearanceControls()
        updateCountdownButtons()
    }

    private func syncStatusModuleCheckboxes() {
        for (module, checkbox) in statusModuleCheckboxes {
            checkbox.state = statusBarDisplayPreferences.isVisible(module) ? .on : .off
        }
    }

    private func syncHardwareMetricPopup() {
        guard let popup = hardwareMetricPopup,
              let item = popup.itemArray.first(where: { $0.representedObject as? String == hardwareStatusBarPreferences.metric.rawValue })
        else {
            return
        }
        popup.select(item)
    }

    private func syncColorPopups() {
        let selectedIDsByRole = [
            "running": colorPreferences.runningColorID,
            "idle": colorPreferences.idleColorID
        ]

        for (role, popups) in colorPopupsByRole {
            guard let selectedID = selectedIDsByRole[role] else {
                continue
            }

            for popup in popups {
                if let item = popup.itemArray.first(where: { $0.representedObject as? String == selectedID }) {
                    popup.select(item)
                }
            }
        }
    }

    private func updateCountdownButtons() {
        switch countdownSnapshot.state {
        case .idle:
            countdownPrimaryButton?.title = "开始"
            countdownResetButton?.isEnabled = false
        case .running:
            countdownPrimaryButton?.title = "暂停"
            countdownResetButton?.isEnabled = true
        case .paused:
            countdownPrimaryButton?.title = "继续"
            countdownResetButton?.isEnabled = true
        case .finished:
            countdownPrimaryButton?.title = "重新开始"
            countdownResetButton?.isEnabled = true
        }
    }

    private func colorPopup(selectedID: String, role: String) -> NSPopUpButton {
        let popup = NSPopUpButton(frame: .zero, pullsDown: false)
        popup.identifier = NSUserInterfaceItemIdentifier(role)
        popup.target = self
        popup.action = #selector(colorPopupChanged(_:))
        colorPopupsByRole[role, default: []].append(popup)

        for color in StatusLightColor.available {
            popup.addItem(withTitle: color.title)
            popup.lastItem?.representedObject = color.id
        }

        if let item = popup.itemArray.first(where: { $0.representedObject as? String == selectedID }) {
            popup.select(item)
        }

        popup.widthAnchor.constraint(equalToConstant: 130).isActive = true
        return popup
    }

    @objc private func statusModuleToggled(_ sender: NSButton) {
        guard let rawValue = sender.identifier?.rawValue,
              let module = StatusBarModule(rawValue: rawValue)
        else {
            return
        }

        let wantsVisible = sender.state == .on
        if !wantsVisible,
           statusBarDisplayPreferences.isVisible(module),
           StatusBarModule.allCases.filter({ statusBarDisplayPreferences.isVisible($0) }).count <= 1 {
            sender.state = .on
            showAlert(message: "至少保留一个状态栏项目", detail: "否则 oneMenu 会失去菜单栏入口。")
            return
        }

        statusBarDisplayPreferences.setVisible(wantsVisible, for: module)
        syncStatusModuleCheckboxes()
        if module == .weather, wantsVisible {
            onWeatherRefresh()
        }
        onChange()
    }

    @objc private func colorPopupChanged(_ sender: NSPopUpButton) {
        guard let selectedID = sender.selectedItem?.representedObject as? String,
              let role = sender.identifier?.rawValue
        else {
            return
        }

        if role == "running" {
            colorPreferences.runningColorID = selectedID
        } else {
            colorPreferences.idleColorID = selectedID
        }
        syncColorPopups()
        onChange()
    }

    @objc private func hardwareMetricChanged(_ sender: NSPopUpButton) {
        guard let rawValue = sender.selectedItem?.representedObject as? String,
              let metric = HardwareStatusBarMetric(rawValue: rawValue)
        else {
            return
        }

        hardwareStatusBarPreferences.metric = metric
        syncHardwareMetricPopup()
        onChange()
    }

    @objc private func sleepPreventionToggled(_ sender: NSButton) {
        sleepPreventionPreferences.isEnabled = sender.state == .on
        onSleepPreferenceChange()
    }

    @objc private func sessionNotificationToggled(_ sender: NSButton) {
        sessionNotificationPreferences.isEnabled = sender.state == .on
        onChange()
    }

    @objc private func systemReminderEnabledToggled(_ sender: NSButton) {
        systemReminderPreferences.isEnabled = sender.state == .on
        systemReminderDidChange()
    }

    @objc private func appearanceModeChanged(_ sender: NSPopUpButton) {
        guard let rawValue = sender.selectedItem?.representedObject as? String,
              let mode = AppAppearanceMode(rawValue: rawValue)
        else {
            return
        }
        guard appearancePreferences.mode != mode else {
            return
        }
        appearancePreferences.mode = mode
        syncAppearanceControls()
        onAppearanceChange()
    }

    @objc private func systemReminderModeChanged(_ sender: NSPopUpButton) {
        guard let rawValue = sender.selectedItem?.representedObject as? String,
              let mode = SystemReminderMode(rawValue: rawValue)
        else {
            return
        }
        guard systemReminderPreferences.mode != mode else {
            return
        }
        systemReminderPreferences.mode = mode
        systemReminderDidChange()
    }

    @objc private func systemReminderDateChanged(_ sender: NSDatePicker) {
        systemReminderPreferences.scheduledDate = sender.dateValue
        systemReminderDidChange()
    }

    @objc private func systemReminderTextEdited(_ sender: NSTextField) {
        applySystemReminderTextField(sender)
    }

    @objc private func sendSystemReminderTest() {
        onSystemReminderTest()
    }

    @objc private func targetTimeCountdownTitleEdited(_ sender: NSTextField) {
        applyTargetTimeCountdownTitle(sender.stringValue)
    }

    @objc private func targetTimeCountdownIconToggled(_ sender: NSButton) {
        let showsIcon = sender.state == .on
        guard targetTimeCountdownPreferences.showsIcon != showsIcon else {
            return
        }
        targetTimeCountdownPreferences.showsIcon = showsIcon
        targetTimeCountdownDidChange()
    }

    @objc private func targetTimeCountdownHourEdited(_ sender: NSTextField) {
        applyTargetTimeCountdownHour(sender.integerValue)
    }

    @objc private func targetTimeCountdownHourStepperChanged(_ sender: NSStepper) {
        applyTargetTimeCountdownHour(sender.integerValue)
    }

    @objc private func targetTimeCountdownMinuteEdited(_ sender: NSTextField) {
        applyTargetTimeCountdownMinute(sender.integerValue)
    }

    @objc private func targetTimeCountdownMinuteStepperChanged(_ sender: NSStepper) {
        applyTargetTimeCountdownMinute(sender.integerValue)
    }

    @objc private func targetTimeCountdownPastBehaviorChanged(_ sender: NSPopUpButton) {
        guard let rawValue = sender.selectedItem?.representedObject as? String,
              let behavior = TargetTimeCountdownPastBehavior(rawValue: rawValue)
        else {
            return
        }
        guard targetTimeCountdownPreferences.pastBehavior != behavior else {
            return
        }
        targetTimeCountdownPreferences.pastBehavior = behavior
        targetTimeCountdownDidChange()
    }

    @objc private func targetTimeCountdownBackgroundColorChanged(_ sender: NSPopUpButton) {
        guard let selectedID = sender.selectedItem?.representedObject as? String,
              TargetTimeCountdownBackgroundColor.available.contains(where: { $0.id == selectedID })
        else {
            return
        }
        guard targetTimeCountdownPreferences.backgroundColorID != selectedID else {
            return
        }
        targetTimeCountdownPreferences.backgroundColorID = selectedID
        targetTimeCountdownDidChange()
    }

    @objc private func targetTimeCountdownTextWeightChanged(_ sender: NSPopUpButton) {
        guard let rawValue = sender.selectedItem?.representedObject as? String,
              let weight = TargetTimeCountdownTextWeight(rawValue: rawValue)
        else {
            return
        }
        guard targetTimeCountdownPreferences.textWeight != weight else {
            return
        }
        targetTimeCountdownPreferences.textWeight = weight
        targetTimeCountdownDidChange()
    }

    @objc private func targetTimeCountdownTextColorChanged(_ sender: NSPopUpButton) {
        guard let selectedID = sender.selectedItem?.representedObject as? String,
              TargetTimeCountdownTextColor.available.contains(where: { $0.id == selectedID })
        else {
            return
        }
        guard targetTimeCountdownPreferences.textColorID != selectedID else {
            return
        }
        targetTimeCountdownPreferences.textColorID = selectedID
        targetTimeCountdownDidChange()
    }

    @objc private func refreshWeather() {
        onWeatherRefresh()
    }

    @objc private func refreshHardware() {
        onHardwareRefresh()
    }

    @objc private func countdownDurationEdited(_ sender: NSTextField) {
        applyCountdownDurationValue(sender.integerValue)
    }

    @objc private func countdownStepperChanged(_ sender: NSStepper) {
        applyCountdownDurationValue(sender.integerValue)
    }

    @objc private func countdownReminderLeadEdited(_ sender: NSTextField) {
        applyCountdownReminderLeadValue(sender.integerValue)
    }

    @objc private func countdownReminderLeadStepperChanged(_ sender: NSStepper) {
        applyCountdownReminderLeadValue(sender.integerValue)
    }

    @objc private func countdownReminderLeadUnitChanged(_ sender: NSPopUpButton) {
        guard let rawValue = sender.selectedItem?.representedObject as? String,
              let unit = CountdownDurationUnit(rawValue: rawValue)
        else {
            return
        }
        guard countdownPreferences.reminderLeadUnit != unit else {
            return
        }
        countdownPreferences.reminderLeadUnit = unit
        syncCountdownReminderControls()
        onCountdownReminderChange()
    }

    @objc private func countdownReminderColorChanged(_ sender: NSPopUpButton) {
        guard let selectedID = sender.selectedItem?.representedObject as? String,
              CountdownReminderColor.available.contains(where: { $0.id == selectedID })
        else {
            return
        }
        countdownPreferences.reminderColorID = selectedID
        syncCountdownReminderControls()
        onCountdownReminderChange()
    }

    @objc private func countdownUnitChanged(_ sender: NSPopUpButton) {
        guard let rawValue = sender.selectedItem?.representedObject as? String,
              let unit = CountdownDurationUnit(rawValue: rawValue)
        else {
            return
        }
        guard countdownPreferences.durationUnit != unit else {
            return
        }
        countdownPreferences.durationUnit = unit
        syncCountdownDurationControls()
        onCountdownDurationChange()
    }

    @objc private func countdownPrimaryAction() {
        switch countdownSnapshot.state {
        case .idle, .finished:
            onCountdownStart()
        case .running:
            onCountdownPause()
        case .paused:
            onCountdownResume()
        }
    }

    @objc private func countdownReset() {
        onCountdownReset()
    }

    func controlTextDidChange(_ notification: Notification) {
        guard let field = notification.object as? NSTextField,
              field === targetTimeCountdownTitleField
        else {
            return
        }

        applyTargetTimeCountdownTitle(field.stringValue, shouldSyncControls: false)
    }

    func controlTextDidEndEditing(_ notification: Notification) {
        guard let field = notification.object as? NSTextField else {
            return
        }
        if field === countdownValueField {
            applyCountdownDurationValue(field.integerValue)
        } else if field === countdownReminderValueField {
            applyCountdownReminderLeadValue(field.integerValue)
        } else if field === targetTimeCountdownTitleField {
            applyTargetTimeCountdownTitle(field.stringValue)
        } else if field === targetTimeCountdownHourField {
            applyTargetTimeCountdownHour(field.integerValue)
        } else if field === targetTimeCountdownMinuteField {
            applyTargetTimeCountdownMinute(field.integerValue)
        } else if field === systemReminderTitleField || field === systemReminderMessageField {
            applySystemReminderTextField(field)
        }
    }

    private func applyCountdownDurationValue(_ value: Int) {
        let sanitizedValue = min(max(value, 1), 9_999)
        guard countdownPreferences.durationValue != sanitizedValue else {
            syncCountdownDurationControls()
            return
        }
        countdownPreferences.durationValue = sanitizedValue
        syncCountdownDurationControls()
        onCountdownDurationChange()
    }

    private func applyCountdownReminderLeadValue(_ value: Int) {
        let sanitizedValue = min(max(value, 0), 9_999)
        guard countdownPreferences.reminderLeadValue != sanitizedValue else {
            syncCountdownReminderControls()
            return
        }
        countdownPreferences.reminderLeadValue = sanitizedValue
        syncCountdownReminderControls()
        onCountdownReminderChange()
    }

    private func applyTargetTimeCountdownTitle(_ title: String, shouldSyncControls: Bool = true) {
        let previousTitle = targetTimeCountdownPreferences.title
        targetTimeCountdownPreferences.title = title
        guard targetTimeCountdownPreferences.title != previousTitle else {
            if shouldSyncControls {
                syncTargetTimeCountdownControls()
            }
            return
        }

        if shouldSyncControls {
            targetTimeCountdownDidChange()
        } else {
            updateTargetTimeCountdownStatus()
            onTargetTimeCountdownChange()
        }
    }

    private func applyTargetTimeCountdownHour(_ hour: Int) {
        let sanitizedHour = min(max(hour, 0), 23)
        guard targetTimeCountdownPreferences.targetHour != sanitizedHour else {
            syncTargetTimeCountdownControls()
            return
        }
        targetTimeCountdownPreferences.targetHour = sanitizedHour
        targetTimeCountdownDidChange()
    }

    private func applyTargetTimeCountdownMinute(_ minute: Int) {
        let sanitizedMinute = min(max(minute, 0), 59)
        guard targetTimeCountdownPreferences.targetMinute != sanitizedMinute else {
            syncTargetTimeCountdownControls()
            return
        }
        targetTimeCountdownPreferences.targetMinute = sanitizedMinute
        targetTimeCountdownDidChange()
    }

    private func targetTimeCountdownDidChange() {
        syncTargetTimeCountdownControls()
        onTargetTimeCountdownChange()
    }

    private func applySystemReminderTextField(_ field: NSTextField) {
        if field === systemReminderTitleField {
            systemReminderPreferences.title = field.stringValue
        } else if field === systemReminderMessageField {
            systemReminderPreferences.message = field.stringValue
        }
        systemReminderDidChange()
    }

    private func systemReminderDidChange() {
        syncSystemReminderControls()
        onSystemReminderChange()
    }

    @objc private func openLocationSettings() {
        onOpenLocationSettings()
    }

    @objc private func openCodexFolder() {
        onOpenCodexFolder()
    }

    @objc private func openClaudeFolder() {
        onOpenClaudeFolder()
    }

    @objc private func openEmailSettings() {
        onOpenEmailSettings()
    }

    private func showAlert(message: String, detail: String) {
        guard let window else {
            return
        }
        let alert = NSAlert()
        alert.messageText = message
        alert.informativeText = detail
        alert.alertStyle = .informational
        alert.beginSheetModal(for: window)
    }

    private func weatherStatusText(for snapshot: WeatherServiceSnapshot) -> String {
        switch snapshot {
        case .idle:
            return "尚未开始获取天气。"
        case .waitingForPermission:
            return "等待 macOS 定位权限。"
        case .locating:
            return "正在定位当前位置。"
        case let .loading(previous):
            if let previous {
                return "正在更新。当前缓存：\(weatherSummary(for: previous))"
            }
            return "正在请求天气服务。"
        case let .forecast(forecast):
            return weatherSummary(for: forecast)
        case let .failed(message, previous):
            if let previous {
                return "更新失败：\(message)。当前缓存：\(weatherSummary(for: previous))"
            }
            return "更新失败：\(message)"
        case .permissionDenied:
            return "定位权限未开启。请在系统设置中允许 oneMenu 使用定位。"
        case let .locationUnavailable(message):
            return message
        }
    }

    private func weatherSummary(for forecast: WeatherForecast) -> String {
        let updatedAt = DateFormatter.localizedString(from: forecast.fetchedAt, dateStyle: .none, timeStyle: .short)
        let current = forecast.current
        return "\(current.condition.title) \(Int(round(current.temperature)))°C，更新于 \(updatedAt)。"
    }

    private func hardwareStatusText(for snapshot: HardwareStatusSnapshot?) -> String {
        guard let snapshot else {
            return "等待首次硬件采样。CPU 使用率需要两次采样后显示。"
        }

        let cpu = "CPU \(percentText(snapshot.cpuUsagePercent))"
        let memory = "内存 \(percentText(snapshot.memory.usedPercent))"
        let battery = snapshot.battery.map { "电池 \($0.percent)%" } ?? "电池未检测到"
        let thermal = "热状态 \(thermalStateText(snapshot.thermalState))"
        let cpuTemp = snapshot.cpuTemperature.map { "CPU 温度 \(temperatureText($0.celsius))" } ?? "CPU 温度不可用"
        let gpu = snapshot.gpu.name.map { "GPU \($0)" } ?? "GPU 未识别"
        let gpuTemp = snapshot.gpuTemperature.map { "GPU 温度 \(temperatureText($0.celsius))" } ?? "GPU 温度不可用"
        let fans = snapshot.fans.isEmpty
            ? "风扇数据不可用"
            : snapshot.fans.map { "\($0.name) \(Int(round($0.rpm))) RPM" }.joined(separator: "，")

        return [cpu, memory, battery, thermal, cpuTemp, gpu, gpuTemp, fans].joined(separator: "\n")
    }

    private func systemReminderStatusText() -> String {
        let snapshot = systemReminderPreferences.snapshot()
        guard snapshot.isEnabled else {
            return "未启用。当前设置：\(systemReminderScheduledText(for: snapshot))。\n注册状态：\(systemReminderRegistrationStatus)"
        }

        guard let nextFireDate = snapshot.nextFireDate else {
            return "单次提醒时间已过期。请重新选择未来时间。\n注册状态：\(systemReminderRegistrationStatus)"
        }

        return "\(snapshot.mode.title)，下次提醒：\(systemReminderDateText(nextFireDate))。\n注册状态：\(systemReminderRegistrationStatus)\n标题：\(snapshot.title)\n内容：\(snapshot.message)"
    }

    private func appearanceStatusText() -> String {
        let mode = appearancePreferences.mode
        return "\(mode.title)：\(mode.description)"
    }

    private func targetTimeCountdownStatusText() -> String {
        let snapshot = targetTimeCountdownPreferences.snapshot()
        let title = snapshot.title.isEmpty ? "未设置名称" : snapshot.title
        let target = targetTimeCountdownTimeText(hour: snapshot.targetHour, minute: snapshot.targetMinute)
        let status = snapshot.isPastTodayTarget ? "今天已过目标时间" : "尚未到目标时间"
        let background = TargetTimeCountdownBackgroundColor.color(for: targetTimeCountdownPreferences.backgroundColorID).title
        let textWeight = targetTimeCountdownPreferences.textWeight.title
        let textColor = TargetTimeCountdownTextColor.color(for: targetTimeCountdownPreferences.textColorID).title
        let icon = targetTimeCountdownPreferences.showsIcon ? "显示" : "隐藏"
        return "目标名称：\(title)。目标时间：\(target)，剩余 \(snapshot.minutesRemaining) 分钟。\n过点处理：\(snapshot.pastBehavior.title)。图标：\(icon)。背景色：\(background)。文字：\(textWeight) / \(textColor)。\(status)。"
    }

    private func targetTimeCountdownTimeText(hour: Int, minute: Int) -> String {
        String(format: "%02d:%02d", hour, minute)
    }

    private func systemReminderScheduledText(for snapshot: SystemReminderSnapshot) -> String {
        switch snapshot.mode {
        case .once:
            return systemReminderDateText(snapshot.scheduledDate)
        case .daily:
            return "每日 \(systemReminderTimeText(snapshot.scheduledDate))"
        }
    }

    private func systemReminderDateText(_ date: Date) -> String {
        DateFormatter.localizedString(from: date, dateStyle: .short, timeStyle: .short)
    }

    private func systemReminderTimeText(_ date: Date) -> String {
        DateFormatter.localizedString(from: date, dateStyle: .none, timeStyle: .short)
    }

    private func countdownStatusText(for snapshot: CountdownSnapshot) -> String {
        let remaining = countdownTimeText(snapshot.remainingSeconds)
        let total = countdownTimeText(snapshot.totalSeconds)

        switch snapshot.state {
        case .idle:
            return "未开始。当前设置：\(total)。"
        case .running:
            return "运行中。剩余 \(remaining)，总时长 \(total)。"
        case .paused:
            return "已暂停。剩余 \(remaining)，总时长 \(total)。"
        case .finished:
            return "已完成。总时长 \(total)。"
        }
    }

    private func countdownTimeText(_ seconds: Int) -> String {
        let safeSeconds = max(0, seconds)
        if safeSeconds >= 3_600 {
            return String(format: "%d:%02d:%02d", safeSeconds / 3_600, (safeSeconds % 3_600) / 60, safeSeconds % 60)
        }
        return String(format: "%d:%02d", safeSeconds / 60, safeSeconds % 60)
    }

    private func percentText(_ value: Double?) -> String {
        guard let value else {
            return "--%"
        }
        return "\(Int(round(value)))%"
    }

    private func temperatureText(_ value: Double) -> String {
        "\(Int(round(value)))°C"
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
}

private final class SettingsPageStackView: NSStackView {
    override var isFlipped: Bool {
        true
    }
}

private final class SettingsSidebarItemView: NSControl {
    private let iconView = NSImageView()
    private let titleLabel: NSTextField
    private let subtitleLabel: NSTextField
    private var trackingArea: NSTrackingArea?
    private var isHovering = false

    var isSelected = false {
        didSet {
            updateAppearance()
        }
    }

    init(title: String, subtitle: String, symbolName: String) {
        self.titleLabel = NSTextField(labelWithString: title)
        self.subtitleLabel = NSTextField(labelWithString: subtitle)
        super.init(frame: .zero)

        wantsLayer = true
        layer?.cornerRadius = 7

        let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: title)
        image?.isTemplate = true
        iconView.image = image
        iconView.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 14, weight: .medium)

        titleLabel.alignment = .left
        titleLabel.font = NSFont.systemFont(ofSize: 12.5, weight: .semibold)
        titleLabel.lineBreakMode = .byClipping
        titleLabel.maximumNumberOfLines = 1

        subtitleLabel.alignment = .left
        subtitleLabel.font = NSFont.systemFont(ofSize: 10.5, weight: .regular)
        subtitleLabel.lineBreakMode = .byClipping
        subtitleLabel.maximumNumberOfLines = 1

        let textStack = NSStackView()
        textStack.orientation = .vertical
        textStack.alignment = .leading
        textStack.spacing = 1
        textStack.addArrangedSubview(titleLabel)
        textStack.addArrangedSubview(subtitleLabel)

        addSubview(iconView)
        addSubview(textStack)
        iconView.translatesAutoresizingMaskIntoConstraints = false
        textStack.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 18),
            iconView.heightAnchor.constraint(equalToConstant: 18),

            textStack.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 8),
            textStack.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -8),
            textStack.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])

        setAccessibilityElement(true)
        setAccessibilityRole(.button)
        setAccessibilityLabel("\(title)，\(subtitle)")
        updateAppearance()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func mouseDown(with event: NSEvent) {
        guard isEnabled else {
            return
        }
        sendAction(action, to: target)
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea {
            removeTrackingArea(trackingArea)
        }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect],
            owner: self
        )
        addTrackingArea(area)
        trackingArea = area
    }

    override func mouseEntered(with event: NSEvent) {
        isHovering = true
        updateAppearance()
    }

    override func mouseExited(with event: NSEvent) {
        isHovering = false
        updateAppearance()
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateAppearance()
    }

    private func updateAppearance() {
        if isSelected {
            layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.18).cgColor
            iconView.contentTintColor = .controlAccentColor
            titleLabel.textColor = .labelColor
            subtitleLabel.textColor = .secondaryLabelColor
        } else if isHovering {
            layer?.backgroundColor = NSColor.labelColor.withAlphaComponent(0.07).cgColor
            iconView.contentTintColor = .secondaryLabelColor
            titleLabel.textColor = .labelColor
            subtitleLabel.textColor = .secondaryLabelColor
        } else {
            layer?.backgroundColor = NSColor.clear.cgColor
            iconView.contentTintColor = .secondaryLabelColor
            titleLabel.textColor = .labelColor
            subtitleLabel.textColor = .secondaryLabelColor
        }
    }
}
