import AppKit
import Carbon
import SwiftUI

/// Closing the settings window leaves the input hook and the menu-bar item alive.
/// A normal Quit request has the same effect; complete termination is explicit.
@MainActor
final class ApplicationLifecycle: NSObject, NSApplicationDelegate {
    private weak var mainWindow: NSWindow?
    private var windowDelegate: BackgroundWindowDelegate?
    private var allowsTermination = false
    private var statusItemController: NativeStatusItemController?
    private var createMainWindow: (() -> Void)?

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard !allowsTermination, !isSystemTermination else { return .terminateNow }
        hideToMenuBar()
        return .terminateCancel
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        guard mainWindow != nil || createMainWindow != nil else {
            sender.setActivationPolicy(.regular)
            return true
        }
        showMainWindow()
        return false
    }

    func applicationWillTerminate(_ notification: Notification) {
        statusItemController?.shutdown()
        statusItemController = nil
    }

    func installStatusItem(keyboard: KeyboardController, createMainWindow: @escaping () -> Void) {
        guard statusItemController == nil else { return }
        self.createMainWindow = createMainWindow
        statusItemController = NativeStatusItemController(
            keyboard: keyboard,
            openWindow: { [weak self] in self?.showMainWindow() },
            quit: { [weak self] in self?.quitCompletely() }
        )
    }

    func registerMainWindow(_ window: NSWindow) {
        guard mainWindow !== window else { return }
        mainWindow = window
        window.isReleasedWhenClosed = false
        let delegate = BackgroundWindowDelegate(lifecycle: self, original: window.delegate)
        windowDelegate = delegate
        window.delegate = delegate
    }

    func hideToMenuBar() {
        // Hiding preserves sheets and other settings windows, including unsaved fields.
        NSApp.hide(nil)
        NSApp.setActivationPolicy(.accessory)
    }

    func showMainWindow(createWindow: (() -> Void)? = nil) {
        NSApp.setActivationPolicy(.regular)
        NSApp.unhide(nil)
        if let mainWindow {
            mainWindow.makeKeyAndOrderFront(nil)
        } else {
            (createWindow ?? createMainWindow)?()
        }
        NSApp.activate(ignoringOtherApps: true)
    }

    func quitCompletely() {
        allowsTermination = true
        NSApp.terminate(nil)
    }

    private var isSystemTermination: Bool {
        // A user Quit stays in the menu bar; system logout/restart/shutdown must finish.
        guard let event = NSAppleEventManager.shared().currentAppleEvent,
              let reason = event.paramDescriptor(forKeyword: AEKeyword(kAEQuitReason))?.enumCodeValue else {
            return false
        }
        return [kAEQuitAll, kAEShutDown, kAERestart, kAEReallyLogOut, kAELogOut]
            .map { OSType($0) }.contains(reason)
    }
}

/// Keep SwiftUI's window callbacks intact while changing only the close behavior.
@MainActor
private final class BackgroundWindowDelegate: NSObject, NSWindowDelegate {
    private weak var lifecycle: ApplicationLifecycle?
    private weak var original: NSWindowDelegate?

    init(lifecycle: ApplicationLifecycle, original: NSWindowDelegate?) {
        self.lifecycle = lifecycle
        self.original = original
        super.init()
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        lifecycle?.hideToMenuBar()
        return false
    }

    override func responds(to selector: Selector!) -> Bool {
        super.responds(to: selector) || original?.responds(to: selector) == true
    }

    override func forwardingTarget(for selector: Selector!) -> Any? {
        if original?.responds(to: selector) == true { return original }
        return super.forwardingTarget(for: selector)
    }
}

struct MainWindowRegistration: NSViewRepresentable {
    let lifecycle: ApplicationLifecycle
    let keyboard: KeyboardController
    @Environment(\.openWindow) private var openWindow

    func makeNSView(context: Context) -> NSView {
        let openWindow = openWindow
        return WindowObserverView { window in
            lifecycle.registerMainWindow(window)
            lifecycle.installStatusItem(keyboard: keyboard, createMainWindow: { openWindow(id: "main") })
        }
    }

    func updateNSView(_ nsView: NSView, context: Context) {}

    @MainActor
    private final class WindowObserverView: NSView {
        let register: (NSWindow) -> Void

        init(register: @escaping (NSWindow) -> Void) {
            self.register = register
            super.init(frame: .zero)
        }

        required init?(coder: NSCoder) { nil }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            guard let window else { return }
            DispatchQueue.main.async { [weak self, weak window] in
                guard let window else { return }
                self?.register(window)
            }
        }
    }
}
