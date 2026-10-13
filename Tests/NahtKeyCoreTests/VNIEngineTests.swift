import XCTest
@testable import NahtKeyCore

final class VNIEngineTests: XCTestCase {
    private func type(_ input: String, into engine: VNIEngine) -> String {
        var visible = ""
        for character in input {
            apply(engine.process(character), to: &visible)
            XCTAssertEqual(visible, engine.rendered, "State mismatch after \(character), input \(input)")
        }
        return visible
    }

    private func apply(_ edit: TextEdit, to text: inout String) {
        XCTAssertLessThanOrEqual(edit.deleteCount, text.count)
        text.removeLast(min(edit.deleteCount, text.count))
        text.append(edit.insertText)
    }

    func testVNIWordsAndFreeModifierOrder() {
        let examples = [
            "ban5": "bạn", "ba5n": "bạn", "tieng61": "tiếng", "tie61ng": "tiếng",
            "can62": "cần", "ca62n": "cần", "Viet65": "Việt", "VIE65T": "VIỆT",
            "duong972": "đường", "d9uo72ng": "đường", "thu7ong": "thương",
            "thu7o7ng": "thương", "thuong7": "thương", "nua74": "nữa",
            "trang81": "trắng", "D9A81NG": "ĐẮNG", "a8": "ă", "o6": "ô",
            "d9a4": "đã", "da49": "đã", "u7u": "ưu", "uu7": "ưu", "luu7": "lưu", "to6i1": "tối",
            "cuu71": "cứu", "huou7": "hươu", "ruou75": "rượu", "luoi74": "lưỡi", "uoi7": "ươi",
            "dau61": "dấu", "d9au62": "đầu", "d9ao3": "đảo", "d9ay65": "đậy",
            "ma1": "má", "ma2": "mà", "ma3": "mả", "ma4": "mã", "ma5": "mạ"
        ]
        for (keys, expected) in examples {
            let engine = VNIEngine()
            XCTAssertEqual(type(keys, into: engine), expected, keys)
            XCTAssertEqual(engine.raw, keys)
        }
    }

    func testTonePlacementAndRelocation() {
        let examples = [
            "hoa2": "hòa", "ho2an": "hoàn", "khoe3": "khỏe", "thuy3": "thủy",
            "ngoai2": "ngoài", "quy1": "quý", "qua1": "quá", "quoc61": "quốc",
            "quyen62": "quyền", "gia1": "giá", "gian1": "gián", "gi1": "gí",
            "giau2": "giàu", "giua74": "giữa", "quo7": "quơ"
        ]
        for (keys, expected) in examples {
            XCTAssertEqual(type(keys, into: VNIEngine()), expected, keys)
        }
    }

    func testExactRawAliasesAtBoundaryRegardlessOfRenderedText() {
        let engine = VNIEngine(corrections: ["abn5": "bạn", "ab5n": "bạn"])
        for alias in ["abn5", "ab5n"] {
            var visible = type(alias, into: engine)
            XCTAssertNotEqual(visible, alias)
            XCTAssertNotEqual(visible, "bạn", "Corrections wait until a boundary")
            apply(engine.finish(), to: &visible)
            XCTAssertEqual(visible, "bạn")
            XCTAssertEqual(engine.raw, "")
            XCTAssertEqual(engine.rendered, "")
        }
    }

    func testAliasesAreExactCaseSensitiveAndDoNotGuess() {
        for input in ["Abn5", "xabn5", "abn", "abn4"] {
            let engine = VNIEngine(corrections: ["abn5": "bạn"])
            let displayed = type(input, into: engine)
            var result = displayed
            apply(engine.finish(), to: &result)
            XCTAssertEqual(result, displayed)
        }
    }

    func testOrdinaryTextNumbersAndUnmatchedModifiersStayLiteral() {
        for input in ["hello", "Swift", "1234567890", "2026", "bc123", "🙂", "foo@example.com"] {
            XCTAssertEqual(type(input, into: VNIEngine()), input, input)
        }
    }

    func testToneReplacementEscapingAndClear() {
        let examples = [
            "ban51": "bán", "a11": "a1", "a66": "a6", "d99": "d9",
            "uo77": "uo7", "ban50": "ban", "tie60ng": "tieng", "d90": "d",
            "a0": "a0"
        ]
        for (keys, expected) in examples {
            XCTAssertEqual(type(keys, into: VNIEngine()), expected, keys)
        }
    }

    func testBackspaceDeletesVisibleCharacterThenContinuesComposition() {
        let engine = VNIEngine(corrections: ["ban5": "WRONG", "bạn": "WRONG"])
        var visible = type("ban5", into: engine)
        apply(engine.backspace(), to: &visible)
        XCTAssertEqual(visible, "bạ")
        XCTAssertEqual(engine.rendered, visible)
        apply(engine.process("n"), to: &visible)
        XCTAssertEqual(visible, "bạn")
        apply(engine.finish(), to: &visible)
        XCTAssertEqual(visible, "bạn", "Reconstructed raw must not match personal rules")

        visible = type("a6", into: engine)
        apply(engine.backspace(), to: &visible)
        XCTAssertEqual(visible, "")
        apply(engine.process("b"), to: &visible)
        XCTAssertEqual(visible, "b")
    }

    func testEditsCountVisibleGraphemesIncludingPersonalPhrases() {
        let engine = VNIEngine(corrections: ["x": "bạn 👨‍👩‍👧‍👦", "longalias": "ý"])
        var visible = type("x", into: engine)
        let long = engine.finish()
        XCTAssertEqual(long.deleteCount, 1)
        apply(long, to: &visible)
        XCTAssertEqual(visible, "bạn 👨‍👩‍👧‍👦")

        visible = type("longalias", into: engine)
        let short = engine.finish()
        XCTAssertEqual(short.deleteCount, 9)
        apply(short, to: &visible)
        XCTAssertEqual(visible, "ý")

        visible = type("a\u{0301}", into: engine)
        XCTAssertEqual(visible.count, 1)
        apply(engine.backspace(), to: &visible)
        XCTAssertEqual(visible, "")
    }

    func testResetAndBoundaryDoNotLeakPreviousToken() {
        let engine = VNIEngine(corrections: ["abn5": "bạn"])
        _ = type("ab", into: engine)
        engine.reset()
        XCTAssertEqual(type("n5", into: engine), "n5")
        XCTAssertEqual(engine.finish(), TextEdit(deleteCount: 0, insertText: ""))
        XCTAssertEqual(type("ban5", into: engine), "bạn")
        XCTAssertEqual(engine.finish(), TextEdit(deleteCount: 0, insertText: ""))
        XCTAssertEqual(type("123", into: engine), "123")
    }

    func testLongTokenCaptureIsBoundedAndCannotMatchSuffixAlias() {
        let engine = VNIEngine(corrections: ["abn5": "bạn"])
        var visible = ""
        let input = String(repeating: "x", count: 129) + "abn5"
        for character in input {
            apply(engine.process(character), to: &visible)
            XCTAssertLessThanOrEqual(engine.raw.count, 128)
            XCTAssertLessThanOrEqual(engine.rendered.count, 128)
        }
        XCTAssertEqual(visible, input)
        apply(engine.finish(), to: &visible)
        XCTAssertEqual(visible, input)
        var fresh = type("abn5", into: engine)
        apply(engine.finish(), to: &fresh)
        XCTAssertEqual(fresh, "bạn")
    }

    func testTelexVowelsWordsAndUppercase() {
        let examples = [
            "aa": "â", "aw": "ă", "ee": "ê", "oo": "ô", "ow": "ơ", "uw": "ư", "dd": "đ",
            "aas": "ấ", "aws": "ắ", "ees": "ế", "oos": "ố", "ows": "ớ", "uws": "ứ",
            "as": "á", "af": "à", "ar": "ả", "ax": "ã", "aj": "ạ",
            "banj": "bạn", "bajn": "bạn", "tieengs": "tiếng", "caafn": "cần",
            "dduowngf": "đường", "dduwowngf": "đường", "ddawngs": "đắng",
            "ddax": "đã", "DDAX": "ĐÃ", "DdaX": "Đã", "TIEENGS": "TIẾNG",
            "uuw": "ưu", "uwu": "ưu", "uwuw": "ưu", "luuw": "lưu", "huuwx": "hữu",
            "cuuws": "cứu", "huouw": "hươu", "ruouwj": "rượu", "luoiwx": "lưỡi", "uoiw": "ươi",
            "toois": "tối", "uaw": "ưa", "uow": "ươ", "uwow": "ươ"
        ]
        for (keys, expected) in examples {
            let engine = VNIEngine(inputMethod: .telex)
            XCTAssertEqual(type(keys, into: engine), expected, keys)
            XCTAssertEqual(engine.raw, keys)
        }
    }

    func testTelexTonePlacementAndReplacement() {
        let examples = [
            "hoaf": "hòa", "hofan": "hoàn", "khoer": "khỏe", "thuyr": "thủy",
            "ngoaif": "ngoài", "quys": "quý", "quas": "quá", "quoocs": "quốc",
            "quyeenf": "quyền", "gias": "giá", "gians": "gián", "gis": "gí",
            "giauf": "giàu", "giuwax": "giữa", "giuawx": "giữa", "quow": "quơ",
            "quaw": "quă", "banjs": "bán", "tieesng": "tiếng", "tieseng": "tiếng"
        ]
        for (keys, expected) in examples {
            XCTAssertEqual(type(keys, into: VNIEngine(inputMethod: .telex)), expected, keys)
        }
    }

    func testTelexRepeatEscapesAndClear() {
        let examples = [
            "aaa": "aa", "aww": "aw", "eee": "ee", "ooo": "oo", "oww": "ow",
            "uww": "uw", "ddd": "dd", "ass": "as", "uoww": "uow", "ASS": "AS",
            "aaz": "a", "asz": "a", "ddaz": "da", "z": "z", "2026": "2026",
            "bc123": "bc123", "hello": "hello"
        ]
        for (keys, expected) in examples {
            XCTAssertEqual(type(keys, into: VNIEngine(inputMethod: .telex)), expected, keys)
        }
    }

    func testRawAliasesAreIndependentOfInputMethod() {
        for method in InputMethod.allCases {
            let engine = VNIEngine(corrections: ["abn5": "bạn", "ab5n": "bạn", "abnj": "bạn"], inputMethod: method)
            for alias in ["abn5", "ab5n", "abnj"] {
                var visible = type(alias, into: engine)
                apply(engine.finish(), to: &visible)
                XCTAssertEqual(visible, "bạn", "\(method): \(alias)")
            }
        }
    }

    func testMethodChangeResetsOnlyWhenActuallyChanged() {
        let engine = VNIEngine(corrections: ["abn5": "bạn"])
        _ = type("ban", into: engine)
        engine.inputMethod = .vni
        XCTAssertEqual(engine.raw, "ban")
        XCTAssertEqual(engine.rendered, "ban")
        _ = engine.process("5")
        XCTAssertEqual(engine.rendered, "bạn")

        engine.inputMethod = .telex
        XCTAssertEqual(engine.raw, "")
        XCTAssertEqual(engine.rendered, "")
        XCTAssertEqual(type("ddax", into: engine), "đã")
        _ = engine.finish()
        var visible = type("abn5", into: engine)
        apply(engine.finish(), to: &visible)
        XCTAssertEqual(visible, "bạn", "Changing methods must preserve the dictionary")
    }

    func testTelexVisibleBackspaceAndContinue() {
        let engine = VNIEngine(inputMethod: .telex)
        var visible = type("ddax", into: engine)
        apply(engine.backspace(), to: &visible)
        XCTAssertEqual(visible, "đ")
        apply(engine.process("a"), to: &visible)
        apply(engine.process("s"), to: &visible)
        XCTAssertEqual(visible, "đá")
        apply(engine.backspace(), to: &visible)
        apply(engine.backspace(), to: &visible)
        XCTAssertEqual(visible, "")
        apply(engine.process("u"), to: &visible)
        apply(engine.process("u"), to: &visible)
        apply(engine.process("w"), to: &visible)
        XCTAssertEqual(visible, "ưu")
    }

    func testRapidConsecutiveWordsKeepBoundariesAndCharacters() {
        let cases: [(InputMethod, String, String)] = [
            (.vni, "d9a4 to6i1 u7u abn5 ab5n, tieng61 Vie6t5.", "đã tối ưu bạn bạn, tiếng Việt."),
            (.telex, "ddax toois uuw abn5 ab5n, tieengs Vieetj.", "đã tối ưu bạn bạn, tiếng Việt.")
        ]
        for (method, input, expected) in cases {
            let engine = VNIEngine(corrections: ["abn5": "bạn", "ab5n": "bạn"], inputMethod: method)
            var visible = ""
            // No artificial sleeps: every edit must remain valid even when keys
            // arrive consecutively. The adapter owns real event-delivery ordering.
            for _ in 0..<100 {
                for character in input {
                    if character.isLetter || character.isNumber {
                        apply(engine.process(character), to: &visible)
                    } else {
                        apply(engine.finish(), to: &visible)
                        visible.append(character)
                    }
                }
            }
            XCTAssertEqual(visible, String(repeating: expected, count: 100), method.displayName)
        }
    }

    func testResumeVisibleWordReplacesToneAndDisablesExactRawAliases() {
        let engine = VNIEngine(corrections: ["go4": "WRONG", "nhận4": "WRONG"])
        for (word, expected) in [("go", "gõ"), ("nhận", "nhẫn")] {
            var visible = word
            engine.resume(word)
            apply(engine.process("4"), to: &visible)
            XCTAssertEqual(visible, expected)
            apply(engine.finish(), to: &visible)
            XCTAssertEqual(visible, expected)
        }

        engine.inputMethod = .telex
        var visible = "nhận"
        engine.resume(visible)
        apply(engine.process("x"), to: &visible)
        XCTAssertEqual(visible, "nhẫn")
    }
}
