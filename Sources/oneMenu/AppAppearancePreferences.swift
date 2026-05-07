import AppKit
import Foundation

enum AppAppearanceMode: String, CaseIterable {
    case system
    case light
    case dark

    var title: String {
        switch self {
        case .system:
            return "跟随系统"
        case .light:
            return "浅色"
        case .dark:
            return "深色"
        }
    }

    var description: String {
        switch self {
        case .system:
            return "根据 macOS 系统亮暗色自动切换。"
        case .light:
            return "始终使用浅色外观。"
        case .dark:
            return "始终使用深色外观。"
        }
    }

    var appearanceName: NSAppearance.Name? {
        switch self {
        case .system:
            return nil
        case .light:
            return .aqua
        case .dark:
            return .darkAqua
        }
    }
}

final class AppAppearancePreferences {
    private enum Key {
        static let mode = "appAppearanceMode"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var mode: AppAppearanceMode {
        get {
            guard let rawValue = defaults.string(forKey: Key.mode),
                  let mode = AppAppearanceMode(rawValue: rawValue)
            else {
                return .system
            }
            return mode
        }
        set {
            defaults.set(newValue.rawValue, forKey: Key.mode)
        }
    }

    var appearance: NSAppearance? {
        guard let name = mode.appearanceName else {
            return nil
        }
        return NSAppearance(named: name)
    }
}
