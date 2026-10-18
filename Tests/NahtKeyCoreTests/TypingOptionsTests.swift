import XCTest
@testable import NahtKeyCore

final class TypingOptionsTests: XCTestCase {
    private func apply(_ edit: TextEdit, to visible: inout String) {
        XCTAssertLessThanOrEqual(edit.deleteCount, visible.count)
        visible.removeLast(min(edit.deleteCount, visible.count))
        visible.append(edit.insertText)
    }

    private func type(_ input: String, into engine: VNIEngine) -> String {
        var visible = ""
        for key in input { apply(engine.process(key), to: &visible) }
        return visible
    }

    func testBackspaceRelocatesToneInBothMethods() {
        let examples: [(InputMethod, String, String, String, TextEdit)] = [
            (.vni, "hoa2n", "hoàn", "hòa", TextEdit(deleteCount: 3, insertText: "òa")),
            (.vni, "tuy2a", "tuỳa", "tùy", TextEdit(deleteCount: 3, insertText: "ùy")),
            (.telex, "hoafn", "hoàn", "hòa", TextEdit(deleteCount: 3, insertText: "òa")),
            (.telex, "tuyfa", "tuỳa", "tùy", TextEdit(deleteCount: 3, insertText: "ùy"))
        ]
        for (method, keys, before, after, expectedEdit) in examples {
            let engine = VNIEngine(inputMethod: method)
            var visible = type(keys, into: engine)
            XCTAssertEqual(visible, before, keys)
            let edit = engine.backspace()
            XCTAssertEqual(edit, expectedEdit, keys)
            apply(edit, to: &visible)
            XCTAssertEqual(visible, after, keys)
            XCTAssertEqual(engine.rendered, after, keys)
        }
    }

    func testLegacyEnglishTelexBehaviorIsReproduced() {
        for (keys, expected) in ["test": "tét", "user": "ủe", "office": "ofice", "useEffect": "uêfct", "JavaScript": "Jẩvcipt"] {
            let engine = VNIEngine(inputMethod: .telex)
            var visible = type(keys, into: engine)
            XCTAssertEqual(visible, expected, keys)
            apply(engine.finish(), to: &visible)
            XCTAssertEqual(visible, expected, keys)
        }
    }

    func testOptInEnglishRestoresOnlyAtBoundary() {
        for (keys, composed) in ["user": "ủe", "office": "ofice", "useEffect": "uêfct", "JavaScript": "Jẩvcipt"] {
            let engine = VNIEngine(inputMethod: .telex, options: .init(restoreEnglishTelex: true))
            var visible = type(keys, into: engine)
            XCTAssertEqual(visible, composed, keys)
            apply(engine.finish(), to: &visible)
            XCTAssertEqual(visible, keys, keys)
        }
    }

    func testEnabledRestoreKeepsPrecomposedMixedCaseVietnamese() {
        let engine = VNIEngine(inputMethod: .telex, options: .init(restoreEnglishTelex: true))
        var visible = type("tiếngViệt", into: engine)
        XCTAssertEqual(visible, "tiếngViệt")
        apply(engine.finish(), to: &visible)
        XCTAssertEqual(visible, "tiếngViệt")
    }


    func testBackspaceNormalizationCanBeDisabled() {
        for (method, keys, expected) in [
            (InputMethod.vni, "hoa2n", "hoà"), (.vni, "tuy2a", "tuỳ"),
            (.telex, "hoafn", "hoà"), (.telex, "tuyfa", "tuỳ")
        ] {
            let engine = VNIEngine(inputMethod: method, options: .init(normalizeToneOnBackspace: false))
            var visible = type(keys, into: engine)
            XCTAssertEqual(engine.backspace(), TextEdit(deleteCount: 1, insertText: ""))
            visible.removeLast()
            XCTAssertEqual(engine.rendered, expected)
            XCTAssertEqual(visible, expected)
        }
    }

    func testBothTonePoliciesAndBackspaceInBothMethods() {
        let words: [(InputMethod, String, String, String)] = [
            (.vni, "hoa2", "hòa", "hoà"), (.vni, "khoe3", "khỏe", "khoẻ"),
            (.vni, "thuy3", "thủy", "thuỷ"), (.vni, "HOA2", "HÒA", "HOÀ"),
            (.vni, "ho2an", "hoàn", "hoàn"), (.vni, "quy1", "quý", "quý"),
            (.vni, "gia2", "già", "già"), (.vni, "tieng61", "tiếng", "tiếng"),
            (.telex, "hoaf", "hòa", "hoà"), (.telex, "khoer", "khỏe", "khoẻ"),
            (.telex, "thuyr", "thủy", "thuỷ"), (.telex, "HOAF", "HÒA", "HOÀ"),
            (.telex, "hofan", "hoàn", "hoàn"), (.telex, "quys", "quý", "quý"),
            (.telex, "giaf", "già", "già"), (.telex, "tieengs", "tiếng", "tiếng")
        ]
        for policy in TonePlacement.allCases {
            for (method, input, traditional, modern) in words {
                let engine = VNIEngine(inputMethod: method, options: .init(tonePlacement: policy))
                XCTAssertEqual(type(input, into: engine), policy == .traditional ? traditional : modern, input)
            }
        }
        for (method, input, expected) in [
            (InputMethod.vni, "hoa2n", "hoà"), (.vni, "tuy2a", "tuỳ"),
            (.telex, "hoafn", "hoà"), (.telex, "tuyfa", "tuỳ")
        ] {
            let engine = VNIEngine(inputMethod: method, options: .init(tonePlacement: .modern))
            var visible = type(input, into: engine)
            apply(engine.backspace(), to: &visible)
            XCTAssertEqual(visible, expected)
        }
    }

    func testEnglishRestorePreservesVietnameseAndExplicitEscapes() {
        let examples = [
            "aa": "â", "aw": "ă", "ee": "ê", "oo": "ô", "ow": "ơ", "uw": "ư", "dd": "đ",
            "aas": "ấ", "aws": "ắ", "ees": "ế", "oos": "ố", "ows": "ớ", "uws": "ứ",
            "as": "á", "af": "à", "ar": "ả", "ax": "ã", "aj": "ạ",
            "banj": "bạn", "bajn": "bạn", "tieengs": "tiếng", "caafn": "cần",
            "dduowngf": "đường", "dduwowngf": "đường", "ddawngs": "đắng",
            "ddax": "đã", "DDAX": "ĐÃ", "DdaX": "Đã", "TIEENGS": "TIẾNG", "Tieengs": "Tiếng",
            "uuw": "ưu", "uwu": "ưu", "uwuw": "ưu", "luuw": "lưu", "huuwx": "hữu",
            "cuuws": "cứu", "huouw": "hươu", "ruouwj": "rượu", "luoiwx": "lưỡi", "uoiw": "ươi",
            "toois": "tối", "uaw": "ưa", "uow": "ươ", "uwow": "ươ",
            "hoaf": "hòa", "hofan": "hoàn", "khoer": "khỏe", "thuyr": "thủy",
            "ngoaif": "ngoài", "quys": "quý", "quas": "quá", "quoocs": "quốc",
            "quyeenf": "quyền", "gias": "giá", "gians": "gián", "gis": "gí",
            "giauf": "giàu", "giuwax": "giữa", "giuawx": "giữa", "quow": "quơ",
            "quaw": "quă", "banjs": "bán", "tieesng": "tiếng", "tieseng": "tiếng",
            "aaa": "aa", "aww": "aw", "eee": "ee", "ooo": "oo", "oww": "ow", "uww": "uw",
            "ddd": "dd", "ass": "as", "uoww": "uow", "ASS": "AS",
            "aaz": "a", "asz": "a", "ddaz": "da", "z": "z", "2026": "2026",
            "bc123": "bc123", "hello": "hello", "test": "tét", "ddc": "đc", "dcd": "đc"
        ]
        for (keys, expected) in examples {
            let engine = VNIEngine(inputMethod: .telex, options: .init(restoreEnglishTelex: true))
            var visible = type(keys, into: engine)
            apply(engine.finish(), to: &visible)
            XCTAssertEqual(visible, expected, keys)
        }
    }

    func testManualRestoreWorksWithoutAutomaticRestoreAndStaysLiteral() throws {
        for (method, input) in [(InputMethod.vni, "ban5"), (.telex, "test"), (.telex, "aas")] {
            let engine = VNIEngine(inputMethod: method)
            var visible = type(input, into: engine)
            apply(try XCTUnwrap(engine.restoreRaw()), to: &visible)
            XCTAssertEqual(visible, input)
            XCTAssertNil(engine.restoreRaw())
            for key in "as5" { apply(engine.process(key), to: &visible) }
            XCTAssertEqual(visible, input + "as5")
            apply(engine.finish(), to: &visible)
            XCTAssertEqual(visible, input + "as5")
            XCTAssertEqual(type(method == .vni ? "ban5" : "banj", into: engine), "bạn")
        }
    }

    func testRawRestoreNeverGuessesAfterBackspaceOrResume() {
        for automatic in [false, true] {
            let engine = VNIEngine(inputMethod: .telex, options: .init(restoreEnglishTelex: automatic))
            var visible = type("user", into: engine)
            apply(engine.backspace(), to: &visible)
            XCTAssertNil(engine.restoreRaw())
            apply(engine.process("e"), to: &visible)
            XCTAssertNil(engine.restoreRaw())
            let composed = visible
            apply(engine.finish(), to: &visible)
            XCTAssertEqual(visible, composed)
            engine.resume("ủe")
            XCTAssertNil(engine.restoreRaw())
            XCTAssertEqual(engine.finish(), TextEdit(deleteCount: 0, insertText: ""))
            engine.resume("tiếng")
            visible = "tiếng"
            apply(engine.process("s"), to: &visible)
            apply(engine.process("V"), to: &visible)
            XCTAssertEqual(visible, "tiếngV", "Mixed-case protection must not replay unknown source keys")
            XCTAssertNil(engine.restoreRaw())
        }
    }

    func testPersonalCorrectionsWinOverEnglishRestore() {
        for corrections in [["user": "người dùng"], ["ủe": "bí danh"], ["user": "đúng", "ủe": "sai"]] {
            let engine = VNIEngine(corrections: corrections, inputMethod: .telex,
                                   options: .init(restoreEnglishTelex: true))
            var visible = type("user", into: engine)
            apply(engine.finish(), to: &visible)
            XCTAssertEqual(visible, corrections["user"] ?? corrections["ủe"])
        }
    }

    func testEnglishOptionDoesNotChangeVNI() {
        for (input, expected) in ["ban5": "bạn", "ba5n": "bạn", "tieng61": "tiếng", "u7u": "ưu", "uu7": "ưu", "model123": "model123", "matkhau123": "matkhau123", "a11": "a1"] {
            let engine = VNIEngine(options: .init(restoreEnglishTelex: true))
            var visible = type(input, into: engine)
            apply(engine.finish(), to: &visible)
            XCTAssertEqual(visible, expected, input)
        }
    }

    func testLongTokensCannotRestoreUnknownRawSuffix() {
        let engine = VNIEngine(inputMethod: .telex, options: .init(restoreEnglishTelex: true))
        var visible = type("as" + String(repeating: "b", count: 140), into: engine)
        let before = visible
        XCTAssertNil(engine.restoreRaw())
        apply(engine.finish(), to: &visible)
        XCTAssertEqual(visible, before)
        XCTAssertTrue(engine.raw.isEmpty)
    }

    func testOptionsRoundTripAndChangeResetOnlyOnDifference() throws {
        let options = TypingOptions(normalizeToneOnBackspace: false, restoreEnglishTelex: true, tonePlacement: .modern)
        XCTAssertEqual(try JSONDecoder().decode(TypingOptions.self, from: JSONEncoder().encode(options)), options)
        let engine = VNIEngine()
        _ = type("ban", into: engine)
        engine.options = TypingOptions()
        XCTAssertEqual(engine.rendered, "ban")
        engine.options = options
        XCTAssertEqual(engine.rendered, "")
        XCTAssertNil(engine.restoreRaw())
    }

    func testSessionTracksRelocatedDeletionRestorationAndOptionResets() throws {
        for method in InputMethod.allCases {
            let session = TypingSession(inputMethod: method)
            var visible = ""
            for key in method == .vni ? "hoa2n" : "hoafn" { apply(session.process(key), to: &visible) }
            apply(session.backspace(), to: &visible)
            XCTAssertEqual(visible, "hòa")
            apply(session.finish(boundary: " "), to: &visible)
            visible.append(" ")
            apply(session.backspace(), to: &visible)
            XCTAssertEqual(session.rendered, "hòa")
            apply(session.process(method == .vni ? "3" : "r"), to: &visible)
            XCTAssertEqual(visible, "hỏa")
            XCTAssertNil(session.restoreRaw())
        }
        let session = TypingSession(inputMethod: .telex, options: .init(restoreEnglishTelex: true))
        var visible = ""
        for key in "user" { apply(session.process(key), to: &visible) }
        apply(session.finish(boundary: " "), to: &visible)
        visible.append(" ")
        XCTAssertEqual(visible, "user ")
        apply(session.backspace(), to: &visible)
        XCTAssertEqual(session.rendered, "user")
        XCTAssertNil(session.restoreRaw())
        session.reset()
        visible = ""
        for key in "test" { apply(session.process(key), to: &visible) }
        apply(try XCTUnwrap(session.restoreRaw()), to: &visible)
        XCTAssertEqual(visible, "test")
        session.options = session.options
        XCTAssertEqual(session.rendered, "test")
        session.options = TypingOptions(tonePlacement: .modern)
        XCTAssertEqual(session.rendered, "")
        apply(session.backspace(), to: &visible)
        XCTAssertEqual(session.rendered, "")
    }


    func testManualRestoreSuppressesPersonalCorrectionsUntilNextBoundary() throws {
        for (method, keys, composed) in [(InputMethod.vni, "ban5", "bạn"), (.telex, "bans", "bán")] {
            let engine = VNIEngine(corrections: [keys: "khác", keys + "a": "cũng khác"], inputMethod: method)
            var visible = type(keys, into: engine)
            XCTAssertEqual(visible, composed)
            apply(try XCTUnwrap(engine.restoreRaw()), to: &visible)
            apply(engine.finish(), to: &visible)
            XCTAssertEqual(visible, keys, "A manually restored token must stay literal at its boundary")

            visible = type(keys, into: engine)
            apply(try XCTUnwrap(engine.restoreRaw()), to: &visible)
            apply(engine.process("a"), to: &visible)
            apply(engine.finish(), to: &visible)
            XCTAssertEqual(visible, keys + "a", "Later literal input must not re-enable personal corrections")

            visible = type(keys, into: engine)
            apply(try XCTUnwrap(engine.restoreRaw()), to: &visible)
            apply(engine.backspace(), to: &visible)
            apply(engine.process(method == .vni ? "5" : "s"), to: &visible)
            XCTAssertEqual(visible, keys, "Backspace must keep a restored token literal until its boundary")
            apply(engine.finish(), to: &visible)
            XCTAssertEqual(visible, keys)

            visible = type(keys, into: engine)
            apply(engine.finish(), to: &visible)
            XCTAssertEqual(visible, "khác", "Personal corrections resume for the next token")
        }
    }

}
