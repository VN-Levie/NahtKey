import Foundation
import XCTest
import NahtKeyCore
@testable import NahtKeyApp

final class LocalFieldReplacementTests: XCTestCase {
    func testUnifiedAliasFieldAcceptsRawExamplesAndVietnameseWithoutPersonalExpansion() throws {
        for (keys, expected) in [("abn5", "abn5"), ("ab5n", "ab5n"), ("cau2", "càu"), ("chua7", "chưa")] {
            let engine = VNIEngine(inputMethod: .vni)
            var text = ""
            var selection = NSRange(location: 0, length: 0)
            for character in keys {
                let replacement = try XCTUnwrap(LocalFieldReplacement.make(
                    edit: engine.process(character), in: text, selection: selection))
                text = try apply(replacement, to: text)
                selection = replacement.selectionAfter
            }
            XCTAssertEqual(text, expected, keys)
        }
    }

    private func apply(_ replacement: LocalFieldReplacement, to text: String) throws -> String {
        let range = try XCTUnwrap(Range(replacement.range, in: text))
        var result = text
        result.replaceSubrange(range, with: replacement.text)
        return result
    }

    func testVNIReplacementFieldComposesUserExampleWithoutPersonalCorrections() throws {
        let engine = VNIEngine(inputMethod: .vni)
        var text = ""
        var selection = NSRange(location: 0, length: 0)
        for character in "giua74" {
            let replacement = try XCTUnwrap(LocalFieldReplacement.make(
                edit: engine.process(character), in: text, selection: selection
            ))
            text = try apply(replacement, to: text)
            selection = replacement.selectionAfter
        }
        XCTAssertEqual(text, "giữa")
        XCTAssertEqual(selection, NSRange(location: "giữa".utf16.count, length: 0))
    }

    func testTelexReplacementFieldUsesSelectedMethod() throws {
        let engine = VNIEngine(inputMethod: .telex)
        var text = ""
        var selection = NSRange(location: 0, length: 0)
        for character in "giuawx" {
            let replacement = try XCTUnwrap(LocalFieldReplacement.make(
                edit: engine.process(character), in: text, selection: selection
            ))
            text = try apply(replacement, to: text)
            selection = replacement.selectionAfter
        }
        XCTAssertEqual(text, "giữa")
    }

    func testGraphemeDeletionPreservesSurrogatePrefixAndTextAfterCaret() throws {
        let text = "🙂 a\u{0300}n đuôi"
        let selection = NSRange(location: "🙂 a\u{0300}n".utf16.count, length: 0)
        let replacement = try XCTUnwrap(LocalFieldReplacement.make(
            edit: TextEdit(deleteCount: 2, insertText: "ăn"), in: text, selection: selection
        ))
        XCTAssertEqual(replacement.range, NSRange(location: 3, length: 3))
        XCTAssertEqual(try apply(replacement, to: text), "🙂 ăn đuôi")
        XCTAssertEqual(replacement.selectionAfter, NSRange(location: 5, length: 0))
    }

    func testTypingOverSelectionReplacesOnlySelectedText() throws {
        let text = "🙂 cũ mới"
        let replacement = try XCTUnwrap(LocalFieldReplacement.make(
            edit: TextEdit(deleteCount: 0, insertText: "m"), in: text,
            selection: NSRange(location: 3, length: 2)
        ))
        XCTAssertEqual(try apply(replacement, to: text), "🙂 m mới")
        XCTAssertEqual(replacement.selectionAfter, NSRange(location: 4, length: 0))
    }

    func testResumeUsesOnlyACompleteVisibleLetterPrefix() throws {
        let text = "🙂 bạn"
        let selection = NSRange(location: text.utf16.count, length: 0)
        let word = try XCTUnwrap(LocalFieldReplacement.wordBeforeCaret(in: text, selection: selection))
        let engine = VNIEngine(inputMethod: .vni)
        engine.resume(word)
        let replacement = try XCTUnwrap(LocalFieldReplacement.make(edit: engine.process("0"), in: text, selection: selection))
        XCTAssertEqual(try apply(replacement, to: text), "🙂 ban")
        XCTAssertNil(LocalFieldReplacement.wordBeforeCaret(in: "foo_bar", selection: NSRange(location: 7, length: 0)))
        XCTAssertNil(LocalFieldReplacement.wordBeforeCaret(in: "ban5", selection: NSRange(location: 4, length: 0)))
    }

    func testInvalidOrSplitGraphemeRangesNeverDeleteText() {
        let edit = TextEdit(deleteCount: 1, insertText: "x")
        XCTAssertNil(LocalFieldReplacement.make(edit: edit, in: "🙂", selection: NSRange(location: 1, length: 0)))
        XCTAssertNil(LocalFieldReplacement.make(edit: edit, in: "a\u{0300}", selection: NSRange(location: 1, length: 0)))
        XCTAssertNil(LocalFieldReplacement.make(edit: edit, in: "a", selection: NSRange(location: 0, length: 0)))
    }
}
