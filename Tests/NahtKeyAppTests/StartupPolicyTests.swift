import AppKit
import Carbon
import XCTest
@testable import NahtKeyApp

final class StartupPolicyTests: XCTestCase {
    private func launchEvent(reason: OSType? = nil, eventID: AEEventID = AEEventID(kAEOpenApplication)) -> NSAppleEventDescriptor {
        let event = NSAppleEventDescriptor(eventClass: AEEventClass(kCoreEventClass), eventID: eventID,
            targetDescriptor: nil, returnID: AEReturnID(kAutoGenerateReturnID), transactionID: AETransactionID(kAnyTransactionID))
        if let reason {
            event.setParam(NSAppleEventDescriptor(enumCode: reason), forKeyword: AEKeyword(keyAEPropData))
        }
        return event
    }

    func testLoginAppleEventRequestsBackgroundStartup() {
        XCTAssertTrue(StartupPolicy.isBackgroundLaunch(event: launchEvent(reason: OSType(keyAELaunchedAsLogInItem)),
                                                       arguments: ["NahtKey"]))
    }

    func testManualOpenRemainsExplicitWindowRequest() {
        XCTAssertFalse(StartupPolicy.isBackgroundLaunch(event: launchEvent(), arguments: ["NahtKey"]))
        XCTAssertFalse(StartupPolicy.isBackgroundLaunch(event: nil, arguments: ["NahtKey"]))
        XCTAssertFalse(StartupPolicy.isLoginEvent(launchEvent(reason: OSType(keyAELaunchedAsLogInItem),
                                                            eventID: AEEventID(kAEReopenApplication))))
    }

    func testExplicitBackgroundArgumentUsesSameWindowPolicy() {
        XCTAssertTrue(StartupPolicy.isBackgroundLaunch(event: nil, arguments: ["NahtKey", "--background"]))
        XCTAssertFalse(StartupPolicy.isBackgroundLaunch(event: nil, arguments: ["NahtKey", "background"]))
    }
}
