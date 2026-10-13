import Foundation
import NahtKeyCore

enum ReplacementOperation: Equatable {
    case text(String)
    case backspace
    case selectPreviousCharacter
}

/// Events posted together through the tap proxy. Selection replacement keeps
/// the field nonempty without assuming an invisible guard was actually inserted.
enum ReplacementPlan {
    static func committingSpace(after edit: TextEdit) -> TextEdit {
        TextEdit(deleteCount: edit.deleteCount, insertText: edit.insertText + " ")
    }

    static func operations(for edit: TextEdit, useSelection: Bool,
                           clearInlineCompletion: Bool = false) -> [ReplacementOperation] {
        guard edit.deleteCount > 0 || !edit.insertText.isEmpty else { return [] }
        var result: [ReplacementOperation] = []
        if useSelection && edit.deleteCount > 0 && !edit.insertText.isEmpty {
            // Only clear a suggestion when the host verified a nonempty selection
            // immediately after the tracked word. Never add a speculative delete.
            if clearInlineCompletion { result.append(.backspace) }
            result += Array(repeating: .selectPreviousCharacter, count: edit.deleteCount)
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

    static func usesSelectionReplacement(bundleID: String) -> Bool {
        // Deliberately scoped. A generic backspace path remains for native editors.
        let browsers = ["com.apple.Safari", "com.google.Chrome", "com.microsoft.edgemac",
                        "org.mozilla.firefox", "com.brave.Browser", "com.vivaldi.Vivaldi",
                        "company.thebrowser.Browser", "com.openai.codex", "com.openai.chat"]
        return browsers.contains { bundleID == $0 || bundleID.hasPrefix($0 + ".") }
    }
}
