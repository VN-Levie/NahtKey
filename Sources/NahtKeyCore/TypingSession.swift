import Foundation

/// Composition plus a bounded suffix of text this session actually displayed.
/// The host must reset on untracked selection/caret changes, and may resume only
/// after verifying a complete visible word immediately to the left of the caret.
public final class TypingSession {
    private let engine: VNIEngine
    private let maximumContextLength = 256
    private let maximumWordLength = 128
    private var recent: [Character] = []
    // Trimming may cut through a word. Never mistake that partial prefix for a
    // complete word when backspacing all the way to the oldest retained text.
    private var leadingWordIsComplete = true

    public init(corrections: [String: String] = [:], inputMethod: InputMethod = .vni) {
        engine = VNIEngine(corrections: corrections, inputMethod: inputMethod)
    }

    public var corrections: [String: String] {
        get { engine.corrections }
        set { engine.corrections = newValue }
    }

    public var inputMethod: InputMethod {
        get { engine.inputMethod }
        set {
            guard newValue != engine.inputMethod else { return }
            reset()
            engine.inputMethod = newValue
        }
    }

    public var raw: String { engine.raw }
    public var rendered: String { engine.rendered }

    public func process(_ character: Character) -> TextEdit {
        let edit = engine.process(character)
        remember(edit)
        return edit
    }

    /// The host inserts the boundary itself after applying this returned edit.
    /// Remember its actual value, including repeated spaces and line breaks.
    public func finish(boundary: Character) -> TextEdit {
        let edit = engine.finish()
        remember(edit)
        recent.append(boundary)
        trimContext()
        return edit
    }

    public func backspace() -> TextEdit {
        let edit = engine.backspace()
        remember(edit)
        if engine.rendered.isEmpty { restoreTrailingWord() }
        return edit
    }

    public func reset() {
        engine.reset()
        recent.removeAll(keepingCapacity: true)
        leadingWordIsComplete = true
    }

    /// Replace local context with a word independently verified by the host. No
    /// assumptions about the text preceding that word survive this operation.
    public func resume(_ visibleWord: String) {
        reset()
        engine.resume(visibleWord)
        recent = Array(engine.rendered)
    }

    private func remember(_ edit: TextEdit) {
        if edit.deleteCount > recent.count {
            // Deletion passed the oldest known character. Text beyond that point
            // is unknown, so future composition must rely only on new input.
            recent.removeAll(keepingCapacity: true)
            leadingWordIsComplete = true
        } else if edit.deleteCount > 0 {
            recent.removeLast(edit.deleteCount)
        }
        recent.append(contentsOf: edit.insertText)
        trimContext()
    }

    private func trimContext() {
        let excess = recent.count - maximumContextLength
        guard excess > 0 else { return }
        let removedLast = recent[excess - 1]
        let keptFirst = recent[excess]
        leadingWordIsComplete = !Self.isTokenCharacter(removedLast) || !Self.isTokenCharacter(keptFirst)
        recent.removeFirst(excess)
    }

    private func restoreTrailingWord() {
        guard recent.last?.isLetter == true else { return }
        var start = recent.count
        while start > 0, Self.isTokenCharacter(recent[start - 1]) {
            start -= 1
            if recent.count - start > maximumWordLength { return }
        }
        guard start > 0 || leadingWordIsComplete else { return }
        guard recent[start...].allSatisfy(\.isLetter) else { return }
        engine.resume(String(recent[start...]))
    }

    private static func isTokenCharacter(_ character: Character) -> Bool {
        character.isLetter || character.isNumber || character == "_"
    }
}
