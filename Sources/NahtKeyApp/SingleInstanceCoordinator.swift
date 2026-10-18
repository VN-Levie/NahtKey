import AppKit

/// Owns the process gate before any keyboard hook, dictionary, or menu exists.
@MainActor
final class SingleInstanceCoordinator: NSObject {
    private static let reopenNotification = Notification.Name("vn.nahtkey.mac.showMainWindow")
    private let center = DistributedNotificationCenter.default()
    private let user = String(getuid())
    private var lock: SingleInstanceLock?
    private var pendingReopen = false
    private var reopen: (() -> Void)?

    var isPrimary: Bool { lock != nil }

    override init() {
        super.init()
        // Register before competing for the lock, so a cold-start loser cannot
        // send its request before the winning process installs its observer.
        center.addObserver(self, selector: #selector(receiveReopen),
                           name: Self.reopenNotification, object: user,
                           suspensionBehavior: .deliverImmediately)
    }

    deinit { center.removeObserver(self) }

    func acquire() throws {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("NahtKey", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        lock = try SingleInstanceLock.acquire(at: directory.appendingPathComponent("instance.lock"))
    }

    func handleReopen(using handler: @escaping () -> Void) {
        reopen = handler
        if pendingReopen {
            pendingReopen = false
            handler()
        }
    }

    func showExistingWindow() {
        // No payload is accepted from other processes. This notification can
        // only reveal our existing window, never change settings or text.
        center.postNotificationName(Self.reopenNotification, object: user,
                                    userInfo: nil, deliverImmediately: true)
    }

    @objc private func receiveReopen(_ notification: Notification) {
        guard isPrimary else { return }
        if let reopen { reopen() }
        else { pendingReopen = true }
    }
}

/// A rejected launch runs only far enough to read its launch Apple event. It
/// never constructs ApplicationLifecycle, which would start the keyboard tap.
@MainActor
final class DuplicateInstanceLifecycle: NSObject, NSApplicationDelegate {
    private let instance: SingleInstanceCoordinator

    init(instance: SingleInstanceCoordinator) { self.instance = instance }

    func applicationDidFinishLaunching(_ notification: Notification) {
        if !StartupPolicy.isBackgroundLaunch(event: NSAppleEventManager.shared().currentAppleEvent,
                                             arguments: ProcessInfo.processInfo.arguments) {
            instance.showExistingWindow()
        }
        NSApp.terminate(nil)
    }

    func applicationShouldOpenUntitledFile(_ sender: NSApplication) -> Bool { false }
}
