import Foundation
import NahtKeyCore

/// Optional behavior starts disabled; the existing VNI/Telex policy stays the default.
struct KeyboardPreferences: Codable, Equatable {
    var typing = TypingOptions()
    var restoreWithEscape = false
    var rememberPerApplication = false
    var expandPhrases = false
    var toggleShortcut = ToggleShortcut.controlShift

    static let storageKey = "keyboardPreferences"

    static func load(from defaults: UserDefaults) -> Self {
        guard let data = defaults.data(forKey: storageKey),
              let value = try? JSONDecoder().decode(Self.self, from: data) else { return Self() }
        return value
    }

    func save(to defaults: UserDefaults) {
        if let data = try? JSONEncoder().encode(self) { defaults.set(data, forKey: Self.storageKey) }
    }
}

enum ToggleShortcut: String, CaseIterable, Codable, Identifiable {
    case controlShift, commandShift, controlOption, disabled

    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .controlShift: return "Ctrl + Shift"
        case .commandShift: return "Cmd + Shift"
        case .controlOption: return "Ctrl + Option"
        case .disabled: return "Không dùng phím tắt"
        }
    }
}
