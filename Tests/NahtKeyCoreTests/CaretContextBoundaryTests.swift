import XCTest
@testable import NahtKeyCore

final class CaretContextBoundaryTests: XCTestCase {
    private func apply(_ edit: TextEdit, to visible: inout String) {
        XCTAssertLessThanOrEqual(edit.deleteCount, visible.count)
        visible.removeLast(min(edit.deleteCount, visible.count))
        visible += edit.insertText
    }

    func testStaleCaretSnapshotCannotReopenWordBeforeKnownDelimiter() {
        for boundary: Character in [" ", ",", "."] {
            let session = TypingSession(corrections: ["test": "test", "cảu": "của"], inputMethod: .telex,
                                        options: .init(restoreEnglishTelex: true))
            let words = ["caur", "push", "fix", "release", "text", "next", "sort", "port", "class", "press", "test", "tets"]
            let expected = ["của", "push", "fix", "release", "text", "next", "sort", "port", "class", "press", "test", "tét"]
            var staleAXWord = ""
            var visible = ""
            var staleReads = 0
            for word in words {
                for key in word {
                    if session.needsExternalWordContext, "sfrxjzaweod".contains(key), !staleAXWord.isEmpty {
                        staleReads += 1
                        session.resume(staleAXWord)
                    }
                    apply(session.process(key), to: &visible)
                }
                // Model Chromium AX remaining one commit behind the visible input.
                staleAXWord = session.rendered
                apply(session.finish(boundary: boundary), to: &visible)
                visible.append(boundary)
            }
            XCTAssertEqual(staleReads, 0)
            XCTAssertEqual(visible, expected.joined(separator: String(boundary)) + String(boundary))
        }
    }

    func testResetStillAllowsVerifiedCaretReconversionButTrackedBackspaceDoesNotNeedIt() {
        let session = TypingSession()
        XCTAssertTrue(session.needsExternalWordContext)
        for key in "cau" { _ = session.process(key) }
        _ = session.finish(boundary: " ")
        XCTAssertFalse(session.needsExternalWordContext)
        _ = session.backspace()
        XCTAssertEqual(session.rendered, "cau")
        XCTAssertFalse(session.needsExternalWordContext)
        _ = session.process("3")
        XCTAssertEqual(session.rendered, "cảu")
        session.reset()
        XCTAssertTrue(session.needsExternalWordContext)
        session.resume("cau")
        XCTAssertFalse(session.needsExternalWordContext)
        _ = session.process("3")
        XCTAssertEqual(session.rendered, "cảu")
    }
}
