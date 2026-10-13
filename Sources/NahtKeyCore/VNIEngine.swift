import Foundation

public enum InputMethod: String, CaseIterable, Codable, Identifiable {
    case vni, telex

    public var id: String { rawValue }
    public var displayName: String { self == .vni ? "VNI" : "Telex" }
}

/// An edit against the end of the currently displayed token. Counts are graphemes,
/// not UTF-8 bytes, UTF-16 code units, or physical keystrokes.
public struct TextEdit: Equatable {
    public let deleteCount: Int
    public let insertText: String

    public init(deleteCount: Int, insertText: String) {
        self.deleteCount = deleteCount
        self.insertText = insertText
    }
}

/// A platform-independent VNI and Telex composer. The host owns word boundaries,
/// cursor changes, and applying edits. Personal rules match the exact input keys.
public final class VNIEngine {
    public var corrections: [String: String]
    public var inputMethod: InputMethod {
        didSet {
            if inputMethod != oldValue { reset() }
        }
    }
    public private(set) var raw = ""
    public private(set) var rendered = ""

    private let maximumTokenLength = 128
    private var mayCorrectRaw = true
    private var passesThroughLongToken = false
    private var characters: [Character] = []
    private var previousKey: Character?
    private var capturedKeyCount = 0

    public init(corrections: [String: String] = [:], inputMethod: InputMethod = .vni) {
        self.corrections = corrections
        self.inputMethod = inputMethod
    }

    public func process(_ character: Character) -> TextEdit {
        // Once a token exceeds the limit, leave it literal until its next boundary.
        // Forgetting the whole token also prevents suffixes from matching a rule.
        guard !passesThroughLongToken, capturedKeyCount < maximumTokenLength else {
            raw = ""
            rendered = ""
            characters.removeAll(keepingCapacity: true)
            previousKey = nil
            mayCorrectRaw = false
            passesThroughLongToken = true
            return TextEdit(deleteCount: 0, insertText: String(character))
        }
        let previous = rendered
        raw.append(character)
        capturedKeyCount += 1
        // Apply just the new key. Replaying every raw key here was quadratic and
        // needlessly repeated tone scans inside the system's keyboard callback.
        Self.compose(character, previousKey: previousKey, method: inputMethod, into: &characters)
        previousKey = character
        rendered = String(characters)
        return Self.edit(from: previous, to: rendered)
    }

    /// Commit a token, applying an exact raw-key correction if one exists.
    /// The delimiter itself is intentionally absent from the returned edit.
    public func finish() -> TextEdit {
        let result: TextEdit
        if mayCorrectRaw, !passesThroughLongToken, !raw.isEmpty,
           let replacement = corrections[raw] {
            result = Self.edit(from: rendered, to: replacement)
        } else {
            result = TextEdit(deleteCount: 0, insertText: "")
        }
        reset()
        return result
    }

    /// Delete one visible grapheme, rather than undoing a hidden typing modifier.
    /// Resume composition from the remaining visible text. Since the original key
    /// sequence is no longer knowable, personal correction waits for a new token.
    public func backspace() -> TextEdit {
        mayCorrectRaw = false
        guard !rendered.isEmpty else {
            return TextEdit(deleteCount: 1, insertText: "")
        }
        rendered.removeLast()
        characters.removeLast()
        raw = rendered
        capturedKeyCount = characters.count
        previousKey = nil
        return TextEdit(deleteCount: 1, insertText: "")
    }

    /// Resume a known visible word after a delimiter was removed or the host
    /// verified the caret position. Unknown source keystrokes must never qualify
    /// for an exact raw alias. Reject partial, non-word, and overlong input.
    public func resume(_ visibleWord: String) {
        reset()
        mayCorrectRaw = false
        guard !visibleWord.isEmpty, visibleWord.count <= maximumTokenLength,
              visibleWord.allSatisfy(\.isLetter) else { return }
        let normalized = visibleWord.precomposedStringWithCanonicalMapping
        raw = normalized
        rendered = normalized
        characters = Array(normalized)
        capturedKeyCount = characters.count
    }

    public func reset() {
        raw = ""
        rendered = ""
        mayCorrectRaw = true
        passesThroughLongToken = false
        characters.removeAll(keepingCapacity: true)
        previousKey = nil
        capturedKeyCount = 0
    }

    private static func edit(from old: String, to new: String) -> TextEdit {
        let a = Array(old)
        let b = Array(new)
        var common = 0
        while common < min(a.count, b.count), a[common] == b[common] {
            common += 1
        }
        return TextEdit(deleteCount: a.count - common, insertText: String(b.dropFirst(common)))
    }

    private enum Shape: Hashable {
        case plain, circumflex, horn, breve
    }

    private struct Vowel: Hashable {
        let base: Character
        var shape: Shape
        var tone: Int
        let uppercase: Bool

        var character: Character {
            vowelCharacters[self]!
        }
    }

    // Each row is unmarked, acute, grave, hook, tilde, dot below (VNI 1...5).
    private static let vowelRows: [(base: Character, shape: Shape, letters: String)] = [
        ("a", .plain, "aáàảãạ"), ("a", .circumflex, "âấầẩẫậ"), ("a", .breve, "ăắằẳẵặ"),
        ("e", .plain, "eéèẻẽẹ"), ("e", .circumflex, "êếềểễệ"),
        ("i", .plain, "iíìỉĩị"),
        ("o", .plain, "oóòỏõọ"), ("o", .circumflex, "ôốồổỗộ"), ("o", .horn, "ơớờởỡợ"),
        ("u", .plain, "uúùủũụ"), ("u", .horn, "ưứừửữự"),
        ("y", .plain, "yýỳỷỹỵ")
    ]

    private static let vowels: [Character: Vowel] = {
        var result: [Character: Vowel] = [:]
        for row in vowelRows {
            for (tone, letter) in row.letters.enumerated() {
                result[letter] = Vowel(base: row.base, shape: row.shape, tone: tone, uppercase: false)
                result[Character(String(letter).uppercased())] = Vowel(base: row.base, shape: row.shape, tone: tone, uppercase: true)
            }
        }
        return result
    }()

    private static let vowelCharacters = Dictionary(uniqueKeysWithValues: vowels.map { ($0.value, $0.key) })

    private static func compose(_ key: Character, previousKey: Character?, method: InputMethod, into text: inout [Character]) {
        switch method {
        case .vni:
            if let digit = key.wholeNumberValue, key.isASCII,
               apply(digit: digit, previousKey: previousKey, to: &text) { return }
        case .telex:
            if applyTelex(key, previousKey: previousKey, to: &text) { return }
        }
        text.append(key)
        if key.isLetter {
            harmonizeHorns(in: &text)
            relocateTone(in: &text)
        }
    }

    /// Only the current letter suffix may participate in a VNI operation. Literal
    /// digits/punctuation cannot accidentally modify text on their other side.
    private static func letterRange(in text: [Character]) -> Range<Int> {
        var start = text.count
        while start > 0, text[start - 1].isLetter { start -= 1 }
        return start..<text.count
    }

    private static func apply(digit: Int, previousKey: Character?, to text: inout [Character]) -> Bool {
        let range = letterRange(in: text)
        guard !range.isEmpty else { return false }
        let repeatsKey = previousKey == Character(String(digit))
        if (1...5).contains(digit) {
            return applyTone(digit, escapeKey: Character(String(digit)), repeatsKey: repeatsKey, to: &text)
        }

        if digit == 9 {
            return applyDStroke(escapeKey: "9", repeatsKey: repeatsKey, to: &text)
        }

        if digit == 0 {
            return clearDiacritics(in: &text)
        }

        let desired: Shape
        let eligible: Set<Character>
        switch digit {
        case 6: desired = .circumflex; eligible = ["a", "e", "o"]
        case 7: desired = .horn; eligible = ["o", "u"]
        case 8: desired = .breve; eligible = ["a"]
        default: return false
        }
        guard var target = range.reversed().first(where: {
            vowels[text[$0]].map { eligible.contains($0.base) } ?? false
        }) else { return false }
        if digit == 7 { target = hornTarget(target, in: text, range: range) }
        return applyShape(desired, target: target, escapeKey: Character(String(digit)), repeatsKey: repeatsKey, to: &text)
    }

    private static func applyTelex(_ key: Character, previousKey: Character?, to text: inout [Character]) -> Bool {
        guard key.isASCII else { return false }
        let lower = Character(String(key).lowercased())
        let repeatsKey = previousKey.map { String($0).lowercased() == String(lower) } ?? false
        let tones: [Character: Int] = ["s": 1, "f": 2, "r": 3, "x": 4, "j": 5]
        if let tone = tones[lower] {
            return applyTone(tone, escapeKey: key, repeatsKey: repeatsKey, to: &text)
        }
        if lower == "z" { return clearDiacritics(in: &text) }
        if lower == "d" { return applyDStroke(escapeKey: key, repeatsKey: repeatsKey, to: &text) }

        let range = letterRange(in: text)
        guard !range.isEmpty else { return false }
        if lower == "a" || lower == "e" || lower == "o" {
            guard let target = range.reversed().first(where: { vowels[text[$0]]?.base == lower }) else { return false }
            return applyShape(.circumflex, target: target, escapeKey: key, repeatsKey: repeatsKey, to: &text)
        }
        if lower == "w" {
            guard var target = range.reversed().first(where: {
                guard let vowel = vowels[text[$0]] else { return false }
                return vowel.base == "a" || vowel.base == "o" || vowel.base == "u"
            }) else { return false }
            // uaw and uuw apply the horn to the first u: ưa and ưu. The u in
            // qu is an initial, so quaw keeps the expected breve on a instead.
            target = hornTarget(target, in: text, range: range)
            let desired: Shape = vowels[text[target]]!.base == "a" ? .breve : .horn
            return applyShape(desired, target: target, escapeKey: key, repeatsKey: repeatsKey, to: &text)
        }
        return false
    }

    private static func applyTone(_ tone: Int, escapeKey: Character, repeatsKey: Bool, to text: inout [Character]) -> Bool {
        let range = letterRange(in: text)
        guard let target = toneTarget(in: text, range: range) else { return false }
        let oldTone = range.compactMap { vowels[text[$0]]?.tone }.first { $0 != 0 } ?? 0
        clearTones(in: &text, range: range)
        if oldTone == tone && repeatsKey {
            text.append(escapeKey)
        } else {
            var vowel = vowels[text[target]]!
            vowel.tone = tone
            text[target] = vowel.character
        }
        return true
    }

    private static func applyDStroke(escapeKey: Character, repeatsKey: Bool, to text: inout [Character]) -> Bool {
        let range = letterRange(in: text)
        guard let target = range.reversed().first(where: { "dDđĐ".contains(text[$0]) }) else { return false }
        switch text[target] {
        case "d": text[target] = "đ"
        case "D": text[target] = "Đ"
        case "đ": if repeatsKey { text[target] = "d"; text.append(escapeKey) }
        default: if repeatsKey { text[target] = "D"; text.append(escapeKey) }
        }
        return true
    }

    private static func clearDiacritics(in text: inout [Character]) -> Bool {
        var changed = false
        for index in letterRange(in: text) {
            if var vowel = vowels[text[index]], vowel.shape != .plain || vowel.tone != 0 {
                vowel.shape = .plain
                vowel.tone = 0
                text[index] = vowel.character
                changed = true
            } else if text[index] == "đ" || text[index] == "Đ" {
                text[index] = text[index] == "đ" ? "d" : "D"
                changed = true
            }
        }
        return changed
    }

    private static func hornTarget(_ target: Int, in text: [Character], range: Range<Int>) -> Int {
        // In uou, the final u is a glide: the main uo pair receives both horns.
        // The analogous uoi group already selects o because i is not eligible.
        if target >= range.lowerBound + 2,
           vowels[text[target]]?.base == "u",
           vowels[text[target - 1]]?.base == "o",
           vowels[text[target - 2]]?.base == "u" {
            return target - 1
        }
        guard target > range.lowerBound,
              let current = vowels[text[target]], current.base == "u" || current.base == "a",
              let preceding = vowels[text[target - 1]], preceding.base == "u",
              !(target >= range.lowerBound + 2 && String(text[target - 2]).lowercased() == "q") else { return target }
        return target - 1
    }

    private static func applyShape(_ desired: Shape, target: Int, escapeKey: Character, repeatsKey: Bool, to text: inout [Character]) -> Bool {
        let range = letterRange(in: text)
        var vowel = vowels[text[target]]!
        let escaping = vowel.shape == desired && repeatsKey
        vowel.shape = escaping ? .plain : desired
        text[target] = vowel.character

        // The uo pair is one vowel group: uo7 -> ươ, also after a final consonant.
        if desired == .horn, vowel.base == "o", target > range.lowerBound,
           var preceding = vowels[text[target - 1]], preceding.base == "u",
           !(target >= range.lowerBound + 2 && String(text[target - 2]).lowercased() == "q") {
            preceding.shape = escaping ? .plain : .horn
            text[target - 1] = preceding.character
        }
        if escaping {
            text.append(escapeKey)
        } else {
            relocateTone(in: &text)
        }
        return true
    }

    private static func harmonizeHorns(in text: inout [Character]) {
        let range = letterRange(in: text)
        guard range.count > 1 else { return }
        for index in (range.lowerBound + 1)..<range.upperBound {
            guard let previous = vowels[text[index - 1]], previous.base == "u", previous.shape == .horn,
                  var current = vowels[text[index]], current.base == "o", current.shape == .plain else { continue }
            current.shape = .horn
            text[index] = current.character
        }
    }

    private static func clearTones(in text: inout [Character], range: Range<Int>) {
        for index in range {
            guard var vowel = vowels[text[index]], vowel.tone != 0 else { continue }
            vowel.tone = 0
            text[index] = vowel.character
        }
    }

    private static func relocateTone(in text: inout [Character]) {
        let range = letterRange(in: text)
        guard let tone = range.compactMap({ vowels[text[$0]]?.tone }).last(where: { $0 != 0 }),
              let target = toneTarget(in: text, range: range) else { return }
        clearTones(in: &text, range: range)
        var vowel = vowels[text[target]]!
        vowel.tone = tone
        text[target] = vowel.character
    }

    private static func toneTarget(in text: [Character], range: Range<Int>) -> Int? {
        var indices = range.filter { vowels[text[$0]] != nil }
        // In qu/gi, u/i belongs to the initial when another vowel follows it.
        if indices.count > 1, let first = indices.first, first > range.lowerBound {
            let preceding = String(text[first - 1]).lowercased()
            let base = vowels[text[first]]!.base
            if (preceding == "q" && base == "u") || (preceding == "g" && base == "i") {
                indices.removeFirst()
            }
        }
        guard let last = indices.last else { return nil }
        // A shaped main vowel takes precedence, especially iê, uô, ươ and uâ.
        if let shaped = indices.last(where: { vowels[text[$0]]!.shape != .plain }) {
            return shaped
        }
        if indices.count == 1 { return last }
        if last < range.upperBound - 1 { return last }
        return indices[indices.count - 2]
    }
}
