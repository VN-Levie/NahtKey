import XCTest
@testable import NahtKeyApp

final class ApplicationTypingStateTests: XCTestCase {
    func testDisabledOptionUsesOnlyGlobalStateAcrossApplications() {
        var state = ApplicationTypingState(globalEnabled: true, applications: ["editor": false])
        state.activate("editor", ownBundleID: "self")
        XCTAssertTrue(state.desiredEnabled(rememberPerApplication: false))
        state.setEnabled(false, rememberPerApplication: false)
        state.activate("chat", ownBundleID: "self")
        XCTAssertFalse(state.desiredEnabled(rememberPerApplication: false))
        XCTAssertNil(state.applications["chat"])
    }

    func testProfilesRestoreWithoutOverwritingGlobalOrEachOther() {
        var state = ApplicationTypingState()
        state.activate("editor", ownBundleID: "self")
        state.setEnabled(false, rememberPerApplication: true)
        state.activate("chat", ownBundleID: "self")
        XCTAssertTrue(state.desiredEnabled(rememberPerApplication: true))
        state.setEnabled(true, rememberPerApplication: true)
        state.activate("editor", ownBundleID: "self")
        XCTAssertFalse(state.desiredEnabled(rememberPerApplication: true))
        XCTAssertTrue(state.globalEnabled)
        XCTAssertTrue(state.desiredEnabled(rememberPerApplication: false))
        state.clearApplications()
        XCTAssertTrue(state.desiredEnabled(rememberPerApplication: true))
    }

    func testSettingsAndTransientMissingFocusDoNotCreateOrOverwriteProfiles() {
        var state = ApplicationTypingState()
        state.activate("editor", ownBundleID: "self")
        state.activate("self", ownBundleID: "self")
        state.activate(nil, ownBundleID: "self")
        state.activate("", ownBundleID: "self")
        state.setEnabled(false, rememberPerApplication: true)
        XCTAssertEqual(state.applications, ["editor": false])
        XCTAssertEqual(state.activeApplication, "editor")
    }
}
