import XCTest
@testable import NahtKeyCore

final class FreshTokenAfterDeletionTests: XCTestCase {
    private func apply(_ edit: TextEdit, to visible: inout String) {
        visible.removeLast(min(edit.deleteCount, visible.count))
        visible += edit.insertText
    }

    private func type(_ keys: String, with engine: VNIEngine, into visible: inout String) {
        for key in keys { apply(engine.process(key), to: &visible) }
    }

    func testBackspaceInAnEmptyFieldDoesNotDisableNextWordPolicies() {
        let cases: [(InputMethod, String, String)] = [
            (.vni, "cau3", "của"), (.telex, "caur", "của"),
            (.vni, "abn5", "bạn"), (.telex, "push", "push"), (.telex, "fix", "fix")
        ]
        for (method, keys, expected) in cases {
            let engine = VNIEngine(corrections: ["cảu": "của", "abn5": "bạn"], inputMethod: method,
                                   options: .init(restoreEnglishTelex: true))
            var visible = ""
            for _ in 0..<3 { apply(engine.backspace(), to: &visible) }
            type(keys, with: engine, into: &visible)
            apply(engine.finish(), to: &visible)
            XCTAssertEqual(visible, expected, keys)
        }
    }

    func testDeletingEntireTokenAllowsFreshCorrectionsAndEnglishRestoration() {
        for (method, keys, expected) in [(InputMethod.vni, "cau3", "của"), (.telex, "caur", "của"),
                                         (.telex, "push", "push"), (.telex, "fix", "fix")] {
            let engine = VNIEngine(corrections: ["cảu": "của"], inputMethod: method,
                                   options: .init(restoreEnglishTelex: true))
            var visible = ""
            type(keys, with: engine, into: &visible)
            while !visible.isEmpty { apply(engine.backspace(), to: &visible) }
            type(keys, with: engine, into: &visible)
            apply(engine.finish(), to: &visible)
            XCTAssertEqual(visible, expected, keys)
        }
    }

    func testDeletingAnEscapedTokenEndsItsLiteralOverride() throws {
        let engine = VNIEngine(corrections: ["cảu": "của"], inputMethod: .telex,
                               options: .init(restoreEnglishTelex: true))
        var visible = ""
        type("test", with: engine, into: &visible)
        apply(try XCTUnwrap(engine.restoreRaw()), to: &visible)
        while !visible.isEmpty { apply(engine.backspace(), to: &visible) }
        type("caur", with: engine, into: &visible)
        apply(engine.finish(), to: &visible)
        XCTAssertEqual(visible, "của")
    }

    func testDeletingBoundaryStillResumesOldWordWithoutReplayingRawAliases() {
        let session = TypingSession(corrections: ["cau3": "WRONG", "cảu": "WRONG"])
        var visible = ""
        for key in "cau" { apply(session.process(key), to: &visible) }
        apply(session.finish(boundary: " "), to: &visible)
        visible += " "
        apply(session.backspace(), to: &visible)
        apply(session.process("3"), to: &visible)
        apply(session.finish(boundary: " "), to: &visible)
        XCTAssertEqual(visible, "cảu")
    }

    func testBackspaceInUntrackedLongTokenDoesNotEnableSuffixCorrections() {
        for method in InputMethod.allCases {
            let keys = method == .vni ? "cau3" : "caur"
            let engine = VNIEngine(corrections: [keys: "WRONG", "cảu": "WRONG"], inputMethod: method,
                                   options: .init(restoreEnglishTelex: true))
            var visible = ""
            type(String(repeating: "a", count: 140), with: engine, into: &visible)
            apply(engine.backspace(), to: &visible)
            let prefix = visible
            type(keys, with: engine, into: &visible)
            apply(engine.finish(), to: &visible)
            XCTAssertEqual(visible, prefix + keys)
        }
    }
}
