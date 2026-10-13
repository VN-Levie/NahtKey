import AppKit
import CoreGraphics
import XCTest
import NahtKeyCore
@testable import NahtKeyApp

final class ReplacementPlanTests: XCTestCase {
    @MainActor func testHornEditsPreservePrefixInNativeEditorThatDropsInvisibleInput() {
        // Rich editors may discard/normalize temporary invisible input. Replay
        // the real plan on NSTextView so selection uses AppKit's caret behavior.
        let cases: [(InputMethod, String, String)] = [
            (.vni, "chu7a", "chưa"), (.vni, "chua7", "chưa"),
            (.vni, "cu7a", "cưa"), (.vni, "cua7", "cưa"),
            (.vni, "thu7", "thư"), (.vni, "uu7", "ưu"),
            (.vni, "d9a4", "đã"), (.telex, "chuw a", "chư a"),
            (.telex, "chuaw", "chưa"), (.telex, "cuw a", "cư a")
        ]
        for (method, input, expected) in cases {
            for prefix in ["", "trước "] {
                let editor = NSTextView(frame: .zero)
                editor.string = prefix
                editor.setSelectedRange(NSRange(location: prefix.utf16.count, length: 0))
                let session = TypingSession(inputMethod: method)
                for character in input + " " {
                    let edit = character == " "
                        ? ReplacementPlan.committingSpace(after: session.finish(boundary: character))
                        : session.process(character)
                    for operation in ReplacementPlan.operations(for: edit, useSelection: true) {
                        switch operation {
                        case .text(let text):
                            let accepted = text.replacingOccurrences(of: "\u{202F}", with: "")
                                .replacingOccurrences(of: "\u{200C}", with: "")
                            if !accepted.isEmpty { editor.insertText(accepted, replacementRange: editor.selectedRange()) }
                        case .backspace: editor.deleteBackward(nil)
                        case .selectPreviousCharacter: editor.moveLeftAndModifySelection(nil)
                        }
                    }
                }
                XCTAssertEqual(editor.string, prefix + expected + " ", "\(method): \(input)")
            }
        }
    }

    func testContinuousHornWordsAndPersonalCorrectionsKeepSpaces() {
        let session = TypingSession(corrections: ["abn5": "bạn", "ab5n": "bạn"])
        var visible = ""
        for _ in 0..<100 {
            for character in "chu7a cu7a uu7 abn5 ab5n " {
                let edit = character == " "
                    ? ReplacementPlan.committingSpace(after: session.finish(boundary: character))
                    : session.process(character)
                visible = apply(ReplacementPlan.operations(for: edit, useSelection: true),
                                to: visible, selection: visible.count..<visible.count)
            }
        }
        XCTAssertEqual(visible, String(repeating: "chưa cưa ưu bạn bạn ", count: 100))
    }

    func testWordAndSpaceAreOneTransactionForOrdinaryAndPersonalWords() {
        let ordinary = ReplacementPlan.committingSpace(after: TextEdit(deleteCount: 0, insertText: ""))
        XCTAssertEqual(apply(ReplacementPlan.operations(for: ordinary, useSelection: true),
                             to: "gõ", selection: 2..<2), "gõ ")
        let correction = ReplacementPlan.committingSpace(after: TextEdit(deleteCount: 3, insertText: "bạn"))
        let output = apply(ReplacementPlan.operations(for: correction, useSelection: true),
                           to: "ạbn", selection: 3..<3)
        XCTAssertEqual(output + "từ", "bạn từ")
        XCTAssertFalse(output.contains("\u{202F}"))
    }

    // Model an editor with a forward selection: Shift+Left moves the active
    // end, so it shrinks an existing forward selection rather than extending it.
    private func apply(_ operations: [ReplacementOperation], to text: String, selection: Range<Int>) -> String {
        var characters = Array(text)
        var anchor = selection.lowerBound
        var caret = selection.upperBound
        for operation in operations {
            let selected = min(anchor, caret)..<max(anchor, caret)
            switch operation {
            case .text(let insertion):
                characters.replaceSubrange(selected, with: insertion)
                caret = selected.lowerBound + insertion.count
                anchor = caret
            case .backspace:
                let deletion = selected.isEmpty ? max(0, selected.lowerBound - 1)..<selected.lowerBound : selected
                characters.removeSubrange(deletion)
                caret = deletion.lowerBound
                anchor = caret
            case .selectPreviousCharacter:
                caret = max(0, caret - 1)
            }
        }
        return String(characters)
    }

    func testFirstCharacterReplacementDoesNotRetainAutocompleteOrDropPrefix() {
        let plan = ReplacementPlan.operations(for: TextEdit(deleteCount: 1, insertText: "đ"), useSelection: true)
        let completion = ReplacementPlan.operations(for: TextEdit(deleteCount: 1, insertText: "đ"),
                                                     useSelection: true, clearInlineCompletion: true)
        XCTAssertEqual(apply(completion, to: "documentation", selection: 1..<13), "đ")
        XCTAssertEqual(apply(plan, to: "d", selection: 1..<1), "đ")
        XCTAssertEqual(apply(plan, to: "xin d", selection: 5..<5), "xin đ")
    }

    func testToneAndWholeWordCorrectionPreserveEarlierText() {
        let tone = ReplacementPlan.operations(for: TextEdit(deleteCount: 1, insertText: "ã"), useSelection: true)
        XCTAssertEqual(apply(tone, to: "xin đa", selection: 6..<6), "xin đã")
        let correction = ReplacementPlan.operations(for: TextEdit(deleteCount: 3, insertText: "bạn"), useSelection: true)
        XCTAssertEqual(apply(correction, to: "xin ạbn", selection: 7..<7), "xin bạn")
    }

    func testNativeReplacementAndUnicodeChunksHaveNoGuardLeak() {
        let text = "👨‍👩‍👧‍👦" + String(repeating: "Việt", count: 20)
        XCTAssertEqual(ReplacementPlan.unicodeChunks(text).joined(), text)
        let replacement = ReplacementPlan.operations(for: TextEdit(deleteCount: 1, insertText: text), useSelection: false)
        XCTAssertEqual(apply(replacement, to: "x", selection: 1..<1), text)
        let browser = ReplacementPlan.operations(for: TextEdit(deleteCount: 1, insertText: text), useSelection: true)
        XCTAssertEqual(apply(browser, to: "x", selection: 1..<1), text)
    }

    @MainActor func testSyntheticSourceNeverSuppressesPhysicalKeyboard() throws {
        let source = try XCTUnwrap(KeyboardController.makeEventSource())
        XCTAssertEqual(source.localEventsSuppressionInterval, 0)
        XCTAssertTrue(source.getLocalEventsFilterDuringSuppressionState(.eventSuppressionStateSuppressionInterval)
            .contains(.permitLocalKeyboardEvents))
        XCTAssertTrue(source.getLocalEventsFilterDuringSuppressionState(.eventSuppressionStateRemoteMouseDrag)
            .contains(.permitLocalKeyboardEvents))
    }
}
