import ApplicationServices
import Foundation

/// The small, metadata-only context needed to recognize Safari's address field.
///
/// This intentionally does not read AXValue or text.  It is used to decide
/// whether an address-bar operation may be attempted at the end of the field.
struct SafariAddressBarContext {
    // Safari can service AX after a suggestion update takes more than 20 ms.
    // This is a response deadline, not a delay added to each keystroke.
    static let messagingTimeout: Float = 0.1
    static let safariBundleIdentifier = "com.apple.Safari"
    static let addressFieldIdentifier = "WEB_BROWSER_ADDRESS_AND_SEARCH_FIELD"

    let selection: CFRange
    let characterCount: Int

    /// True when the caret is at the end or the selected range is a suffix.
    var isAtTail: Bool {
        selection.location + selection.length == characterCount
    }

    func permitsCompletionClearing(verifiedInlineCompletion: Bool) -> Bool {
        isAtTail && (selection.length == 0 || verifiedInlineCompletion)
    }

    static func identifies(element: AXUIElement, bundleID: String) -> Bool {
        guard bundleID == safariBundleIdentifier else { return false }
        AXUIElementSetMessagingTimeout(element, messagingTimeout)
        return (attribute("AXIdentifier", of: element) as? String) == addressFieldIdentifier
            && (attribute(kAXRoleAttribute, of: element) as? String) == kAXTextFieldRole as String
            && (attribute(kAXSubroleAttribute, of: element) as? String) != kAXSecureTextFieldSubrole as String
            && (attribute("AXProtectedContent", of: element) as? Bool) != true
    }

    /// Pure metadata classifier, kept separate from AX calls for regression tests.
    static func classify(
        bundleID: String,
        role: String,
        subrole: String,
        identifier: String,
        protectedContent: Bool,
        selection: CFRange,
        characterCount: Int
    ) -> SafariAddressBarContext? {
        guard bundleID == safariBundleIdentifier,
              role == (kAXTextFieldRole as String),
              identifier == addressFieldIdentifier,
              subrole != (kAXSecureTextFieldSubrole as String),
              !protectedContent,
              (0...4096).contains(characterCount),
              selection.location >= 0,
              selection.length >= 0,
              selection.location <= characterCount,
              selection.length <= characterCount - selection.location else { return nil }
        return SafariAddressBarContext(selection: selection, characterCount: characterCount)
    }

    /// Reads only bounded accessibility metadata and never reads or mutates text.
    static func read(element: AXUIElement, bundleID: String) -> SafariAddressBarContext? {
        guard identifies(element: element, bundleID: bundleID) else { return nil }
        return readSelection(inVerifiedAddressField: element)
    }

    /// The controller invalidates identity on every focus change or failed read.
    /// Dynamic metadata is queried only for edits, not every physical letter.
    static func readSelection(inVerifiedAddressField element: AXUIElement) -> SafariAddressBarContext? {
        AXUIElementSetMessagingTimeout(element, messagingTimeout)
        guard let selectionValue = attribute(kAXSelectedTextRangeAttribute, of: element),
              CFGetTypeID(selectionValue) == AXValueGetTypeID(),
              let characterNumber = attribute(kAXNumberOfCharactersAttribute, of: element) as? NSNumber else {
            return nil
        }

        var selection = CFRange()
        guard AXValueGetValue(selectionValue as! AXValue, .cfRange, &selection) else { return nil }
        return classify(
            bundleID: safariBundleIdentifier,
            role: kAXTextFieldRole as String,
            subrole: "",
            identifier: addressFieldIdentifier,
            protectedContent: false,
            selection: selection,
            characterCount: characterNumber.intValue
        )
    }

    private static func attribute(_ name: String, of element: AXUIElement) -> CFTypeRef? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else { return nil }
        return value
    }
}
