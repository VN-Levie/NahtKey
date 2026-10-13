import XCTest
@testable import NahtKeyCore

final class VNIPrefixGuardTests: XCTestCase {
    private func apply(_ edit: TextEdit, to visible: inout String) {
        XCTAssertLessThanOrEqual(edit.deleteCount, visible.count)
        visible.removeLast(min(edit.deleteCount, visible.count))
        visible.append(edit.insertText)
    }

    private func type(_ input: String, engine: VNIEngine, into visible: inout String) {
        for key in input {
            apply(engine.process(key), to: &visible)
            if !engine.rendered.isEmpty {
                XCTAssertEqual(visible, engine.rendered, "Edits and composition must agree after every key")
            }
        }
    }

    func testClearlyImpossibleSyllablesAndIdentifiersRemainExact() {
        let inputs = [
            "matkhau123", "MatKhau123", "MATKHAU123", "liennhau123",
            "password123", "PASSWORD123", "model123", "mp3", "abc123", "Windows10",
            "html5", "3g", "2020", "test42"
        ]
        for input in inputs {
            let engine = VNIEngine()
            var visible = ""
            type(input, engine: engine, into: &visible)
            XCTAssertEqual(visible, input)
            XCTAssertEqual(engine.raw, input)
            apply(engine.finish(), to: &visible)
            XCTAssertEqual(visible, input)
        }
    }

    func testLaterImpossibleLettersRestorePreviouslyConsumedModifierKeys() {
        for (prefix, composed, suffix) in [
            ("ma6t", "mât", "khau123"),
            ("ba1t", "bát", "man"),
            ("MA6T", "MÂT", "KHAU123")
        ] {
            let engine = VNIEngine()
            var visible = ""
            type(prefix, engine: engine, into: &visible)
            XCTAssertEqual(visible, composed)
            type(suffix, engine: engine, into: &visible)
            XCTAssertEqual(visible, prefix + suffix)
            XCTAssertEqual(engine.raw, prefix + suffix)
        }
    }

    func testASecondVowelGroupIsNotOneVietnameseSyllable() {
        let engine = VNIEngine()
        var visible = ""
        type("ba5n", engine: engine, into: &visible)
        XCTAssertEqual(visible, "bạn")
        type("ana123", engine: engine, into: &visible)
        XCTAssertEqual(visible, "ba5nana123")
    }

    func testValidLookingNumericSuffixStillHasVNIMeaning() {
        for (input, expected) in [("ban5", "bạn"), ("ban51", "bán"), ("ban123", "bản"), ("d9a4", "đã")] {
            let engine = VNIEngine()
            var visible = ""
            type(input, engine: engine, into: &visible)
            XCTAssertEqual(visible, expected)
        }
    }

    func testCommonDAbbreviationsAllowEarlyOrLateStrokeModifier() {
        for ending in ["c", "t", "k", "g", "h", "v", "b", "s"] {
            for input in ["d9" + ending, "d" + ending + "9"] {
                let engine = VNIEngine()
                var visible = ""
                type(input, engine: engine, into: &visible)
                XCTAssertEqual(visible, "đ" + ending, input)
                apply(engine.finish(), to: &visible)
                XCTAssertEqual(visible, "đ" + ending, input)
            }
        }
        for (input, expected) in [("D9C", "ĐC"), ("DC9", "ĐC"), ("dT9", "đT"), ("D9t", "Đt")] {
            let engine = VNIEngine()
            var visible = ""
            type(input, engine: engine, into: &visible)
            XCTAssertEqual(visible, expected)
        }
    }

    func testDAbbreviationIsVisibleImmediatelyAndStaysNarrow() {
        let engine = VNIEngine()
        var visible = ""
        for (key, expected): (Character, String) in [("d", "d"), ("9", "đ"), ("c", "đc")] {
            apply(engine.process(key), to: &visible)
            XCTAssertEqual(visible, expected)
        }
        for input in ["cmd9", "cd9", "dcs9", "d9cmd", "dc123", "model123", "matkhau123", "password"] {
            engine.reset()
            visible = ""
            type(input, engine: engine, into: &visible)
            XCTAssertEqual(visible, input)
        }
    }

    func testIncompleteOnsetsAndVowelGroupsRemainComposable() {
        for prefix in ["ng", "ngh", "q", "qu", "gi", "uo", "uoi", "uon", "uong", "uoc", "ie", "tie"] {
            let engine = VNIEngine()
            var visible = ""
            type(prefix, engine: engine, into: &visible)
            XCTAssertEqual(visible, prefix)
        }
        for (input, expected) in [
            ("nghie6n", "nghiên"), ("tie61ng", "tiếng"), ("quye6n2", "quyền"),
            ("giua74", "giữa"), ("uou7", "ươu"), ("uu7", "ưu"), ("ba5n", "bạn")
        ] {
            let engine = VNIEngine()
            var visible = ""
            type(input, engine: engine, into: &visible)
            XCTAssertEqual(visible, expected)
        }
    }

    func testBackspaceCanMakeLiteralTextComposableAgain() {
        for (input, expected) in [("matkhau", "mạt"), ("MatKhau", "Mạt")] {
            let engine = VNIEngine()
            var visible = ""
            type(input, engine: engine, into: &visible)
            for _ in 0..<4 { apply(engine.backspace(), to: &visible) }
            apply(engine.process("5"), to: &visible)
            XCTAssertEqual(visible, expected)
        }

        let engine = VNIEngine()
        var visible = ""
        type("ba1tman", engine: engine, into: &visible)
        for _ in 0..<4 { apply(engine.backspace(), to: &visible) }
        XCTAssertEqual(visible, "ba1", "Visible backspace must not silently replay restored digits")
        apply(engine.backspace(), to: &visible)
        apply(engine.process("5"), to: &visible)
        XCTAssertEqual(visible, "bạ")
    }

    func testExplicitRawAliasesStillOverrideTheStructuralGuard() {
        let rules = ["abn5": "bạn", "ab5n": "bạn", "matkhau123": "mật khẩu"]
        let engine = VNIEngine(corrections: rules)
        for (input, expected) in rules {
            var visible = ""
            type(input, engine: engine, into: &visible)
            XCTAssertEqual(visible, input)
            apply(engine.finish(), to: &visible)
            XCTAssertEqual(visible, expected)
        }
    }

    func testOneExactPersonalRuleWinsOnceAtBoundary() {
        let engine = VNIEngine(corrections: [
            "matkhau123": "mật khẩu", "ban5": "Bạn bè", "a": "b", "b": "c"
        ])
        for (input, candidate, expected) in [
            ("matkhau123", "matkhau123", "mật khẩu"),
            ("ban5", "bạn", "Bạn bè"),
            ("a", "a", "b"),
            ("b", "b", "c")
        ] {
            var visible = ""
            type(input, engine: engine, into: &visible)
            XCTAssertEqual(visible, candidate, "A personal rule does not replace a token while it is still being typed")
            apply(engine.finish(), to: &visible)
            XCTAssertEqual(visible, expected, "The replacement must not become another raw alias")
            apply(engine.finish(), to: &visible)
            XCTAssertEqual(visible, expected, "A second commit cannot apply the same rule twice")
        }
    }

    func testPrefixAliasesAndResumedUnknownKeysDoNotTriggerRules() {
        let engine = VNIEngine(corrections: ["matkhau": "WRONG", "ban": "WRONG", "go4": "WRONG"])
        for (input, expected) in [("matkhau123", "matkhau123"), ("ban5", "bạn")] {
            var visible = ""
            type(input, engine: engine, into: &visible)
            apply(engine.finish(), to: &visible)
            XCTAssertEqual(visible, expected)
        }
        engine.corrections["ban5"] = "WRONG"
        var visible = "ban"
        engine.resume(visible)
        apply(engine.process("5"), to: &visible)
        apply(engine.finish(), to: &visible)
        XCTAssertEqual(visible, "bạn")
    }

    func testResumePreservesInvalidVisibleWordAndDoesNotEnableRawAliases() {
        let engine = VNIEngine(corrections: ["matkhau123": "WRONG"])
        var visible = "matkhau"
        engine.resume(visible)
        type("123", engine: engine, into: &visible)
        XCTAssertEqual(visible, "matkhau123")
        apply(engine.finish(), to: &visible)
        XCTAssertEqual(visible, "matkhau123")

        visible = "nhận"
        engine.resume(visible)
        apply(engine.process("4"), to: &visible)
        XCTAssertEqual(visible, "nhẫn")
    }

    func testRepeatedModifierEscapeRemainsAnExplicitLiteralOperation() {
        for (input, expected) in [("a11", "a1"), ("a66", "a6"), ("d99", "d9"), ("uo77", "uo7"), ("a11b", "a1b")] {
            let engine = VNIEngine()
            var visible = ""
            type(input, engine: engine, into: &visible)
            XCTAssertEqual(visible, expected)
        }
    }

    func testLiteralFreezeEndsAtBoundaryAndRemainsBounded() {
        let engine = VNIEngine()
        var visible = ""
        let longIdentifier = "ma6t" + String(repeating: "x", count: 150) + "123"
        type(longIdentifier, engine: engine, into: &visible)
        XCTAssertEqual(visible, longIdentifier)
        XCTAssertLessThanOrEqual(engine.raw.count, 128)
        XCTAssertLessThanOrEqual(engine.rendered.count, 128)
        apply(engine.finish(), to: &visible)
        visible = ""
        type("ban5", engine: engine, into: &visible)
        XCTAssertEqual(visible, "bạn")
    }
}
