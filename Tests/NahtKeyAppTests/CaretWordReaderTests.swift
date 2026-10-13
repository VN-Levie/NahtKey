import Foundation
import XCTest
@testable import NahtKeyApp

final class CaretWordReaderTests: XCTestCase {
    func testInlineCompletionRequiresTheWholeTrackedWordBeforeSelection() {
        XCTAssertTrue(CaretWordReader.matchesInlineCompletionPrefix("chu", word: "chu"))
        XCTAssertTrue(CaretWordReader.matchesInlineCompletionPrefix(" chu", word: "chu"))
        XCTAssertTrue(CaretWordReader.matchesInlineCompletionPrefix("/chu", word: "chu"))
        XCTAssertFalse(CaretWordReader.matchesInlineCompletionPrefix("chu", word: "u"))
        XCTAssertFalse(CaretWordReader.matchesInlineCompletionPrefix("_chu", word: "chu"))
        XCTAssertFalse(CaretWordReader.matchesInlineCompletionPrefix("9chu", word: "chu"))
        XCTAssertFalse(CaretWordReader.matchesInlineCompletionPrefix("cu", word: "chu"))
        XCTAssertFalse(CaretWordReader.matchesInlineCompletionPrefix("chu", word: ""))
    }

    func testWordAtCaretAndPrefixAreSeparated() {
        XCTAssertEqual(CaretWordReader.word(in: "go", selection: CFRange(location: 2, length: 0)), "go")
        XCTAssertEqual(CaretWordReader.word(in: "xin nhận", selection: CFRange(location: 8, length: 0)), "nhận")
        XCTAssertEqual(CaretWordReader.word(in: "nhận tiếp", selection: CFRange(location: 4, length: 0)), "nhận")
        XCTAssertNil(CaretWordReader.word(in: "nhận tiếp", selection: CFRange(location: 2, length: 0)))
        XCTAssertNil(CaretWordReader.word(in: "go ", selection: CFRange(location: 3, length: 0)))
        XCTAssertNil(CaretWordReader.word(in: "123go", selection: CFRange(location: 5, length: 0)))
        XCTAssertNil(CaretWordReader.word(in: "foo_go", selection: CFRange(location: 6, length: 0)))
        XCTAssertNil(CaretWordReader.word(in: "go4", selection: CFRange(location: 2, length: 0)))
        XCTAssertNil(CaretWordReader.word(in: "go_suffix", selection: CFRange(location: 2, length: 0)))
    }

    func testSelectionAndInvalidRangesNeverTriggerReconversion() {
        XCTAssertNil(CaretWordReader.word(in: "nhận", selection: CFRange(location: 0, length: 4)))
        XCTAssertNil(CaretWordReader.word(in: "go", selection: CFRange(location: 3, length: 0)))
        XCTAssertNil(CaretWordReader.word(in: "go", selection: CFRange(location: -1, length: 0)))
        XCTAssertNil(CaretWordReader.word(in: String(repeating: "a", count: 300), selection: CFRange(location: 300, length: 0)))
    }

    func testUTF16CaretAndCanonicalVietnamese() {
        let text = "🙂 nha\u{0323}\u{0302}n".precomposedStringWithCanonicalMapping
        XCTAssertEqual(CaretWordReader.word(in: text, selection: CFRange(location: text.utf16.count, length: 0)), "nhận")
    }
}
