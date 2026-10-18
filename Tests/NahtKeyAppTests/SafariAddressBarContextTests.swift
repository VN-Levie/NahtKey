import ApplicationServices
import XCTest
@testable import NahtKeyApp

final class SafariAddressBarContextTests: XCTestCase {
    private let role = kAXTextFieldRole as String
    private let subrole = "AXTextField"
    private let identifier = SafariAddressBarContext.addressFieldIdentifier

    private func context(
        bundleID: String = SafariAddressBarContext.safariBundleIdentifier,
        role: String? = nil,
        subrole: String? = nil,
        identifier: String? = nil,
        protectedContent: Bool = false,
        selection: CFRange,
        characterCount: Int = 10
    ) -> SafariAddressBarContext? {
        SafariAddressBarContext.classify(
            bundleID: bundleID,
            role: role ?? self.role,
            subrole: subrole ?? self.subrole,
            identifier: identifier ?? self.identifier,
            protectedContent: protectedContent,
            selection: selection,
            characterCount: characterCount
        )
    }

    func testCollapsedCaretAtTail() {
        let value = context(selection: CFRange(location: 10, length: 0))
        XCTAssertNotNil(value)
        XCTAssertTrue(value?.isAtTail == true)
    }

    func testSelectedSuffixIsAtTail() {
        let value = context(selection: CFRange(location: 7, length: 3))
        XCTAssertTrue(value?.isAtTail == true)
    }

    func testInteriorCaretAndSelectionAreNotAtTail() {
        XCTAssertFalse(context(selection: CFRange(location: 4, length: 0))?.isAtTail == true)
        XCTAssertFalse(context(selection: CFRange(location: 2, length: 3))?.isAtTail == true)
    }

    func testSelectAllIsAtTail() {
        XCTAssertTrue(context(selection: CFRange(location: 0, length: 10))?.isAtTail == true)
    }

    func testOnlyCollapsedTailOrVerifiedCompletionMayBeCleared() {
        let caret = context(selection: CFRange(location: 10, length: 0))!
        XCTAssertTrue(caret.permitsCompletionClearing(verifiedInlineCompletion: false))
        let suffix = context(selection: CFRange(location: 3, length: 7))!
        XCTAssertFalse(suffix.permitsCompletionClearing(verifiedInlineCompletion: false))
        XCTAssertTrue(suffix.permitsCompletionClearing(verifiedInlineCompletion: true))
        let all = context(selection: CFRange(location: 0, length: 10))!
        XCTAssertFalse(all.permitsCompletionClearing(verifiedInlineCompletion: false))
        let middle = context(selection: CFRange(location: 3, length: 0))!
        XCTAssertFalse(middle.permitsCompletionClearing(verifiedInlineCompletion: true))
    }

    func testOnlySafariTextFieldAddressIdentifierIsAccepted() {
        XCTAssertNil(context(bundleID: "com.google.Chrome", selection: CFRange(location: 10, length: 0)))
        XCTAssertNil(context(role: kAXComboBoxRole as String, selection: CFRange(location: 10, length: 0)))
        XCTAssertNil(context(identifier: "other", selection: CFRange(location: 10, length: 0)))
    }

    func testProtectedFieldsAreRejected() {
        XCTAssertNil(context(subrole: kAXSecureTextFieldSubrole as String, selection: CFRange(location: 10, length: 0)))
        XCTAssertNil(context(protectedContent: true, selection: CFRange(location: 10, length: 0)))
    }

    func testMalformedAndOutOfBoundsRangesAreRejected() {
        XCTAssertNil(context(selection: CFRange(location: -1, length: 0)))
        XCTAssertNil(context(selection: CFRange(location: 0, length: -1)))
        XCTAssertNil(context(selection: CFRange(location: 11, length: 0)))
        XCTAssertNil(context(selection: CFRange(location: 9, length: 2)))
        XCTAssertNil(context(selection: CFRange(location: Int.max, length: 1)))
    }

    func testCharacterCountIsBounded() {
        XCTAssertNil(context(selection: CFRange(location: 0, length: 0), characterCount: -1))
        XCTAssertNil(context(selection: CFRange(location: 0, length: 0), characterCount: 4097))
    }
}
