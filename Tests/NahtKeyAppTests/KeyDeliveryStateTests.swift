import CoreGraphics
import XCTest
import NahtKeyCore
@testable import NahtKeyApp

final class KeyDeliveryStateTests: XCTestCase {
    func testPassedDownStillGetsItsUpAfterTransformedRepeats() {
        for sequence in [[true, false], [true, false, false], [false, true, false], [false, false, true]] {
            var state = KeyDeliveryState()
            for passed in sequence { state.recordDown(0, forwarded: passed) }
            XCTAssertTrue(state.hasForwardedDown(0))
            XCTAssertTrue(state.release(0))
            XCTAssertFalse(state.hasForwardedDown(0))
        }
    }

    func testTelexHeldARepeatKeepsPhysicalReleaseBalanced() {
        let engine = VNIEngine(inputMethod: .telex)
        var state = KeyDeliveryState()
        for _ in 0..<2 {
            let edit = engine.process("a")
            state.recordDown(0, forwarded: edit.deleteCount == 0 && edit.insertText == "a")
        }
        XCTAssertEqual(engine.rendered, "â")
        XCTAssertTrue(state.release(0), "The first A down reached the target, so its up must also arrive")
    }

    func testEntirelyConsumedPressDoesNotLeakUpAndNextPressIsIndependent() {
        var state = KeyDeliveryState()
        state.recordDown(26, forwarded: false)
        state.recordDown(26, forwarded: false)
        XCTAssertFalse(state.release(26))
        state.recordDown(26, forwarded: true)
        XCTAssertTrue(state.release(26))
        XCTAssertTrue(state.release(14), "Unknown up defaults to pass-through")
    }

    func testLifecycleResetClearsBothPassedAndConsumedState() {
        var state = KeyDeliveryState()
        state.recordDown(0, forwarded: true)
        state.recordDown(0, forwarded: false)
        state.recordDown(26, forwarded: false)
        state.reset()
        XCTAssertFalse(state.hasForwardedDown(0))
        XCTAssertTrue(state.release(0))
        XCTAssertTrue(state.release(26))
    }
}
