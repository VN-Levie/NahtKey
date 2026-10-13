import XCTest
@testable import NahtKeyCore

final class TypingSessionTests: XCTestCase {
    private func apply(_ edit: TextEdit, to visible: inout String) {
        XCTAssertLessThanOrEqual(edit.deleteCount, visible.count)
        visible.removeLast(min(edit.deleteCount, visible.count))
        visible.append(edit.insertText)
    }

    private func type(_ input: String, using session: TypingSession, into visible: inout String) {
        for character in input {
            if character.isLetter || character.isNumber {
                apply(session.process(character), to: &visible)
            } else {
                apply(session.finish(boundary: character), to: &visible)
                visible.append(character)
            }
        }
    }

    func testDeleteSpaceThenReplaceToneInPreviousVNIWord() {
        for (input, expected) in [("go ", "gõ"), ("nha6n5 ", "nhẫn"), ("NHA6N5 ", "NHẪN")] {
            let session = TypingSession()
            var visible = ""
            type(input, using: session, into: &visible)
            XCTAssertEqual(session.rendered, "")
            apply(session.backspace(), to: &visible)
            XCTAssertFalse(session.rendered.isEmpty)
            apply(session.process("4"), to: &visible)
            XCTAssertEqual(visible, expected, input)
        }
    }

    func testDeleteSpaceThenReplaceToneInPreviousTelexWord() {
        for (input, expected) in [("go ", "gõ"), ("nhaanj ", "nhẫn")] {
            let session = TypingSession(inputMethod: .telex)
            var visible = ""
            type(input, using: session, into: &visible)
            apply(session.backspace(), to: &visible)
            apply(session.process("x"), to: &visible)
            XCTAssertEqual(visible, expected, input)
        }
    }

    func testEverySeparatingSpaceMustBeDeletedBeforeResuming() {
        let session = TypingSession()
        var visible = ""
        type("go  ", using: session, into: &visible)
        apply(session.backspace(), to: &visible)
        XCTAssertEqual(visible, "go ")
        XCTAssertEqual(session.rendered, "")
        apply(session.backspace(), to: &visible)
        XCTAssertEqual(session.rendered, "go")
        apply(session.process("4"), to: &visible)
        XCTAssertEqual(visible, "gõ")

        session.reset()
        visible = ""
        type("go  ", using: session, into: &visible)
        apply(session.backspace(), to: &visible)
        apply(session.process("4"), to: &visible)
        XCTAssertEqual(visible, "go 4", "A surviving space keeps words separated")
    }

    func testNewlineAndPunctuationRememberExactBoundaries() {
        for separator: Character in ["\n", "\t", ",", "."] {
            let session = TypingSession()
            var visible = ""
            type("xin, go", using: session, into: &visible)
            let boundaryEdit = session.finish(boundary: separator)
            XCTAssertEqual(boundaryEdit, TextEdit(deleteCount: 0, insertText: ""))
            apply(boundaryEdit, to: &visible)
            visible.append(separator)
            apply(session.backspace(), to: &visible)
            apply(session.process("4"), to: &visible)
            XCTAssertEqual(visible, "xin, gõ")
        }
    }

    func testBackspaceCanReachAnEarlierRememberedWord() {
        let session = TypingSession()
        var visible = ""
        type("go ban5 ", using: session, into: &visible)
        XCTAssertEqual(visible, "go bạn ")
        // Delete the space, all three visible letters, then the previous space.
        for _ in 0..<5 { apply(session.backspace(), to: &visible) }
        XCTAssertEqual(visible, "go")
        XCTAssertEqual(session.rendered, "go")
        apply(session.process("4"), to: &visible)
        XCTAssertEqual(visible, "gõ")
    }

    func testResumeUsesCorrectedVisibleOutputAndNeverRawAliasAgain() {
        let session = TypingSession(corrections: [
            "abn5": "bạn", "ab5n": "bạn", "bạn4": "WRONG", "bãn": "WRONG"
        ])
        var visible = ""
        type("abn5 ", using: session, into: &visible)
        XCTAssertEqual(visible, "bạn ")
        apply(session.backspace(), to: &visible)
        XCTAssertEqual(session.rendered, "bạn")
        apply(session.process("4"), to: &visible)
        XCTAssertEqual(visible, "bãn")
        type(" ", using: session, into: &visible)
        XCTAssertEqual(visible, "bãn ")
        type("ab5n ", using: session, into: &visible)
        XCTAssertEqual(visible, "bãn bạn ", "A genuinely new token can still use its raw alias")
    }

    func testPhraseCorrectionKeepsItsVisiblePrefix() {
        let session = TypingSession(corrections: ["abn5": "xin bạn"])
        var visible = ""
        type("abn5 ", using: session, into: &visible)
        apply(session.backspace(), to: &visible)
        XCTAssertEqual(session.rendered, "bạn")
        apply(session.process("4"), to: &visible)
        XCTAssertEqual(visible, "xin bãn")
    }

    func testResetLosesOldContextInsteadOfGuessingAfterCaretMove() {
        let session = TypingSession()
        var visible = ""
        type("go ", using: session, into: &visible)
        session.reset()
        apply(session.backspace(), to: &visible)
        XCTAssertEqual(session.rendered, "")
        apply(session.process("4"), to: &visible)
        XCTAssertEqual(visible, "go4")
    }

    func testVerifiedResumeAfterCaretReturnAndNFCNormalization() {
        let session = TypingSession()
        var visible = "xin go"
        session.resume("go")
        apply(session.process("4"), to: &visible)
        XCTAssertEqual(visible, "xin gõ")

        let decomposed = "NHA\u{0302}\u{0323}N"
        visible = "xin " + decomposed
        session.resume(decomposed)
        XCTAssertEqual(Array(session.rendered.unicodeScalars), Array("NHẬN".unicodeScalars))
        apply(session.process("4"), to: &visible)
        XCTAssertEqual(visible, "xin NHẪN")
    }

    func testResumeDiscardsContextBeforeTheVerifiedWord() {
        let session = TypingSession()
        var visible = ""
        type("xin ", using: session, into: &visible)
        visible.append("go")
        session.resume("go")
        for _ in 0..<3 { apply(session.backspace(), to: &visible) }
        XCTAssertEqual(visible, "xin")
        XCTAssertEqual(session.rendered, "", "The text before the verified word is unknown")
        apply(session.process("4"), to: &visible)
        XCTAssertEqual(visible, "xin4")
    }

    func testInvalidAndOverlongWordsCannotResumePartialSuffixes() {
        for word in ["", "go4", "go nha", "nhận,", "🙂", String(repeating: "a", count: 129)] {
            let session = TypingSession()
            var visible = word
            session.resume(word)
            XCTAssertEqual(session.raw, "")
            XCTAssertEqual(session.rendered, "")
            apply(session.process("4"), to: &visible)
            XCTAssertEqual(visible, word + "4")
        }

        let session = TypingSession()
        var visible = ""
        type("123go ", using: session, into: &visible)
        apply(session.backspace(), to: &visible)
        XCTAssertEqual(session.rendered, "", "A letter suffix in a mixed numeric token is not a whole word")
        apply(session.process("4"), to: &visible)
        XCTAssertEqual(visible, "123go4")
        session.reset()
        visible = ""
        type("foo_go ", using: session, into: &visible)
        apply(session.backspace(), to: &visible)
        XCTAssertEqual(session.rendered, "")
        apply(session.process("4"), to: &visible)
        XCTAssertEqual(visible, "foo_go4")
    }

    func testBoundedHistoryNeverResumesItsTruncatedLeadingWord() {
        let session = TypingSession()
        var visible = ""
        type(String(repeating: "a", count: 350) + " ", using: session, into: &visible)
        // After history is trimmed, deleting back into fewer than 128 retained
        // letters must not reinterpret that partial word as a complete token.
        for _ in 0..<141 { apply(session.backspace(), to: &visible) }
        XCTAssertEqual(visible, String(repeating: "a", count: 210))
        XCTAssertEqual(session.rendered, "")
        apply(session.process("4"), to: &visible)
        XCTAssertEqual(visible, String(repeating: "a", count: 210) + "4")

        session.reset()
        visible = ""
        let prefix = String(repeating: "x", count: 350) + " "
        type(prefix + "go ", using: session, into: &visible)
        apply(session.backspace(), to: &visible)
        apply(session.process("4"), to: &visible)
        XCTAssertEqual(visible, prefix + "gõ", "A complete recent word remains editable after trimming")
    }

    func testMethodChangeInvalidatesRememberedTextOnlyOnActualChange() {
        let session = TypingSession()
        var visible = ""
        type("go ", using: session, into: &visible)
        session.inputMethod = .vni
        apply(session.backspace(), to: &visible)
        apply(session.process("4"), to: &visible)
        XCTAssertEqual(visible, "gõ")

        type(" ", using: session, into: &visible)
        session.inputMethod = .telex
        apply(session.backspace(), to: &visible)
        XCTAssertEqual(session.rendered, "")
        apply(session.process("x"), to: &visible)
        XCTAssertEqual(visible, "gõx")
        session.resume("gõ")
        XCTAssertEqual(session.inputMethod, .telex)
    }
}
