import AppKit
import CodexStatusCore

final class EmailConfigWindowController: NSWindowController {
    private let enabledCheckbox = NSButton(checkboxWithTitle: "启用邮件通知", target: nil, action: nil)
    private let smtpURLField = NSTextField(frame: .zero)
    private let usernameField = NSTextField(frame: .zero)
    private let passwordSecureField = PasteableSecureTextField(frame: .zero)
    private let passwordPlainField = NSTextField(frame: .zero)
    private let passwordCommandField = NSTextField(frame: .zero)
    private let fromField = NSTextField(frame: .zero)
    private let toField = NSTextField(frame: .zero)
    private let subjectField = NSTextField(frame: .zero)
    private let tlsCheckbox = NSButton(checkboxWithTitle: "使用 TLS", target: nil, action: nil)

    private let passwordLabel = NSTextField(labelWithString: "授权码：")
    private let passwordCommandLabel = NSTextField(labelWithString: "密码命令：")
    private let passwordHint = NSTextField(labelWithString: "授权码和密码命令二选一。QQ/163 等邮箱请填写授权码而非登录密码。密码命令如 security find-generic-password -w -s aistatus-smtp")
    private let showPasswordCheckbox = NSButton(checkboxWithTitle: "显示授权码", target: nil, action: nil)

    private var formStack: NSStackView!

    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 500),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "邮件通知设置"
        window.center()
        self.init(window: window)
        buildUI()
        loadCurrentConfig()
    }

    private func buildUI() {
        guard let window else { return }

        let contentView = NSView(frame: window.contentLayoutRect)
        window.contentView = contentView

        smtpURLField.placeholderString = "smtps://smtp.example.com:465"
        usernameField.placeholderString = "sender@example.com"
        passwordSecureField.placeholderString = "SMTP 授权码（留空则使用密码命令）"
        passwordPlainField.placeholderString = "SMTP 授权码（留空则使用密码命令）"
        passwordCommandField.placeholderString = "security find-generic-password -w -s aistatus-smtp"
        fromField.placeholderString = "sender@example.com"
        toField.placeholderString = "recipient@example.com"
        subjectField.placeholderString = "AiStatus: all AI work finished"

        passwordPlainField.isHidden = true

        passwordHint.font = NSFont.systemFont(ofSize: 10)
        passwordHint.textColor = .secondaryLabelColor
        passwordHint.lineBreakMode = .byWordWrapping
        passwordHint.maximumNumberOfLines = 0
        passwordHint.preferredMaxLayoutWidth = 400

        showPasswordCheckbox.font = NSFont.systemFont(ofSize: 11)
        showPasswordCheckbox.target = self
        showPasswordCheckbox.action = #selector(togglePasswordVisibility)

        formStack = NSStackView()
        formStack.orientation = .vertical
        formStack.spacing = 8
        formStack.alignment = .leading
        formStack.distribution = .fill

        let enabledRow = NSStackView(views: [enabledCheckbox])
        enabledRow.alignment = .centerY
        formStack.addArrangedSubview(enabledRow)
        formStack.setCustomSpacing(12, after: enabledRow)

        addFormRow(label: "SMTP 地址：", control: smtpURLField, controlWidth: 320)
        addFormRow(label: "用户名：", control: usernameField, controlWidth: 320)
        addFormRow(label: "", control: passwordLabel)

        // Password row: secure field + plain field + show checkbox
        let passwordRow = NSStackView()
        passwordRow.alignment = .centerY
        passwordRow.spacing = 6
        passwordSecureField.widthAnchor.constraint(equalToConstant: 240).isActive = true
        passwordPlainField.widthAnchor.constraint(equalToConstant: 240).isActive = true
        passwordRow.addArrangedSubview(passwordSecureField)
        passwordRow.addArrangedSubview(passwordPlainField)
        passwordRow.addArrangedSubview(showPasswordCheckbox)
        formStack.addArrangedSubview(passwordRow)

        addFormRow(label: "", control: passwordCommandLabel)
        addFormRow(label: "", control: passwordCommandField, controlWidth: 360)
        addFormRow(label: "", control: passwordHint)
        formStack.setCustomSpacing(0, after: formStack.arrangedSubviews.last!)

        addFormRow(label: "发件人：", control: fromField, controlWidth: 320)
        addFormRow(label: "收件人：", control: toField, controlWidth: 320)
        addFormRow(label: "主题：", control: subjectField, controlWidth: 320)

        let tlsRow = NSStackView(views: [tlsCheckbox])
        tlsRow.alignment = .centerY
        formStack.addArrangedSubview(tlsRow)
        formStack.setCustomSpacing(16, after: tlsRow)

        // Buttons
        let buttonsRow = NSStackView()
        buttonsRow.spacing = 8
        buttonsRow.distribution = .fill

        let cancelButton = NSButton(title: "取消", target: self, action: #selector(cancelAction))
        cancelButton.bezelStyle = .rounded
        cancelButton.keyEquivalent = "\u{1b}"

        let saveButton = NSButton(title: "保存", target: self, action: #selector(saveAction))
        saveButton.bezelStyle = .rounded
        saveButton.keyEquivalent = "\r"

        buttonsRow.addArrangedSubview(NSView()) // spacer
        buttonsRow.addArrangedSubview(cancelButton)
        buttonsRow.addArrangedSubview(saveButton)
        formStack.addArrangedSubview(buttonsRow)

        contentView.addSubview(formStack)
        formStack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            formStack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            formStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            formStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20)
        ])

        enabledCheckbox.target = self
        enabledCheckbox.action = #selector(enabledToggled)
        updateFieldStates()
    }

    private func addFormRow(label labelText: String, control: NSView, controlWidth: CGFloat = 360) {
        let row = NSStackView()
        row.alignment = .centerY
        row.spacing = 4
        row.distribution = .fill

        if !labelText.isEmpty {
            let label = NSTextField(labelWithString: labelText)
            label.widthAnchor.constraint(equalToConstant: 80).isActive = true
            row.addArrangedSubview(label)
        }
        row.addArrangedSubview(control)

        if let textField = control as? NSTextField {
            textField.widthAnchor.constraint(equalToConstant: controlWidth).isActive = true
        } else if let secureField = control as? NSSecureTextField {
            secureField.widthAnchor.constraint(equalToConstant: controlWidth).isActive = true
        }

        formStack.addArrangedSubview(row)
    }

    private var passwordValue: String {
        get {
            showPasswordCheckbox.state == .on
                ? passwordPlainField.stringValue
                : passwordSecureField.stringValue
        }
        set {
            passwordSecureField.stringValue = newValue
            passwordPlainField.stringValue = newValue
        }
    }

    @objc private func togglePasswordVisibility() {
        let showing = showPasswordCheckbox.state == .on
        if showing {
            passwordPlainField.stringValue = passwordSecureField.stringValue
        } else {
            passwordSecureField.stringValue = passwordPlainField.stringValue
        }
        passwordSecureField.isHidden = showing
        passwordPlainField.isHidden = !showing
    }

    private func loadCurrentConfig() {
        do {
            guard let config = try EmailNotificationConfigLoader.load() else {
                enabledCheckbox.state = .off
                updateFieldStates()
                return
            }

            enabledCheckbox.state = .on
            smtpURLField.stringValue = config.smtpURL
            usernameField.stringValue = config.username ?? ""
            passwordValue = config.password ?? ""
            passwordCommandField.stringValue = config.passwordCommand ?? ""
            fromField.stringValue = config.from
            toField.stringValue = config.to.joined(separator: ", ")
            subjectField.stringValue = config.subject
            tlsCheckbox.state = config.requiresTLS ? .on : .off
        } catch {
            let alert = NSAlert()
            alert.messageText = "加载邮件配置失败"
            alert.informativeText = error.localizedDescription
            alert.alertStyle = .warning
            alert.beginSheetModal(for: window!, completionHandler: nil)
        }
        updateFieldStates()
    }

    @objc private func enabledToggled() {
        updateFieldStates()
    }

    private func updateFieldStates() {
        let enabled = enabledCheckbox.state == .on
        for view in formStack.arrangedSubviews {
            if let row = view as? NSStackView {
                for subview in row.arrangedSubviews {
                    if let control = subview as? NSControl {
                        control.isEnabled = enabled
                    }
                }
            }
        }
        enabledCheckbox.isEnabled = true
    }

    @objc private func cancelAction() {
        window?.close()
    }

    @objc private func saveAction() {
        guard enabledCheckbox.state == .on else {
            saveDisabledConfig()
            return
        }

        let smtpURL = smtpURLField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let username = usernameField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let password = passwordValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let passwordCommand = passwordCommandField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let from = fromField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let to = toField.stringValue
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let subject = subjectField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !smtpURL.isEmpty, !from.isEmpty, !to.isEmpty else {
            let alert = NSAlert()
            alert.messageText = "必填字段不完整"
            alert.informativeText = "SMTP 地址、发件人和收件人为必填项。"
            alert.alertStyle = .warning
            alert.beginSheetModal(for: window!, completionHandler: nil)
            return
        }

        guard let components = URLComponents(string: smtpURL),
              let scheme = components.scheme?.lowercased(),
              ["smtp", "smtps"].contains(scheme),
              components.host != nil
        else {
            let alert = NSAlert()
            alert.messageText = "SMTP 地址无效"
            alert.informativeText = "SMTP 地址必须以 smtp:// 或 smtps:// 开头，并包含有效的主机名。"
            alert.alertStyle = .warning
            alert.beginSheetModal(for: window!, completionHandler: nil)
            return
        }

        var config: [String: Any] = [
            "enabled": true,
            "smtpURL": smtpURL,
            "from": from,
            "to": to,
            "subject": subject.isEmpty ? "AiStatus: all AI work finished" : subject,
            "requiresTLS": tlsCheckbox.state == .on
        ]

        if !username.isEmpty { config["username"] = username }
        if !password.isEmpty { config["password"] = password }
        if !passwordCommand.isEmpty { config["passwordCommand"] = passwordCommand }

        writeConfig(config)
    }

    private func saveDisabledConfig() {
        writeConfig(["enabled": false])
    }

    private func writeConfig(_ config: [String: Any]) {
        let configDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".aistatus", isDirectory: true)
        let configURL = configDir.appendingPathComponent("email.json")

        do {
            try FileManager.default.createDirectory(at: configDir, withIntermediateDirectories: true)
            let data = try JSONSerialization.data(withJSONObject: config, options: .prettyPrinted)
            try data.write(to: configURL, options: .atomic)
            window?.close()
        } catch {
            let alert = NSAlert()
            alert.messageText = "保存配置失败"
            alert.informativeText = error.localizedDescription
            alert.alertStyle = .warning
            alert.beginSheetModal(for: window!, completionHandler: nil)
        }
    }
}

/// NSSecureTextField that allows pasting.
private final class PasteableSecureTextField: NSSecureTextField {
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard event.type == .keyDown,
              event.modifierFlags.contains(.command),
              event.charactersIgnoringModifiers == "v"
        else {
            return super.performKeyEquivalent(with: event)
        }

        guard let pasteboardString = NSPasteboard.general.string(forType: .string) else {
            return false
        }

        let currentValue = stringValue
        let range = currentEditor()?.selectedRange ?? NSRange(location: currentValue.count, length: 0)
        let startIndex = currentValue.index(currentValue.startIndex, offsetBy: range.location, limitedBy: currentValue.endIndex) ?? currentValue.startIndex
        let endIndex = currentValue.index(startIndex, offsetBy: range.length, limitedBy: currentValue.endIndex) ?? currentValue.endIndex
        stringValue = currentValue.replacingCharacters(in: startIndex..<endIndex, with: pasteboardString)
        return true
    }
}
