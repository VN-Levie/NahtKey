import CoreGraphics
import XCTest
@testable import NahtKeyApp

final class ModifierToggleStateTests: XCTestCase {
    func testBothPressOrdersToggleOnlyOnceOnRelease() {
        for first: CGEventFlags in [.maskControl, .maskShift] {
            var state = ModifierToggleState()
            XCTAssertFalse(state.flagsChanged(first))
            XCTAssertFalse(state.flagsChanged([.maskControl, .maskShift]))
            XCTAssertFalse(state.flagsChanged([.maskControl, .maskShift]))
            XCTAssertTrue(state.flagsChanged(first))
            XCTAssertFalse(state.flagsChanged([]))
            XCTAssertFalse(state.flagsChanged([]))
        }
    }

    func testCharacterShortcutAndMouseGestureNeverToggle() {
        for _ in 0..<2 {
            var state = ModifierToggleState()
            _ = state.flagsChanged([.maskControl, .maskShift])
            state.usedOtherInput(flags: [.maskControl, .maskShift])
            XCTAssertFalse(state.flagsChanged(.maskControl))
            XCTAssertFalse(state.flagsChanged([]))
            _ = state.flagsChanged([.maskControl, .maskShift])
            XCTAssertTrue(state.flagsChanged([]))
        }
    }

    func testCommandOptionAndFnCancelWholeGesture() {
        for extra: CGEventFlags in [.maskCommand, .maskAlternate, .maskSecondaryFn] {
            var state = ModifierToggleState()
            _ = state.flagsChanged([.maskControl, .maskShift])
            XCTAssertFalse(state.flagsChanged([.maskControl, .maskShift, extra]))
            XCTAssertFalse(state.flagsChanged([.maskControl, .maskShift]))
            XCTAssertFalse(state.flagsChanged([]))
        }
    }

    func testCapsLockDoesNotPreventGestureAndResetDisarms() {
        var state = ModifierToggleState()
        XCTAssertFalse(state.flagsChanged([.maskAlphaShift, .maskControl, .maskShift]))
        XCTAssertTrue(state.flagsChanged(.maskAlphaShift))
        _ = state.flagsChanged([.maskControl, .maskShift])
        state.reset()
        XCTAssertFalse(state.flagsChanged([]))
    }

    func testNormalTypingDoesNotPoisonNextGesture() {
        var state = ModifierToggleState()
        state.usedOtherInput(flags: [])
        XCTAssertFalse(state.flagsChanged(.maskControl))
        XCTAssertFalse(state.flagsChanged([.maskControl, .maskShift]))
        XCTAssertTrue(state.flagsChanged([]))
    }
}
