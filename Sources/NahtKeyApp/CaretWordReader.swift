import ApplicationServices
import Foundation

/// Read only the word immediately before a collapsed caret, on an explicit
/// reconversion key. Nothing is persisted or logged. Secure controls are excluded.
enum CaretWordReader {
    static func word(beforeCaretIn element: AXUIElement) -> String? {
        AXUIElementSetMessagingTimeout(element, 0.02)
        let subrole = attribute(kAXSubroleAttribute, of: element) as? String
        guard subrole != (kAXSecureTextFieldSubrole as String),
              (attribute("AXProtectedContent", of: element) as? Bool) != true,
              let selectionValue = attribute(kAXSelectedTextRangeAttribute, of: element),
              CFGetTypeID(selectionValue) == AXValueGetTypeID() else { return nil }
        let selectionAX = selectionValue as! AXValue
        var selection = CFRange()
        guard AXValueGetValue(selectionAX, .cfRange, &selection),
              selection.location > 0, selection.length == 0 else { return nil }

        let count = (attribute(kAXNumberOfCharactersAttribute, of: element) as? NSNumber)?.intValue
        let start = max(0, selection.location - 256)
        if let left = text(in: CFRange(location: start, length: selection.location - start), of: element) {
            let right: String
            if count == selection.location { right = "" }
            else if let character = text(in: CFRange(location: selection.location, length: 1), of: element) { right = character }
            else { return nil } // Do not guess if the caret is inside a word.
            return trailingWord(left: left, right: right, beginsAtDocumentStart: start == 0)
        }

        // Some native single-line controls expose AXValue but not StringForRange.
        // Only read these when their advertised size is small and bounded.
        guard let count, count <= 4096, selection.location <= count,
              let value = attribute(kAXValueAttribute, of: element) as? String,
              value.utf16.count == count else { return nil }
        return word(in: value, selection: selection)
    }

    static func word(in value: String, selection: CFRange) -> String? {
        let text = value as NSString
        guard selection.length == 0, selection.location > 0, selection.location <= text.length else { return nil }
        let start = max(0, selection.location - 256)
        let left = text.substring(with: NSRange(location: start, length: selection.location - start))
        let right = selection.location < text.length ? text.substring(with: NSRange(location: selection.location, length: 1)) : ""
        return trailingWord(left: left, right: right, beginsAtDocumentStart: start == 0)
    }

    private static func trailingWord(left: String, right: String, beginsAtDocumentStart: Bool) -> String? {
        if let next = right.first, next.isLetter || next.isNumber || next == "_" { return nil }
        let suffix = String(left.reversed().prefix(while: \.isLetter).reversed())
        guard !suffix.isEmpty, suffix.count <= 128,
              beginsAtDocumentStart || suffix.count < left.count else { return nil }
        if let preceding = left.dropLast(suffix.count).last,
           preceding.isNumber || preceding == "_" { return nil }
        return suffix.precomposedStringWithCanonicalMapping
    }

    private static func attribute(_ name: String, of element: AXUIElement) -> CFTypeRef? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else { return nil }
        return value
    }

    private static func text(in range: CFRange, of element: AXUIElement) -> String? {
        var range = range
        guard let parameter = AXValueCreate(.cfRange, &range) else { return nil }
        var value: CFTypeRef?
        guard AXUIElementCopyParameterizedAttributeValue(element, kAXStringForRangeParameterizedAttribute as CFString,
                                                        parameter, &value) == .success else { return nil }
        return value as? String
    }
}
