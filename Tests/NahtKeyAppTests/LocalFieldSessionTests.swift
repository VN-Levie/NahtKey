import AppKit
import SwiftUI
import XCTest
import NahtKeyCore
@testable import NahtKeyApp

@MainActor
final class LocalFieldSessionTests: XCTestCase {
    private final class LaggingField: NSTextField {
        var simulatesDelayedValue = false
        override var stringValue: String {
            get { simulatesDelayedValue ? "" : super.stringValue }
            set { super.stringValue = newValue }
        }
    }

    func testFirstWordInNewNativeEditorForBothInputMethods() throws {
        _ = NSApplication.shared
        for (method, keys, expected) in [
            (InputMethod.vni, "uu7", "ưu"), (.vni, "u7", "ư"), (.vni, "chu7a", "chưa"),
            (.vni, "hoa2n\u{7f}", "hòa"), (.telex, "uuw", "ưu"),
            (.telex, "user ", "user "), (.telex, "hoafn\u{7f}", "hòa")
        ] {
            var value = ""
            let view = VietnameseTextField(text: Binding(get: { value }, set: { value = $0 }),
                inputMethod: method, typingOptions: TypingOptions(restoreEnglishTelex: true), placeholder: "")
            let coordinator = view.makeCoordinator()
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 300, height: 100),
                                  styleMask: .borderless, backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 280, height: 24))
            field.delegate = coordinator
            window.contentView?.addSubview(field)
            coordinator.attach(field)
            defer { coordinator.detach(); field.delegate = nil; window.makeFirstResponder(nil) }
            XCTAssertTrue(window.makeFirstResponder(field))
            for key in keys {
                let code: UInt16 = key == "\u{7f}" ? 51 : (key == " " ? 49 : 0)
                let event = try XCTUnwrap(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [],
                    timestamp: 0, windowNumber: window.windowNumber, context: nil, characters: String(key),
                    charactersIgnoringModifiers: String(key), isARepeat: false, keyCode: code))
                XCTAssertNil(coordinator.handle(event))
                coordinator.synchronizeText(in: field)
            }
            XCTAssertEqual(value, expected, "\(method): \(keys)")
        }
    }

    func testBindingRedrawDuringEditingKeepsRawHistoryAndSelection() throws {
        _ = NSApplication.shared
        var value = ""
        let view = VietnameseTextField(text: Binding(get: { value }, set: { value = $0 }),
            inputMethod: .telex, typingOptions: TypingOptions(restoreEnglishTelex: true), placeholder: "")
        let coordinator = view.makeCoordinator()
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 300, height: 100),
                              styleMask: .borderless, backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        let field = LaggingField(frame: NSRect(x: 0, y: 0, width: 280, height: 24))
        field.isEditable = true
        field.delegate = coordinator
        window.contentView?.addSubview(field)
        coordinator.attach(field)
        defer { coordinator.detach(); field.delegate = nil; window.makeFirstResponder(nil) }
        XCTAssertTrue(window.makeFirstResponder(field))
        let editor = try XCTUnwrap(field.currentEditor() as? NSTextView)

        func key(_ character: String, code: UInt16) throws {
            let event = try XCTUnwrap(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [],
                timestamp: 0, windowNumber: window.windowNumber, context: nil, characters: character,
                charactersIgnoringModifiers: character, isARepeat: false, keyCode: code))
            XCTAssertNil(coordinator.handle(event))
        }
        try key("u", code: 32)
        XCTAssertEqual(value, "u")
        XCTAssertEqual(editor.selectedRange(), NSRange(location: 1, length: 0))
        field.simulatesDelayedValue = true
        coordinator.synchronizeText(in: field)
        field.simulatesDelayedValue = false
        try key("s", code: 1)
        XCTAssertEqual(value, "ú")
        try key("e", code: 14)
        XCTAssertEqual(value, "úe")
        try key("r", code: 15)
        XCTAssertEqual(value, "ủe")
        try key(" ", code: 49)
        XCTAssertEqual(value, "user ")
        XCTAssertEqual(editor.string, "user ")
        XCTAssertEqual(editor.selectedRange(), NSRange(location: 5, length: 0))
    }
}
