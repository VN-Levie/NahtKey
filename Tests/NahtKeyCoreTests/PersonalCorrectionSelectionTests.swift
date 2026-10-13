import XCTest
@testable import NahtKeyCore

final class PersonalCorrectionSelectionTests: XCTestCase {
    private func apply(_ edit: TextEdit, to visible: inout String) {
        XCTAssertLessThanOrEqual(edit.deleteCount, visible.count)
        visible.removeLast(min(edit.deleteCount, visible.count))
        visible.append(edit.insertText)
    }

    private func type(_ keys: String, into engine: VNIEngine) -> String {
        var visible = ""
        for key in keys {
            apply(engine.process(key), to: &visible)
            XCTAssertEqual(visible, engine.rendered)
        }
        return visible
    }

    func testUnicodeWordAliasMatchesAfterCompositionAtBoundary() {
        for (method, input) in [(InputMethod.vni, "cau2"), (.telex, "cauf")] {
            let engine = VNIEngine(corrections: ["càu": "của"], inputMethod: method)
            var visible = type(input, into: engine)
            XCTAssertEqual(visible, "càu", "Unicode aliases wait for the boundary")
            apply(engine.finish(), to: &visible)
            XCTAssertEqual(visible, "của")
        }
    }

    func testExactRawRuleHasPriorityOverComposedUnicodeRule() {
        let engine = VNIEngine(corrections: ["cau2": "ưu tiên", "càu": "của"])
        var visible = type("cau2", into: engine)
        XCTAssertEqual(visible, "càu")
        apply(engine.finish(), to: &visible)
        XCTAssertEqual(visible, "ưu tiên")
    }

    func testASCIIKeysCannotMatchOnlyTheComposedCandidate() {
        let rules = ["ban": "WRONG", "a1": "WRONG", "d": "WRONG"]
        for (input, expected) in [("ban50", "ban"), ("a11", "a1"), ("d90", "d")] {
            let engine = VNIEngine(corrections: rules)
            var visible = type(input, into: engine)
            apply(engine.finish(), to: &visible)
            XCTAssertEqual(visible, expected)
        }
    }

    func testUnicodeKeysSupportNFCAndNFDWithoutLosingCaseSensitivity() {
        let decomposedKey = "ca\u{0300}u"
        let engine = VNIEngine(corrections: [decomposedKey: "của"])
        var visible = type("cau2", into: engine)
        apply(engine.finish(), to: &visible)
        XCTAssertEqual(visible, "của")

        visible = type("Cau2", into: engine)
        apply(engine.finish(), to: &visible)
        XCTAssertEqual(visible, "Càu", "Unicode matching remains case-sensitive")

        engine.corrections["Ca\u{0300}u"] = "Của"
        visible = type("Cau2", into: engine)
        apply(engine.finish(), to: &visible)
        XCTAssertEqual(visible, "Của", "Public dictionary updates take effect without a stale secondary index")
    }

    func testNeitherRawNorUnicodeReplacementCascades() {
        let engine = VNIEngine(corrections: ["càu": "của", "của": "WRONG", "a": "b", "b": "WRONG"])
        for (input, expected) in [("cau2", "của"), ("a", "b")] {
            var visible = type(input, into: engine)
            apply(engine.finish(), to: &visible)
            XCTAssertEqual(visible, expected)
            apply(engine.finish(), to: &visible)
            XCTAssertEqual(visible, expected)
        }
    }

    func testResumedOrBackspacedUnknownKeysCannotUseUnicodeAliases() {
        let engine = VNIEngine(corrections: ["càu": "WRONG", "cau2": "WRONG"])
        var visible = "cau"
        engine.resume(visible)
        apply(engine.process("2"), to: &visible)
        apply(engine.finish(), to: &visible)
        XCTAssertEqual(visible, "càu")

        visible = "càu"
        engine.resume(visible)
        apply(engine.finish(), to: &visible)
        XCTAssertEqual(visible, "càu")

        visible = type("cau2", into: engine)
        apply(engine.backspace(), to: &visible)
        apply(engine.process("u"), to: &visible)
        apply(engine.finish(), to: &visible)
        XCTAssertEqual(visible, "càu")
    }

    func testUnicodeReplacementDoesNotExpandIdentifierMatching() {
        let engine = VNIEngine(corrections: ["càu": "của", "đc": "được"])
        for input in ["matkhau123", "model123", "cmd9", "password", "xcau2"] {
            var visible = type(input, into: engine)
            apply(engine.finish(), to: &visible)
            XCTAssertEqual(visible, input)
        }
        var visible = type("dc9", into: engine)
        XCTAssertEqual(visible, "đc")
        apply(engine.finish(), to: &visible)
        XCTAssertEqual(visible, "được", "An explicit Unicode abbreviation alias can expand at its boundary")
    }
}
