import AppKit
import XCTest
import NahtKeyCore
@testable import NahtKeyApp

@MainActor
final class SafariReplacementTests: XCTestCase {
    private func apply(_ edit: TextEdit, to editor: NSTextView, safariTail: Bool = false) {
        for operation in ReplacementPlan.operations(for: edit, prepareSafariTail: safariTail) {
            switch operation {
            case .backspace: editor.deleteBackward(nil)
            case .forwardDelete: editor.deleteForward(nil)
            case .text(let text): editor.insertText(text, replacementRange: editor.selectedRange())
            }
        }
    }

    func testCompletionAppearingAfterPlanningCannotConsumeAWordDeletion() {
        for (word, edit, expected) in [
            ("uu", TextEdit(deleteCount: 2, insertText: "ưu"), "ưu"),
            ("chu", TextEdit(deleteCount: 1, insertText: "ư"), "chư")
        ] {
            for prefix in ["", "xin "] {
                for completion in ["", ".localhost:8766"] {
                    let editor = NSTextView(frame: .zero)
                    let typed = prefix + word
                    editor.string = typed + completion
                    editor.setSelectedRange(NSRange(location: typed.utf16.count, length: completion.utf16.count))
                    // The AX snapshot may have had no completion. Its late arrival
                    // must be handled by the native edit, not an extra guessed BS.
                    apply(edit, to: editor, safariTail: true)
                    XCTAssertEqual(editor.string, prefix + expected)
                    XCTAssertEqual(editor.selectedRange().length, 0)
                }
            }
        }
    }

    func testPhysicalBackspaceClearsCompletionWithoutDeletingComposition() {
        for (method, suffix) in [(InputMethod.vni, "7a"), (.telex, "wa")] {
            let session = TypingSession(inputMethod: method)
            let editor = NSTextView(frame: .zero)
            for character in "chu" { apply(session.process(character), to: editor) }
            editor.string += ".localhost:8766"
            editor.setSelectedRange(NSRange(location: 3, length: 15))
            let edit = KeyboardController.backspaceEdit(in: session, clearingInlineCompletion: true)
            if let edit { apply(edit, to: editor) } else { editor.deleteBackward(nil) }
            XCTAssertEqual(editor.string, "chu")
            XCTAssertEqual(session.rendered, "chu")
            for character in suffix { apply(session.process(character), to: editor) }
            XCTAssertEqual(editor.string, "chưa", method.rawValue)
        }
    }

    func testFailedBackspaceResyncDoesNotStartAPartialWord() {
        for (method, tone) in [(InputMethod.vni, "2"), (.telex, "f")] {
            let session = TypingSession(inputMethod: method)
            let editor = NSTextView(frame: .zero)
            editor.string = "chư"
            editor.setSelectedRange(NSRange(location: 3, length: 0))
            XCTAssertFalse(KeyboardController.restoreAfterUncertainBackspace(in: session, word: nil))
            // Native 'a' is forwarded while AX is unavailable. The engine must
            // not begin a new one-letter composition that would yield chưà.
            editor.insertText("a", replacementRange: editor.selectedRange())
            XCTAssertEqual(session.rendered, "")
            XCTAssertTrue(KeyboardController.restoreAfterUncertainBackspace(in: session, word: editor.string))
            for character in tone { apply(session.process(character), to: editor) }
            XCTAssertEqual(editor.string, "chừa", method.rawValue)
        }
    }

    func testOrdinaryBackspaceAndMiddleOfTextUseExistingBehavior() {
        for (method, input) in [(InputMethod.vni, "hoa2n"), (.telex, "hoafn")] {
            let session = TypingSession(inputMethod: method)
            let editor = NSTextView(frame: .zero)
            editor.string = "🙂 "
            editor.setSelectedRange(NSRange(location: editor.string.utf16.count, length: 0))
            for character in input { apply(session.process(character), to: editor) }
            let caret = editor.selectedRange()
            editor.string += " đuôi"
            editor.setSelectedRange(caret)
            let edit = KeyboardController.backspaceEdit(in: session, clearingInlineCompletion: false)!
            apply(edit, to: editor)
            XCTAssertEqual(editor.string, "🙂 hòa đuôi")
        }
    }
}
