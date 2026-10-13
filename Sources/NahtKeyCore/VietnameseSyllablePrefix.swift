/// A deliberately permissive structural guard, not a word dictionary. It checks
/// that a normalized prefix can still have one onset, one contiguous vowel group,
/// and one Vietnamese final consonant. Shape/tone and spelling rules are left to
/// the composer so early modifiers and incomplete nuclei such as ie/uo still work.
enum VietnameseSyllablePrefix {
    private static let onsets = [
        "", "b", "c", "ch", "d", "đ", "g", "gh", "gi", "h", "k", "kh", "l", "m",
        "n", "ng", "ngh", "nh", "p", "ph", "q", "qu", "r", "s", "t", "th", "tr", "v", "x"
    ].map(Array.init)
    private static let codas = ["", "c", "ch", "m", "n", "ng", "nh", "p", "t"].map(Array.init)
    private static let vowels: Set<Character> = ["a", "e", "i", "o", "u", "y"]
    // Common two-letter d/đ abbreviations, e.g. đc (được), đt (điện thoại),
    // đk (đăng ký), đg (đường), đh (đại học), đv (đơn vị), đb, đs. This exact
    // pair allowance supports late 9 without accepting arbitrary code tokens.
    private static let dAbbreviationFinals: Set<Character> = ["c", "t", "k", "g", "h", "v", "b", "s"]

    /// Input is lowercase with Vietnamese vowel tones/shapes removed; đ remains.
    static func accepts(_ letters: [Character]) -> Bool {
        if letters.isEmpty { return true }
        guard letters.allSatisfy({ ($0 >= "a" && $0 <= "z") || $0 == "đ" }) else { return false }
        if letters.count == 2, letters[0] == "d" || letters[0] == "đ",
           dAbbreviationFinals.contains(letters[1]) { return true }

        for onset in onsets {
            // Consonant-only beginnings may still grow: n -> ng -> ngh -> nghi.
            if onset.starts(with: letters) { return true }
            guard letters.starts(with: onset) else { continue }
            var index = onset.count
            let vowelStart = index
            while index < letters.count, vowels.contains(letters[index]) { index += 1 }
            let vowelCount = index - vowelStart
            // Three vowels cover a Vietnamese nucleus. Alternate qu/gi parses
            // remove the initial u/i, so quyeu and similar prefixes remain valid.
            guard (1...3).contains(vowelCount) else { continue }
            let final = letters[index...]
            if codas.contains(where: { $0.starts(with: final) }) { return true }
        }
        return false
    }
}
