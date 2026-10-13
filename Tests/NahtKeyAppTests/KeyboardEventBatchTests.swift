import AppKit
import CoreGraphics
import XCTest
import NahtKeyCore
@testable import NahtKeyApp

final class KeyboardEventBatchTests: XCTestCase {
    @MainActor func testHeldAAndELeaveHornReplacementAndPhysicalKeysIntact() throws {
        for held: Set<CGKeyCode> in [[], [0], [0, 14], [0, 11, 14]] {
            let source = try XCTUnwrap(KeyboardController.makeEventSource())
            for (old, new) in [("mua", "mưa"), ("chua", "chưa"), ("cua", "cưa"), ("be", "bê")] {
                let prefix = old.dropLast(2)
                let edit = TextEdit(deleteCount: 2, insertText: String(new.dropFirst(prefix.count)))
                let batch = try XCTUnwrap(KeyboardEventBatch.make(
                    ReplacementPlan.operations(for: edit), source: source, marker: 42,
                    isPhysicallyDown: held.contains))
                let editor = NSTextView(frame: .zero)
                editor.string = old
                editor.setSelectedRange(NSRange(location: old.utf16.count, length: 0))
                var textKey: Int64?
                for event in batch {
                    XCTAssertEqual(event.getIntegerValueField(.eventSourceUserData), 42)
                    let key = event.getIntegerValueField(.keyboardEventKeycode)
                    if key == 51 {
                        if event.type == .keyDown { editor.deleteBackward(nil) }
                    } else {
                        XCTAssertFalse(held.contains(CGKeyCode(key)), "Must not release a physical key being held")
                        if let textKey { XCTAssertEqual(key, textKey) } else { textKey = key }
                        var length = 0
                        var units = [UniChar](repeating: 0, count: 32)
                        event.keyboardGetUnicodeString(maxStringLength: units.count, actualStringLength: &length,
                                                       unicodeString: &units)
                        if event.type == .keyDown {
                            editor.insertText(String(utf16CodeUnits: units, count: length), replacementRange: editor.selectedRange())
                        }
                    }
                }
                XCTAssertEqual(editor.string, new)
            }
        }
    }

    func testUnavailableCarrierAbortsWholeReplacement() {
        let operations: [ReplacementOperation] = [.backspace, .backspace, .text("ưa")]
        XCTAssertNil(KeyboardEventBatch.make(operations, source: nil, marker: 42, isPhysicallyDown: { _ in true }))
    }

    func testBackspaceOnlyDoesNotRequireAFreeTextKey() throws {
        let batch = try XCTUnwrap(KeyboardEventBatch.make([.backspace], source: nil, marker: 42,
                                                         isPhysicallyDown: { _ in true }))
        XCTAssertEqual(batch.map(\.type), [.keyDown, .keyUp])
        XCTAssertTrue(batch.allSatisfy { $0.getIntegerValueField(.keyboardEventKeycode) == 51 })
    }
}
