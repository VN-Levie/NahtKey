import XCTest
import NahtKeyCore
@testable import NahtKeyApp

@MainActor
final class CorrectionPriorityIntegrationTests: XCTestCase {
    func testExactRawRuleWinsOverUnicodeRuleAndEnglishRestore() {
        let rules = ["push": "quy tắc thô", "púh": "từ Unicode"]

        XCTAssertEqual(type("push", corrections: rules, options: .init(restoreEnglishTelex: true), method: .telex),
                       "quy tắc thô",
                       "An exact raw-key correction must win over the composed Unicode alias")
        XCTAssertEqual(type("push", corrections: ["púh": "từ Unicode"],
                            options: .init(restoreEnglishTelex: true), method: .telex),
                       "từ Unicode",
                       "The Unicode-word correction must win when no exact raw rule exists")
        XCTAssertEqual(type("push", corrections: [:], options: .init(restoreEnglishTelex: true), method: .telex),
                       "push",
                       "English restoration is the last fallback")
    }

    func testSingleWordPriorityMatrixAcrossPhraseAndEnglishToggles() {
        for expandPhrases in [false, true] {
            for restoreEnglish in [false, true] {
                let options = TypingOptions(restoreEnglishTelex: restoreEnglish)
                let exact = DictionaryStore.activeCorrections(
                    ["push": "thô", "púh": "Unicode"],
                    expandPhrases: expandPhrases)
                XCTAssertEqual(type("push", corrections: exact, options: options, method: .telex),
                               "thô",
                               "raw > Unicode, expandPhrases=\(expandPhrases), restoreEnglish=\(restoreEnglish)")

                let unicode = DictionaryStore.activeCorrections(["púh": "nhấn"],
                                                                  expandPhrases: expandPhrases)
                XCTAssertEqual(type("push", corrections: unicode, options: options, method: .telex),
                               "nhấn",
                               "Unicode > English, expandPhrases=\(expandPhrases), restoreEnglish=\(restoreEnglish)")

                let noCorrection = type("push", corrections: [:], options: options, method: .telex)
                XCTAssertEqual(noCorrection, restoreEnglish ? "push" : "púh",
                               "English fallback, expandPhrases=\(expandPhrases), restoreEnglish=\(restoreEnglish)")
            }
        }
    }

    func testPhraseToggleKeepsOneWordUnicodeRuleAndControlsRawPhraseRule() {
        let rules = ["push": "một câu đầy đủ", "púh": "của"]

        let collapsed = DictionaryStore.activeCorrections(rules, expandPhrases: false)
        XCTAssertNil(collapsed["push"], "A phrase must be inactive while phrase expansion is disabled")
        XCTAssertEqual(collapsed["púh"], "của",
                       "Disabling phrases must not disable a one-word Unicode correction")
        let expanded = DictionaryStore.activeCorrections(rules, expandPhrases: true)
        XCTAssertEqual(expanded, rules)
        for restoreEnglish in [false, true] {
            let options = TypingOptions(restoreEnglishTelex: restoreEnglish)
            XCTAssertEqual(type("push", corrections: collapsed, options: options, method: .telex), "của")
            XCTAssertEqual(type("push", corrections: expanded, options: options, method: .telex), "một câu đầy đủ",
                           "The exact raw phrase must take priority when phrase expansion is enabled")
        }
    }

    func testPhraseRemovalLeavesEnglishRestoreAndUnicodeCorrectionIsUnaffected() {
        let phraseOnly = DictionaryStore.activeCorrections(["push": "một câu đầy đủ"], expandPhrases: false)
        XCTAssertTrue(phraseOnly.isEmpty)
        XCTAssertEqual(type("push", corrections: phraseOnly,
                            options: .init(restoreEnglishTelex: true), method: .telex), "push")

        let oneWord = ["cảu": "của"]
        XCTAssertEqual(DictionaryStore.activeCorrections(oneWord, expandPhrases: false), oneWord)
        XCTAssertEqual(type("cau3", corrections: oneWord, method: .vni), "của")
        XCTAssertEqual(type("caur", corrections: oneWord, method: .telex), "của")
    }

    func testCauUnicodeCorrectionSurvivesEveryPreferenceCombinationAndInputMethod() {
        let rules = ["cảu": "của"]
        for expandPhrases in [false, true] {
            let active = DictionaryStore.activeCorrections(rules, expandPhrases: expandPhrases)
            for restoreEnglish in [false, true] {
                let options = TypingOptions(restoreEnglishTelex: restoreEnglish)
                XCTAssertEqual(type("cau3", corrections: active, options: options, method: .vni), "của",
                               "VNI cau3, expandPhrases=\(expandPhrases), restoreEnglish=\(restoreEnglish)")
                XCTAssertEqual(type("caur", corrections: active, options: options, method: .telex), "của",
                               "Telex caur, expandPhrases=\(expandPhrases), restoreEnglish=\(restoreEnglish)")
            }
        }
    }

    func testRawSelfRulesOverrideCompositionWithoutChangingAlternativeTelexWords() {
        let rules = ["test": "test", "push": "push"]
        for restoreEnglish in [false, true] {
            let options = TypingOptions(restoreEnglishTelex: restoreEnglish)
            XCTAssertEqual(type("test", corrections: rules, options: options, method: .telex), "test",
                           "test self-rule must beat tét composition, restoreEnglish=\(restoreEnglish)")
            XCTAssertEqual(type("push", corrections: rules, options: options, method: .telex), "push",
                           "push self-rule must beat púh composition, restoreEnglish=\(restoreEnglish)")
            XCTAssertEqual(type("tets", corrections: rules, options: options, method: .telex), "tét",
                           "An alternative Telex spelling must retain its normal composition, restoreEnglish=\(restoreEnglish)")
        }
    }

    func testEscapeRestoresLiteralKeysAndUnicodeAliasesRemainCaseSensitive() throws {
        let session = TypingSession(corrections: ["cau3": "raw", "cảu": "của"], inputMethod: .vni)
        var visible = type("cau3", session: session)
        XCTAssertEqual(visible, "cảu")
        apply(try XCTUnwrap(session.restoreRaw()), to: &visible)
        XCTAssertEqual(visible, "cau3", "Escape restoration must preserve the literal key sequence")
        XCTAssertNil(session.restoreRaw(), "A restored token must remain literal for the rest of the token")
        apply(session.finish(boundary: " "), to: &visible)
        XCTAssertEqual(visible, "cau3")

        XCTAssertEqual(type("Cau3", corrections: ["cảu": "của"], method: .vni), "Cảu",
                       "A lower-case Unicode alias must not rewrite an upper-case composed word")
    }

    private func type(_ keys: String, corrections: [String: String],
                      options: TypingOptions = .init(), method: InputMethod) -> String {
        let session = TypingSession(corrections: corrections, inputMethod: method, options: options)
        var visible = type(keys, session: session)
        apply(session.finish(boundary: " "), to: &visible)
        return visible
    }

    private func type(_ keys: String, session: TypingSession) -> String {
        var visible = ""
        for key in keys { apply(session.process(key), to: &visible) }
        return visible
    }

    private func apply(_ edit: TextEdit, to visible: inout String) {
        XCTAssertLessThanOrEqual(edit.deleteCount, visible.count)
        visible.removeLast(min(edit.deleteCount, visible.count))
        visible.append(edit.insertText)
    }
}
