import Foundation
import XCTest
@testable import NahtKeyApp

final class StatusItemClickDispatcherTests: XCTestCase {
    @MainActor private final class ManualScheduler {
        var actions: [StatusItemClickDispatcher.Action] = []
        var delays: [TimeInterval] = []
        var cancelled = Set<Int>()

        func schedule(delay: TimeInterval, action: @escaping StatusItemClickDispatcher.Action) -> StatusItemClickDispatcher.Cancellation {
            let index = actions.count
            actions.append(action)
            delays.append(delay)
            return { [weak self] in self?.cancelled.insert(index) }
        }
    }

    @MainActor func testSingleClickWaitsForDoubleClickIntervalBeforeOpeningMenu() {
        let scheduler = ManualScheduler()
        var menus = 0
        var windows = 0
        let dispatcher = StatusItemClickDispatcher(
            delay: 0.45, schedule: { scheduler.schedule(delay: $0, action: $1) },
            openMenu: { menus += 1 }, openWindow: { windows += 1 }
        )
        dispatcher.handle(clickCount: 1)
        XCTAssertEqual(menus, 0)
        XCTAssertEqual(windows, 0)
        XCTAssertEqual(scheduler.delays, [0.45])
        scheduler.actions[0]()
        XCTAssertEqual(menus, 1)
        XCTAssertEqual(windows, 0)
    }

    @MainActor func testDoubleClickCancelsPendingMenuAndOpensWindowOnce() {
        let scheduler = ManualScheduler()
        var menus = 0
        var windows = 0
        let dispatcher = StatusItemClickDispatcher(
            delay: 0.45, schedule: { scheduler.schedule(delay: $0, action: $1) },
            openMenu: { menus += 1 }, openWindow: { windows += 1 }
        )
        dispatcher.handle(clickCount: 1)
        dispatcher.handle(clickCount: 2)
        XCTAssertEqual(scheduler.cancelled, [0])
        XCTAssertEqual(windows, 1)
        // A callback that was already queued must remain harmless after cancellation.
        scheduler.actions[0]()
        XCTAssertEqual(menus, 0)
        XCTAssertEqual(windows, 1)
    }

    @MainActor func testRightClickImmediatelyOpensMenuAndCancelsPendingLeftClick() {
        let scheduler = ManualScheduler()
        var menus = 0
        var windows = 0
        let dispatcher = StatusItemClickDispatcher(
            delay: 0.45, schedule: { scheduler.schedule(delay: $0, action: $1) },
            openMenu: { menus += 1 }, openWindow: { windows += 1 }
        )
        dispatcher.handle(clickCount: 1)
        dispatcher.handle(clickCount: 1, rightClick: true)
        XCTAssertEqual(menus, 1)
        XCTAssertEqual(windows, 0)
        XCTAssertEqual(scheduler.cancelled, [0])
        scheduler.actions[0]()
        XCTAssertEqual(menus, 1)
    }

    @MainActor func testExternalReopenOrShutdownCanCancelPendingMenu() {
        let scheduler = ManualScheduler()
        var menus = 0
        let dispatcher = StatusItemClickDispatcher(
            delay: 0.45, schedule: { scheduler.schedule(delay: $0, action: $1) },
            openMenu: { menus += 1 }, openWindow: {}
        )
        dispatcher.handle(clickCount: 1)
        dispatcher.cancelPending()
        scheduler.actions[0]()
        XCTAssertEqual(menus, 0)
        dispatcher.handle(clickCount: 1)
        scheduler.actions[1]()
        XCTAssertEqual(menus, 1)
    }
}
