import CoreGraphics
import XCTest
import NahtKeyCore
@testable import NahtKeyApp

final class ReplacementPlanTests: XCTestCase {
    func testWordAndSpaceAreOneTransactionForOrdinaryAndPersonalWords() {
        let ordinary = ReplacementPlan.committingSpace(after: TextEdit(deleteCount: 0, insertText: ""))
        XCTAssertEqual(apply(ReplacementPlan.operations(for: ordinary, protectAutocomplete: true),
                             to: "gõ", selection: 2..<2), "gõ ")
        let correction = ReplacementPlan.committingSpace(after: TextEdit(deleteCount: 3, insertText: "bạn"))
        let output = apply(ReplacementPlan.operations(for: correction, protectAutocomplete: true),
                           to: "ạbn", selection: 3..<3)
        XCTAssertEqual(output + "từ", "bạn từ")
        XCTAssertFalse(output.contains(ReplacementPlan.selectionGuard))
    }

    // Model normal editor selection semantics, including a browser's selected
    // inline completion. It checks the visible result, not an exact step count.
    private func apply(_ operations: [ReplacementOperation], to text: String, selection: Range<Int>) -> String {
        var characters = Array(text)
        var selected = selection
        for operation in operations {
            switch operation {
            case .text(let insertion):
                characters.replaceSubrange(selected, with: insertion)
                let caret = selected.lowerBound + insertion.count
                selected = caret..<caret
            case .backspace:
                let deletion = selected.isEmpty ? max(0, selected.lowerBound - 1)..<selected.lowerBound : selected
                characters.removeSubrange(deletion)
                selected = deletion.lowerBound..<deletion.lowerBound
            case .selectPreviousCharacter:
                selected = max(0, selected.lowerBound - 1)..<selected.upperBound
            }
        }
        return String(characters)
    }

    func testFirstCharacterReplacementDoesNotRetainAutocompleteOrDropPrefix() {
        let plan = ReplacementPlan.operations(for: TextEdit(deleteCount: 1, insertText: "đ"), protectAutocomplete: true)
        XCTAssertEqual(apply(plan, to: "documentation", selection: 1..<13), "đ")
        XCTAssertEqual(apply(plan, to: "d", selection: 1..<1), "đ")
        XCTAssertEqual(apply(plan, to: "xin d", selection: 5..<5), "xin đ")
    }

    func testToneAndWholeWordCorrectionPreserveEarlierText() {
        let tone = ReplacementPlan.operations(for: TextEdit(deleteCount: 1, insertText: "ã"), protectAutocomplete: true)
        XCTAssertEqual(apply(tone, to: "xin đa", selection: 6..<6), "xin đã")
        let correction = ReplacementPlan.operations(for: TextEdit(deleteCount: 3, insertText: "bạn"), protectAutocomplete: true)
        XCTAssertEqual(apply(correction, to: "xin ạbn", selection: 7..<7), "xin bạn")
    }

    func testNativeReplacementAndUnicodeChunksHaveNoGuardLeak() {
        let text = "👨‍👩‍👧‍👦" + String(repeating: "Việt", count: 20)
        XCTAssertEqual(ReplacementPlan.unicodeChunks(text).joined(), text)
        let replacement = ReplacementPlan.operations(for: TextEdit(deleteCount: 1, insertText: text), protectAutocomplete: false)
        XCTAssertEqual(apply(replacement, to: "x", selection: 1..<1), text)
        let browser = ReplacementPlan.operations(for: TextEdit(deleteCount: 1, insertText: text), protectAutocomplete: true)
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
