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

    func testUnicodeKeysSupportNFCAndNFDIncludingFoldedCase() {
        let decomposedKey = "ca\u{0300}u"
        let engine = VNIEngine(corrections: [decomposedKey: "của"])
        var visible = type("cau2", into: engine)
        apply(engine.finish(), to: &visible)
        XCTAssertEqual(visible, "của")

        visible = type("Cau2", into: engine)
        apply(engine.finish(), to: &visible)
        XCTAssertEqual(visible, "Của", "A lower-case NFD key also serves a capitalized word")

        engine.corrections["Ca\u{0300}u"] = "CỦA"
        visible = type("Cau2", into: engine)
        apply(engine.finish(), to: &visible)
        XCTAssertEqual(visible, "CỦA", "Public dictionary updates take effect without a stale secondary index")
    }

    func testCapitalizedAndAllCapsWordsReuseLowerCaseRules() {
        let rules = ["haòn": "hoàn", "chekc": "check", "abn5": "bạn", "dne961": "đến",
                     "swifui": "SwiftUI", "bt": "bình thường"]
        let cases: [(InputMethod, String, String)] = [
            (.vni, "Haon2", "Hoàn"), (.vni, "HAON2", "HOÀN"), (.vni, "Hao2n", "Hoàn"),
            (.vni, "Chekc", "Check"), (.vni, "CHEKC", "CHECK"),
            (.vni, "Abn5", "Bạn"), (.vni, "ABN5", "BẠN"),
            (.vni, "Dne961", "Đến"), (.vni, "DNE961", "ĐẾN"),
            (.vni, "Swifui", "SwiftUI"), (.vni, "SWIFUI", "SWIFTUI"),
            (.vni, "Bt", "Bình thường"), (.vni, "BT", "BÌNH THƯỜNG"),
            (.telex, "Haonf", "Hoàn"), (.telex, "HAONF", "HOÀN")
        ]
        for (method, input, expected) in cases {
            let engine = VNIEngine(corrections: rules, inputMethod: method)
            var visible = type(input, into: engine)
            apply(engine.finish(), to: &visible)
            XCTAssertEqual(visible, expected, input)
        }
    }

    func testMixedCaseWordsAreNotRewrittenByLowerCaseRules() {
        for input in ["cHEKC", "ChEkc", "hAon2", "aBN5"] {
            let engine = VNIEngine(corrections: ["chekc": "check", "haòn": "hoàn", "abn5": "bạn"])
            let displayed = type(input, into: engine)
            var visible = displayed
            apply(engine.finish(), to: &visible)
            XCTAssertEqual(visible, displayed, input)
        }
    }

    func testExactCaseRulesBeatFoldedRulesAndRawStillBeatsComposed() {
        let names = VNIEngine(corrections: ["kai": "kia", "Kai": "Kai"])
        for (input, expected) in [("Kai", "Kai"), ("KAI", "KIA"), ("kai", "kia")] {
            var visible = type(input, into: names)
            apply(names.finish(), to: &visible)
            XCTAssertEqual(visible, expected, input)
        }

        let priority = VNIEngine(corrections: ["cau3": "raw", "cảu": "của"])
        for (input, expected) in [("Cau3", "Raw"), ("CAU3", "RAW")] {
            var visible = type(input, into: priority)
            apply(priority.finish(), to: &visible)
            XCTAssertEqual(visible, expected, input)
        }
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
