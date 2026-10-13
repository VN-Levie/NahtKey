import Foundation
import NahtKeyCore

enum ReplacementOperation: Equatable {
    case text(String)
    case backspace
}

/// Replace the engine's suffix with ordinary deletion and Unicode input. Avoid
/// synthetic selection: some editors intercept Shift+Left instead of selecting.
enum ReplacementPlan {
    static func committingSpace(after edit: TextEdit) -> TextEdit {
        TextEdit(deleteCount: edit.deleteCount, insertText: edit.insertText + " ")
    }

    static func operations(for edit: TextEdit, clearInlineCompletion: Bool = false) -> [ReplacementOperation] {
        guard edit.deleteCount > 0 || !edit.insertText.isEmpty else { return [] }
        var result: [ReplacementOperation] = []
        // This optional deletion clears an existing selected suggestion, not a
        // character guessed to exist. The host must verify that selection first.
        if clearInlineCompletion && edit.deleteCount > 0 { result.append(.backspace) }
        result += Array(repeating: .backspace, count: edit.deleteCount)
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

    static func commitsSpaceAsText(bundleID: String) -> Bool {
        // Keep a composed word and its Space on the same Unicode output path.
        let browsers = ["com.apple.Safari", "com.google.Chrome", "com.microsoft.edgemac",
                        "org.mozilla.firefox", "com.brave.Browser", "com.vivaldi.Vivaldi",
                        "company.thebrowser.Browser", "com.openai.codex", "com.openai.chat"]
        return browsers.contains { bundleID == $0 || bundleID.hasPrefix($0 + ".") }
    }
}
