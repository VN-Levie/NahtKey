import Foundation
import NahtKeyCore

enum ReplacementOperation: Equatable {
    case text(String)
    case backspace
    case selectPreviousCharacter
}

/// A complete synchronous transaction. It never includes the physical delimiter;
/// Quartz inserts these operations before the event returned by the tap callback.
enum ReplacementPlan {
    static let selectionGuard = "\u{202F}"

    static func operations(for edit: TextEdit, protectAutocomplete: Bool) -> [ReplacementOperation] {
        guard edit.deleteCount > 0 || !edit.insertText.isEmpty else { return [] }
        var result: [ReplacementOperation] = []
        if protectAutocomplete && edit.deleteCount > 0 && !edit.insertText.isEmpty {
            // Commit/cancel an inline suggestion without deleting the typed prefix.
            // Select the old suffix AND the temporary guard, then replace in one
            // insertion. Unlike backspacing the first letter, the field never empties.
            result.append(.text(selectionGuard))
            result += Array(repeating: .selectPreviousCharacter, count: edit.deleteCount + 1)
        } else {
            result += Array(repeating: .backspace, count: edit.deleteCount)
        }
        result += unicodeChunks(edit.insertText).map(ReplacementOperation.text)
        return result
    }

    static func unicodeChunks(_ text: String) -> [String] {
        var result: [String] = []
        var chunk = ""
        for character in text {
            let next = String(character)
            if !chunk.isEmpty && chunk.utf16.count + next.utf16.count > 16 {
                result.append(chunk)
                chunk = ""
            }
            chunk += next
        }
        if !chunk.isEmpty { result.append(chunk) }
        return result
    }

    static func protectsAutocomplete(bundleID: String) -> Bool {
        // Deliberately scoped. A generic backspace path remains for native editors.
        let browsers = ["com.apple.Safari", "com.google.Chrome", "com.microsoft.edgemac",
                        "org.mozilla.firefox", "com.brave.Browser", "com.vivaldi.Vivaldi",
                        "company.thebrowser.Browser", "com.openai.codex", "com.openai.chat"]
        return browsers.contains { bundleID == $0 || bundleID.hasPrefix($0 + ".") }
    }
}
