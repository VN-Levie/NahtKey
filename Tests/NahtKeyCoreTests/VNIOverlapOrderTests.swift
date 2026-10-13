import XCTest
@testable import NahtKeyCore

/// These tests vary logical key order after the relevant base vowel exists.
/// They verify composition and returned edits, not physical key timing or the
/// macOS event-delivery path; pressing a modifier before any eligible vowel is
/// deliberately tested as literal input instead of being predicted/reordered.
final class VNIOverlapOrderTests: XCTestCase {
    private func apply(_ edit: TextEdit, to visible: inout String, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertGreaterThanOrEqual(edit.deleteCount, 0, file: file, line: line)
        XCTAssertLessThanOrEqual(edit.deleteCount, visible.count, file: file, line: line)
        visible.removeLast(min(max(edit.deleteCount, 0), visible.count))
        visible.append(edit.insertText)
    }

    private func type(_ keys: String, engine: VNIEngine, file: StaticString = #filePath, line: UInt = #line) -> String {
        var visible = ""
        for key in keys {
            apply(engine.process(key), to: &visible, file: file, line: line)
            XCTAssertEqual(visible, engine.rendered, "Edit mismatch for \(keys) after \(key)", file: file, line: line)
        }
        XCTAssertEqual(engine.raw, keys, "Logical key order must remain available to exact aliases", file: file, line: line)
        return visible
    }

    func testAAndETonesBeforeOrAfterShapesAndZeroClearing() {
        // Expected Unicode letters are explicit; no expected value is produced
        // by calling the composer or by replaying another implementation path.
        let rows: [(base: String, shape: String, tones: String)] = [
            ("a", "", "áàảãạ"), ("a", "6", "ấầẩẫậ"), ("a", "8", "ắằẳẵặ"),
            ("e", "", "éèẻẽẹ"), ("e", "6", "ếềểễệ")
        ]
        for row in rows {
            for (index, expectedLetter) in row.tones.enumerated() {
                let tone = String(index + 1)
                let variants = row.shape.isEmpty
                    ? [row.base + tone]
                    : [row.base + row.shape + tone, row.base + tone + row.shape]
                for keys in variants {
                    let engine = VNIEngine()
                    var visible = type(keys, engine: engine)
                    XCTAssertEqual(visible, String(expectedLetter), keys)
                    apply(engine.process("0"), to: &visible)
                    XCTAssertEqual(visible, row.base, "0 clears both shape and tone after \(keys)")
                }
            }
        }
    }

    func testKnownWordsAcrossValidShapeToneAndFinalConsonantOrders() {
        let cases: [(expected: String, variants: [String])] = [
            ("cần", ["can62", "ca6n2", "ca2n6", "ca26n"]),
            ("chậm", ["cham65", "cha6m5", "cha5m6", "cha56m"]),
            ("mến", ["men61", "me6n1", "me1n6", "me16n"]),
            ("biển", ["bien63", "bie6n3", "bi3en6", "bie36n"]),
            ("tiếng", ["tieng61", "tie6ng1", "ti1eng6", "tie16ng"]),
            ("tiểu", ["tieu63", "tie6u3", "ti3eu6", "tie36u"]),
            ("vừa", ["vua72", "vu7a2", "vu2a7", "vu27a"]),
            ("cửa", ["cua73", "cu7a3", "cu3a7", "cu37a"]),
            ("mưa", ["mua7", "mu7a"]),
            ("mía", ["mia1", "mi1a"]),
            ("bìa", ["bia2", "bi2a"])
        ]
        for item in cases {
            for keys in item.variants {
                let engine = VNIEngine()
                var visible = type(keys, engine: engine)
                XCTAssertEqual(visible, item.expected, keys)
                apply(engine.finish(), to: &visible)
                XCTAssertEqual(visible, item.expected, "A boundary must not undo a valid order variant")
            }
        }
    }

    func testStrokeBreveAndToneCanArriveInDifferentOrdersIncludingUppercase() {
        for keys in ["d9a81ng", "d9ang81", "da981ng", "da198ng", "dang918", "dang819"] {
            XCTAssertEqual(type(keys, engine: VNIEngine()), "đắng", keys)
            XCTAssertEqual(type(keys.uppercased(), engine: VNIEngine()), "ĐẮNG", keys)
        }
        for (keys, expected) in [("CA26N", "CẦN"), ("ME16N", "MẾN"), ("BI3EN6", "BIỂN"), ("VU27A", "VỪA")] {
            XCTAssertEqual(type(keys, engine: VNIEngine()), expected)
        }
    }

    func testLaterVowelOrModifierNeverDeletesExistingConsonantPrefix() {
        let cases: [(keys: String, displayedAfterEachKey: [String])] = [
            ("ca2n6", ["c", "ca", "cà", "càn", "cần"]),
            ("me16n", ["m", "me", "mé", "mế", "mến"]),
            ("chu7a", ["c", "ch", "chu", "chư", "chưa"]),
            ("chua7", ["c", "ch", "chu", "chua", "chưa"]),
            ("hoa2n", ["h", "ho", "hoa", "hòa", "hoàn"])
        ]
        for item in cases {
            let engine = VNIEngine()
            var visible = ""
            for (index, key) in item.keys.enumerated() {
                apply(engine.process(key), to: &visible)
                XCTAssertEqual(visible, item.displayedAfterEachKey[index], "\(item.keys) after \(key)")
            }
        }
    }

    func testInapplicableModifiersAndConsecutiveEscapesKeepTheirLiteralMeaning() {
        for keys in ["a7", "e7", "e8", "a9", "e9", "a0", "m6e", "m1a", "7ua"] {
            XCTAssertEqual(type(keys, engine: VNIEngine()), keys, "A missing base is not a timing prediction")
        }
        let escapes = [
            "a11": "a1", "e22": "e2", "a66": "a6", "e66": "e6", "a88": "a8",
            "u77": "u7", "d99": "d9", "a611": "â1", "e622": "ê2"
        ]
        for (keys, expected) in escapes {
            XCTAssertEqual(type(keys, engine: VNIEngine()), expected, keys)
        }
        XCTAssertEqual(type("a68", engine: VNIEngine()), "ă")
        XCTAssertEqual(type("a86", engine: VNIEngine()), "â")
    }

    func testExactRawAliasDistinguishesEquivalentCompositionOrders() {
        let engine = VNIEngine(corrections: [
            "ca6n2": "riêng", "cần": "chuẩn", "riêng": "WRONG", "chuẩn": "WRONG"
        ])
        for (keys, expectedAtBoundary) in [("ca6n2", "riêng"), ("ca2n6", "chuẩn")] {
            var visible = type(keys, engine: engine)
            XCTAssertEqual(visible, "cần")
            apply(engine.finish(), to: &visible)
            XCTAssertEqual(visible, expectedAtBoundary)
        }
    }

    func testConsecutiveMixedOrderWordsAndBoundariesStayIndependent() {
        let session = TypingSession(corrections: ["ưu": "ưu tiên"])
        let keys = "mu7a cu73a bi3en6 tie16ng ca26n me16n d9a18ng uu7 chua7\n"
        let expected = "mưa cửa biển tiếng cần mến đắng ưu tiên chưa\n"
        var visible = ""
        // Deliberately no sleeps: this verifies logical stream state over many
        // boundaries, not physical overlap or CGEvent delivery timing.
        for _ in 0..<20 {
            for key in keys {
                if key.isLetter || key.isNumber {
                    apply(session.process(key), to: &visible)
                } else {
                    apply(session.finish(boundary: key), to: &visible)
                    visible.append(key)
                }
            }
        }
        XCTAssertEqual(visible, String(repeating: expected, count: 20))
    }
}
