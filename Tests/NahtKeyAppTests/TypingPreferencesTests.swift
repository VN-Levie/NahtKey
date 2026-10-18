import Foundation
import XCTest
import NahtKeyCore
@testable import NahtKeyApp

final class TypingPreferencesTests: XCTestCase {
    func testFreshAndUnreadableSettingsUseConservativeDefaultsAndRoundTrip() throws {
        let name = "NahtKey.tests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let original = KeyboardPreferences.load(from: defaults)
        XCTAssertTrue(original.typing.normalizeToneOnBackspace)
        XCTAssertFalse(original.typing.restoreEnglishTelex)
        XCTAssertFalse(original.restoreWithEscape)
        XCTAssertFalse(original.rememberPerApplication)
        XCTAssertFalse(original.expandPhrases)
        XCTAssertEqual(original.toggleShortcut, .controlShift)
        XCTAssertEqual(original.typing.tonePlacement, .traditional)
        var enabled = original
        enabled.typing.restoreEnglishTelex = true
        enabled.typing.tonePlacement = .modern
        enabled.restoreWithEscape = true
        enabled.rememberPerApplication = true
        enabled.expandPhrases = true
        enabled.toggleShortcut = .controlOption
        enabled.save(to: defaults)
        XCTAssertEqual(KeyboardPreferences.load(from: defaults), enabled)
        defaults.set(Data("invalid".utf8), forKey: KeyboardPreferences.storageKey)
        XCTAssertEqual(KeyboardPreferences.load(from: defaults), original)
    }

    @MainActor
    func testPhraseToggleAndPersonalCorrectionsAcrossBothMethodsAndBoundaries() {
        let rules = ["bt": "bình thường", "abn5": "bạn", "càu": "của"]
        for method in InputMethod.allCases {
            for enabled in [false, true] {
                for boundary: Character in [" ", ".", ",", "\t", "\n"] {
                    let session = TypingSession(corrections: DictionaryStore.activeCorrections(rules, expandPhrases: enabled), inputMethod: method)
                    var visible = ""
                    for key in "bt" { apply(session.process(key), to: &visible) }
                    apply(session.finish(boundary: boundary), to: &visible)
                    visible.append(boundary)
                    XCTAssertEqual(visible, (enabled ? "bình thường" : "bt") + String(boundary))
                    XCTAssertEqual(session.finish(boundary: " "), TextEdit(deleteCount: 0, insertText: ""))
                }
            }
        }
        let session = TypingSession(corrections: DictionaryStore.activeCorrections(rules, expandPhrases: false))
        var visible = ""
        for key in "abn5" { apply(session.process(key), to: &visible) }
        apply(session.finish(boundary: " "), to: &visible)
        XCTAssertEqual(visible, "bạn")
    }

    func testLocalReplacementRelocatesToneWithoutTouchingSurroundingText() throws {
        for (method, keys) in [(InputMethod.vni, "hoa2n"), (.telex, "hoafn")] {
            let engine = VNIEngine(inputMethod: method)
            var word = ""
            for key in keys { apply(engine.process(key), to: &word) }
            let text = "🙂 " + word + " đuôi"
            let edit = engine.backspace()
            let replacement = try XCTUnwrap(LocalFieldReplacement.make(edit: edit, in: text,
                selection: NSRange(location: ("🙂 " + word).utf16.count, length: 0)))
            var changed = text
            changed.replaceSubrange(try XCTUnwrap(Range(replacement.range, in: text)), with: replacement.text)
            XCTAssertEqual(changed, "🙂 hòa đuôi")
        }
    }

    @MainActor
    func testQuickAddOpensDictionaryAndPreservesAnUnfinishedEditor() {
        let navigation = MainWindowNavigation()
        navigation.selectedTab = .settings
        navigation.addWord()
        XCTAssertEqual(navigation.selectedTab, .dictionary)
        let firstID = navigation.editor?.id
        navigation.addWord()
        XCTAssertEqual(navigation.editor?.id, firstID)
        let existing = CorrectionEntry(raw: "test", replacement: "giữ")
        navigation.editor = CorrectionEditorTarget(entry: existing)
        navigation.addWord()
        XCTAssertEqual(navigation.editor?.entry, existing)
    }

    private func apply(_ edit: TextEdit, to text: inout String) {
        XCTAssertLessThanOrEqual(edit.deleteCount, text.count)
        text.removeLast(min(edit.deleteCount, text.count))
        text += edit.insertText
    }
}
