import Foundation
import ServiceManagement
import XCTest
@testable import NahtKeyApp

final class LoginItemControllerTests: XCTestCase {
    @MainActor private final class FakeService: LoginItemService {
        var status: SMAppService.Status = .notRegistered
        var registrationStatus: SMAppService.Status? = .enabled
        var unregistrationStatus: SMAppService.Status? = .notRegistered
        var registrationError: Error?
        var unregistrationError: Error?
        var registrationCalls = 0
        var unregistrationCalls = 0
        var settingsCalls = 0

        func register() throws {
            registrationCalls += 1
            if let registrationStatus { status = registrationStatus }
            if let registrationError { throw registrationError }
        }

        func unregister() throws {
            unregistrationCalls += 1
            if let unregistrationStatus { status = unregistrationStatus }
            if let unregistrationError { throw unregistrationError }
        }

        func openSettings() { settingsCalls += 1 }
    }

    @MainActor func testInitializationAndRefreshOnlyReadActualSystemStatus() {
        let service = FakeService()
        let controller = LoginItemController(service: service)
        XCTAssertFalse(controller.isEnabled)
        service.status = .enabled
        controller.refresh()
        XCTAssertTrue(controller.isEnabled)
        service.status = .notRegistered
        controller.refresh()
        XCTAssertFalse(controller.isEnabled)
        XCTAssertEqual(service.registrationCalls, 0)
        XCTAssertEqual(service.unregistrationCalls, 0)
    }

    @MainActor func testExplicitToggleRegistersAndUnregisters() {
        let service = FakeService()
        let controller = LoginItemController(service: service)
        controller.setEnabled(true)
        XCTAssertEqual(service.registrationCalls, 1)
        XCTAssertTrue(controller.isEnabled)
        XCTAssertNil(controller.errorMessage)
        controller.setEnabled(false)
        XCTAssertEqual(service.unregistrationCalls, 1)
        XCTAssertFalse(controller.isEnabled)
        XCTAssertEqual(controller.status, .notRegistered)
    }

    @MainActor func testPendingApprovalKeepsToggleOnAndCanOpenSettingsOrUnregister() {
        let service = FakeService()
        service.registrationStatus = .requiresApproval
        let controller = LoginItemController(service: service)
        controller.setEnabled(true)
        XCTAssertTrue(controller.isEnabled)
        XCTAssertTrue(controller.requiresApproval)
        XCTAssertNotNil(controller.statusMessage)
        controller.setEnabled(true)
        XCTAssertEqual(service.registrationCalls, 1)
        controller.openSettings()
        XCTAssertEqual(service.settingsCalls, 1)
        controller.setEnabled(false)
        XCTAssertFalse(controller.isEnabled)
        XCTAssertFalse(controller.requiresApproval)
        XCTAssertEqual(service.unregistrationCalls, 1)
    }

    @MainActor func testFailedRegistrationReportsErrorAndReflectsActualStatus() {
        let service = FakeService()
        service.registrationStatus = .requiresApproval
        service.registrationError = NSError(domain: "LoginItemTest", code: 1,
                                            userInfo: [NSLocalizedDescriptionKey: "Permission denied"])
        let controller = LoginItemController(service: service)
        controller.setEnabled(true)
        XCTAssertEqual(controller.status, .requiresApproval)
        XCTAssertTrue(controller.isEnabled)
        XCTAssertTrue(controller.errorMessage?.contains("Permission denied") == true)
        controller.refresh()
        XCTAssertNotNil(controller.errorMessage)
    }

    @MainActor func testFailedUnregisterDoesNotPretendLoginWasDisabledAndRetryCanRecover() {
        let service = FakeService()
        service.status = .enabled
        service.unregistrationStatus = nil
        service.unregistrationError = NSError(domain: "LoginItemTest", code: 2,
                                              userInfo: [NSLocalizedDescriptionKey: "Temporarily unavailable"])
        let controller = LoginItemController(service: service)
        controller.setEnabled(false)
        XCTAssertTrue(controller.isEnabled)
        XCTAssertNotNil(controller.errorMessage)
        service.unregistrationStatus = .notRegistered
        service.unregistrationError = nil
        controller.setEnabled(false)
        XCTAssertFalse(controller.isEnabled)
        XCTAssertNil(controller.errorMessage)
    }

    @MainActor func testToggleRefreshesExternalStateBeforeAttemptingMutation() {
        let service = FakeService()
        let controller = LoginItemController(service: service)
        service.status = .enabled
        controller.setEnabled(true)
        XCTAssertTrue(controller.isEnabled)
        XCTAssertEqual(service.registrationCalls, 0)
        service.status = .notRegistered
        controller.setEnabled(false)
        XCTAssertFalse(controller.isEnabled)
        XCTAssertEqual(service.unregistrationCalls, 0)
    }

    @MainActor func testMissingServiceIsNotReportedAsEnabled() {
        let service = FakeService()
        service.status = .notFound
        let controller = LoginItemController(service: service)
        XCTAssertFalse(controller.isEnabled)
        XCTAssertFalse(controller.requiresApproval)
        XCTAssertNotNil(controller.statusMessage)
        XCTAssertEqual(service.registrationCalls, 0)
    }
}
