import AppKit
import Carbon
import XCTest
import NahtKeyCore
@testable import NahtKeyApp

/// A deterministic delivery model, not an OS timing benchmark. Physical letters
/// remain down through modifiers and Space; synthetic down/up must never use
/// those held keys. Text edits are replayed through real NSTextView operations.
final class VNIKeyOverlapDeliveryTests: XCTestCase {
    private enum ReleaseOrder: CaseIterable { case immediate, afterModifier, afterSpace }
    private static let keycodes: [Character: CGKeyCode] = Dictionary(uniqueKeysWithValues: zip(
        Array("abcdefghijklmnopqrstuvwxyz0123456789 "),
        [0, 11, 8, 2, 14, 3, 5, 4, 34, 38, 40, 37, 46, 45, 31, 35, 12, 15, 1, 17, 32, 9, 13, 7, 16, 6,
         29, 18, 19, 20, 21, 23, 22, 26, 28, 25, 49].map(CGKeyCode.init)
    ))

    @MainActor private func check(_ keys: String, expected: String, order: ReleaseOrder,
                                 extraHeld: Set<CGKeyCode> = [], corrections: [String: String] = [:],
                                 file: StaticString = #filePath, line: UInt = #line) throws {
        let editor = NSTextView(frame: .zero)
        let session = TypingSession(corrections: corrections)
        let source = try XCTUnwrap(KeyboardController.makeEventSource())
        var delivery = KeyDeliveryState()
        var physicalDown = extraHeld
        var targetDown = Set<CGKeyCode>()
        var delayedUps: [CGKeyCode] = []

        func release(_ key: CGKeyCode) {
            physicalDown.remove(key)
            if delivery.release(key) { targetDown.remove(key) }
        }

        for character in keys + " " {
            let key = try XCTUnwrap(Self.keycodes[Character(String(character).lowercased())])
            physicalDown.insert(key)
            let edit = character == " "
                ? ReplacementPlan.committingSpace(after: session.finish(boundary: character))
                : session.process(character)
            let forwarded = character != " " && edit.deleteCount == 0 && edit.insertText == String(character)
            if forwarded {
                targetDown.insert(key)
                editor.insertText(String(character), replacementRange: editor.selectedRange())
            } else {
                let events = try XCTUnwrap(KeyboardEventBatch.make(ReplacementPlan.operations(for: edit),
                    source: source, marker: 42, isPhysicallyDown: {
                        physicalDown.contains($0) || delivery.hasForwardedDown($0)
                    }))
                var syntheticDown = Set<CGKeyCode>()
                for event in events {
                    let outputKey = CGKeyCode(truncatingIfNeeded: event.getIntegerValueField(.keyboardEventKeycode))
                    XCTAssertFalse(targetDown.contains(outputKey), "Synthetic event collides with held physical key", file: file, line: line)
                    XCTAssertFalse(physicalDown.contains(outputKey), "Synthetic event releases physical state", file: file, line: line)
                    if event.type == .keyUp {
                        XCTAssertNotNil(syntheticDown.remove(outputKey), file: file, line: line)
                        continue
                    }
                    XCTAssertTrue(syntheticDown.insert(outputKey).inserted, file: file, line: line)
                    if outputKey == CGKeyCode(kVK_Delete) {
                        editor.deleteBackward(nil)
                    } else {
                        var length = 0
                        var units = [UniChar](repeating: 0, count: 32)
                        event.keyboardGetUnicodeString(maxStringLength: units.count, actualStringLength: &length, unicodeString: &units)
                        editor.insertText(String(utf16CodeUnits: units, count: length), replacementRange: editor.selectedRange())
                    }
                }
                XCTAssertTrue(syntheticDown.isEmpty, file: file, line: line)
            }
            delivery.recordDown(key, forwarded: forwarded)
            if order != .immediate && (character.lowercased() == "a" || character.lowercased() == "e") {
                delayedUps.append(key)
            } else {
                release(key)
            }
            if order == .afterModifier && character.isNumber {
                delayedUps.forEach(release)
                delayedUps.removeAll()
            }
        }
        delayedUps.forEach(release)
        XCTAssertEqual(editor.string, expected + " ", "\(keys), \(order)", file: file, line: line)
        XCTAssertTrue(targetDown.isEmpty, "All forwarded downs must receive their up", file: file, line: line)
    }

    @MainActor func testAllVNIDigitsWithHeldAAndEAndDifferentReleaseOrders() throws {
        var cases: [(String, String)] = [
            ("mua7", "mưa"), ("mu7a", "mưa"), ("chua7", "chưa"), ("chu7a", "chưa"),
            ("cua73", "cửa"), ("cu37a", "cửa"), ("be6", "bê"), ("me61", "mế"),
            ("me16", "mế"), ("ca26n", "cần"), ("tieng61", "tiếng"), ("tie16ng", "tiếng"),
            ("da981ng", "đắng"), ("d9a18ng", "đắng"), ("DANG918", "ĐẮNG"),
            ("a0", "a0"), ("a60", "a"), ("e610", "e"), ("a66", "a6"),
            ("e22", "e2"), ("a88", "a8"), ("d99", "d9"), ("uu7", "ưu")
        ]
        for (base, tones) in [("a", "áàảãạ"), ("e", "éèẻẽẹ"), ("a6", "ấầẩẫậ"),
                              ("a8", "ắằẳẵặ"), ("e6", "ếềểễệ")] {
            for (index, expected) in tones.enumerated() { cases.append((base + String(index + 1), String(expected))) }
        }
        for order in ReleaseOrder.allCases {
            for (keys, expected) in cases {
                try check(keys, expected: expected, order: order)
                try check(keys, expected: expected, order: order, extraHeld: [0, 11, 8, 14])
            }
        }
    }

    @MainActor func testPersonalCorrectionAndLongUnicodeBurstWhileAAndEStayHeld() throws {
        let replacement = "tiếngViệt" + String(repeating: "🙂", count: 12)
        try check("abn5", expected: "bạn", order: .afterSpace, corrections: ["abn5": "bạn"])
        try check("ae", expected: replacement, order: .afterSpace,
                  extraHeld: [0, 11, 8, 14], corrections: ["ae": replacement])
    }
}
