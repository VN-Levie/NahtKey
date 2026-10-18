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

    // A permissive set of vowel groups, not a word dictionary. Shapes matter:
    // uê occurs in Vietnamese, while the plain ue in user -> ủe does not.
    // This intentionally allows a few unfinished groups (ie, uo, uơ) so the
    // optional English guard does not become strict spelling correction.
    private static let nuclei: Set<String> = [
        "a", "ă", "â", "e", "ê", "i", "o", "ô", "ơ", "u", "ư", "y",
        "ai", "ao", "au", "ay", "âu", "ây", "eo", "êu", "ia", "ie", "iê", "iu",
        "oa", "oă", "oe", "oi", "oo", "ôi", "ơi",
        "ua", "uâ", "uê", "ui", "uo", "uô", "uơ", "uu", "uy",
        "ưa", "ưi", "ưu", "ươ", "ya", "ye", "yê",
        "iêu", "yêu", "oai", "oao", "oay", "oeo", "uai", "uao", "uay", "uây",
        "uoi", "uou", "uôi", "uơi", "uêu", "uya", "uyê", "uyu", "ươi", "ươu"
    ]
    private static let shapedVowels = Set("aăâeêioôơuưy")

    /// Completed lowercase text, with tones removed but vowel shapes retained.
    /// Only English restoration uses this stricter check; the live VNI guard
    /// remains permissive to allow late modifiers and partial syllables.
    static func acceptsCompleted(_ letters: [Character]) -> Bool {
        if letters == ["đ"] { return true }
        if letters.count == 2, letters[0] == "d" || letters[0] == "đ",
           dAbbreviationFinals.contains(letters[1]) { return true }
        for onset in onsets where letters.starts(with: onset) {
            var index = onset.count
            while index < letters.count, shapedVowels.contains(letters[index]) { index += 1 }
            guard nuclei.contains(String(letters[onset.count..<index])) else { continue }
            if codas.contains(Array(letters[index...])) { return true }
        }
        return false
    }

}
