import AppKit
import SwiftUI
import NahtKeyCore

/// Translates engine grapheme counts into a native field editor's UTF-16 range.
/// It never removes text outside the current selection and its verified prefix.
struct LocalFieldReplacement: Equatable {
    let range: NSRange
    let text: String
    let selectionAfter: NSRange

    static func make(edit: TextEdit, in text: String, selection: NSRange) -> LocalFieldReplacement? {
        guard edit.deleteCount >= 0, let selected = characterRange(selection, in: text),
              text[..<selected.lowerBound].count >= edit.deleteCount else { return nil }
        let start = text.index(selected.lowerBound, offsetBy: -edit.deleteCount)
        let range = NSRange(start..<selected.upperBound, in: text)
        return LocalFieldReplacement(range: range, text: edit.insertText,
                                     selectionAfter: NSRange(location: range.location + edit.insertText.utf16.count, length: 0))
    }

    static func wordBeforeCaret(in text: String, selection: NSRange) -> String? {
        guard selection.length == 0, let selected = characterRange(selection, in: text) else { return nil }
        var start = selected.lowerBound
        var count = 0
        while start > text.startIndex {
            let previous = text.index(before: start)
            let character = text[previous]
            guard character.isLetter || character.isNumber || character == "_" else { break }
            count += 1
            guard count <= 128 else { return nil }
            start = previous
        }
        let word = text[start..<selected.lowerBound]
        guard !word.isEmpty, word.allSatisfy(\.isLetter) else { return nil }
        return String(word)
    }

    static func characterRange(_ range: NSRange, in text: String) -> Range<String.Index>? {
        guard let selected = Range(range, in: text),
              (selected.lowerBound == text.endIndex || text.indices.contains(selected.lowerBound)),
              (selected.upperBound == text.endIndex || text.indices.contains(selected.upperBound)) else { return nil }
        return selected
    }
}

/// Composes only this field, independently of global Accessibility permission.
/// Other controls retain their ordinary native input behavior.
struct VietnameseTextField: NSViewRepresentable {
    @Binding var text: String
    var inputMethod: InputMethod
    var typingOptions = TypingOptions()
    var restoreWithEscape = false
    var placeholder: String
    var accessibilityLabel = "Thay bằng"
    var accessibilityIdentifier = "correction-replacement"
    var onSubmit: () -> Void = {}

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    func makeNSView(context: Context) -> NSTextField {
        let field = NSTextField(string: text)
        field.placeholderString = placeholder
        field.isEditable = true
        field.isSelectable = true
        field.isBezeled = true
        field.bezelStyle = .roundedBezel
        field.font = .systemFont(ofSize: NSFont.systemFontSize)
        field.isAutomaticTextCompletionEnabled = false
        field.setContentHuggingPriority(.defaultLow, for: .horizontal)
        field.setAccessibilityLabel(accessibilityLabel)
        field.setAccessibilityIdentifier(accessibilityIdentifier)
        field.delegate = context.coordinator
        field.target = context.coordinator
        field.action = #selector(Coordinator.submit(_:))
        context.coordinator.attach(field)
        return field
    }

    func updateNSView(_ field: NSTextField, context: Context) {
        context.coordinator.parent = self
        context.coordinator.updateMethod(inputMethod)
        context.coordinator.updateOptions(typingOptions)
        field.placeholderString = placeholder
        field.setAccessibilityLabel(accessibilityLabel)
        field.setAccessibilityIdentifier(accessibilityIdentifier)
        context.coordinator.synchronizeText(in: field)
    }

    static func dismantleNSView(_ field: NSTextField, coordinator: Coordinator) {
        coordinator.detach()
        field.delegate = nil
        field.target = nil
    }

    @MainActor
    final class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: VietnameseTextField
        private let engine: VNIEngine
        private weak var field: NSTextField?
        private var monitor: Any?
        private var expectedText: String?
        private var expectedSelection: NSRange?
        private var applying = false
        private weak var configuredEditor: NSTextView?
        private var previousTextReplacement = false
        private var previousSpellingCorrection = false

        init(parent: VietnameseTextField) {
            self.parent = parent
            engine = VNIEngine(inputMethod: parent.inputMethod, options: parent.typingOptions)
            super.init()
        }

        func attach(_ field: NSTextField) {
            self.field = field
            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                let consumed = MainActor.assumeIsolated {
                    guard let self else { return false }
                    return self.handle(event) == nil
                }
                return consumed ? nil : event
            }
        }

        func detach() {
            if let monitor { NSEvent.removeMonitor(monitor) }
            monitor = nil
            restoreEditorOptions()
            field = nil
            reset()
        }

        func updateMethod(_ method: InputMethod) {
            guard engine.inputMethod != method else { return }
            engine.inputMethod = method
            reset()
        }

        func updateOptions(_ options: TypingOptions) {
            guard engine.options != options else { return }
            engine.options = options
            reset()
        }

        func synchronizeText(in field: NSTextField) {
            let editor = field.currentEditor() as? NSTextView
            let text = parent.text
            // The live field editor can be newer than NSTextField's value. A
            // redraw of our own keystroke must not erase the captured raw keys.
            guard (editor?.string ?? field.stringValue) != text else { return }
            reset()
            let selection = editor?.selectedRange()
            field.stringValue = text
            if let editor {
                editor.string = text
                if let selection, LocalFieldReplacement.characterRange(selection, in: text) != nil {
                    editor.setSelectedRange(selection)
                } else {
                    editor.setSelectedRange(NSRange(location: text.utf16.count, length: 0))
                }
            }
        }

        func reset() {
            engine.reset()
            expectedText = nil
            expectedSelection = nil
        }

        @objc func submit(_ sender: NSTextField) {
            // NSTextField also sends its action when Tab/click ends editing.
            // Only Return/Enter should submit the containing form.
            guard let event = NSApp.currentEvent, event.type == .keyDown,
                  event.keyCode == 36 || event.keyCode == 76 else { return }
            parent.onSubmit()
        }

        func controlTextDidBeginEditing(_ notification: Notification) {
            // AppKit may begin editing lazily inside our first insertText call.
            // That first captured key already belongs to this editing session.
            if !applying { reset() }
            guard let editor = field?.currentEditor() as? NSTextView else { return }
            restoreEditorOptions()
            configuredEditor = editor
            previousTextReplacement = editor.isAutomaticTextReplacementEnabled
            previousSpellingCorrection = editor.isAutomaticSpellingCorrectionEnabled
            editor.isAutomaticTextReplacementEnabled = false
            editor.isAutomaticSpellingCorrectionEnabled = false
        }

        func controlTextDidEndEditing(_ notification: Notification) {
            if let field, parent.text != field.stringValue { parent.text = field.stringValue }
            restoreEditorOptions()
            reset()
        }

        func controlTextDidChange(_ notification: Notification) {
            guard let field else { return }
            let value = (field.currentEditor() as? NSTextView)?.string ?? field.stringValue
            if !applying && value != expectedText { reset() }
            if parent.text != value { parent.text = value }
        }

        private func restoreEditorOptions() {
            configuredEditor?.isAutomaticTextReplacementEnabled = previousTextReplacement
            configuredEditor?.isAutomaticSpellingCorrectionEnabled = previousSpellingCorrection
            configuredEditor = nil
        }

        func handle(_ event: NSEvent) -> NSEvent? {
            guard let field, let editor = field.currentEditor() as? NSTextView,
                  field.window === event.window, field.window?.firstResponder === editor else { return event }
            guard !editor.hasMarkedText(), event.modifierFlags.intersection([.command, .control, .option]).isEmpty else {
                reset()
                return event
            }
            let selection = editor.selectedRange()
            if editor.string != expectedText || selection != expectedSelection {
                reset()
                if let word = LocalFieldReplacement.wordBeforeCaret(in: editor.string, selection: selection) {
                    engine.resume(word)
                }
            }
            if event.keyCode == 53 {
                guard parent.restoreWithEscape, let edit = engine.restoreRaw(), apply(edit, in: editor) else {
                    reset()
                    return event
                }
                return nil
            }
            if event.keyCode == 51 {
                guard selection.length == 0, !engine.rendered.isEmpty else { reset(); return event }
                return apply(engine.backspace(), in: editor) ? nil : event
            }
            if [36, 48, 76].contains(event.keyCode) {
                let edit = engine.finish()
                if edit.deleteCount > 0 || !edit.insertText.isEmpty { _ = apply(edit, in: editor) }
                reset()
                return event // Return submits; Tab only moves focus.
            }
            guard let characters = event.characters, characters.count == 1, let character = characters.first,
                  let ascii = character.asciiValue else { reset(); return event }
            let edit: TextEdit
            if (65...90).contains(ascii) || (97...122).contains(ascii) || (48...57).contains(ascii) {
                edit = engine.process(character)
            } else if ascii >= 32 && ascii < 127 {
                let commit = engine.finish()
                edit = TextEdit(deleteCount: commit.deleteCount, insertText: commit.insertText + String(character))
            } else {
                reset()
                return event
            }
            return apply(edit, in: editor) ? nil : event
        }

        @discardableResult
        private func apply(_ edit: TextEdit, in editor: NSTextView) -> Bool {
            let selection = editor.selectedRange()
            guard let replacement = LocalFieldReplacement.make(edit: edit, in: editor.string, selection: selection) else {
                reset()
                return false
            }
            applying = true
            editor.insertText(replacement.text, replacementRange: replacement.range)
            editor.setSelectedRange(replacement.selectionAfter)
            applying = false
            expectedText = editor.string
            expectedSelection = editor.selectedRange()
            if parent.text != editor.string { parent.text = editor.string }
            return true
        }
    }
}
