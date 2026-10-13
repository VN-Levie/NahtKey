import AppKit
import Carbon
import Combine
import SwiftUI

/// Services live independently of windows. Login creates the menu and keyboard
/// hook, but never constructs a window or restores saved windows.
@MainActor
final class ApplicationLifecycle: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private let dictionary = DictionaryStore()
    private let keyboard = KeyboardController()
    private let loginItem = LoginItemController()
    private var dictionaryObservation: AnyCancellable?
    private var mainWindow: NSWindow?
    private var allowsTermination = false
    private var acceptsUserReopen = false
    private var statusItemController: NativeStatusItemController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Read now: currentAppleEvent changes after the launch callback.
        let background = StartupPolicy.isBackgroundLaunch(
            event: NSAppleEventManager.shared().currentAppleEvent,
            arguments: ProcessInfo.processInfo.arguments)
        NSApp.setActivationPolicy(.accessory)
        installApplicationMenu()
        dictionaryObservation = dictionary.$entries.sink { [weak self] entries in
            self?.keyboard.updateCorrections(Dictionary(uniqueKeysWithValues: entries.map { ($0.raw, $0.replacement) }))
        }
        statusItemController = NativeStatusItemController(
            keyboard: keyboard,
            openWindow: { [weak self] in self?.showMainWindow() },
            quit: { [weak self] in self?.quitCompletely() })
        if !background { showMainWindow() }
        // AppKit may issue an initial reopen without retaining the launch event.
        // Ignore that launch turn; later explicit opens can still show the window.
        DispatchQueue.main.async { [weak self] in self?.acceptsUserReopen = true }
    }

    func applicationDidBecomeActive(_ notification: Notification) { loginItem.refresh() }
    func applicationShouldOpenUntitledFile(_ sender: NSApplication) -> Bool { false }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard !allowsTermination, !isSystemTermination else { return .terminateNow }
        hideToMenuBar()
        return .terminateCancel
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        guard acceptsUserReopen,
              !StartupPolicy.isLoginEvent(NSAppleEventManager.shared().currentAppleEvent) else { return false }
        showMainWindow()
        return false
    }

    func applicationWillTerminate(_ notification: Notification) {
        dictionaryObservation?.cancel()
        statusItemController?.shutdown()
        statusItemController = nil
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        hideToMenuBar()
        return false
    }

    @objc private func hideFromMenu(_ sender: Any?) { hideToMenuBar() }
    @objc private func quitFromMenu(_ sender: Any?) { quitCompletely() }

    func hideToMenuBar() {
        // Preserve sheets and unsaved fields when hiding the window.
        NSApp.hide(nil)
    }

    func showMainWindow() {
        NSApp.setActivationPolicy(.accessory)
        if mainWindow == nil {
            let content = MainView(dictionary: dictionary, keyboard: keyboard, loginItem: loginItem)
            let window = NSWindow(contentViewController: NSHostingController(rootView: content))
            window.title = "NahtKey"
            window.setAccessibilityIdentifier("main")
            window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
            window.setContentSize(NSSize(width: 880, height: 650))
            window.contentMinSize = NSSize(width: 760, height: 580)
            window.isReleasedWhenClosed = false
            window.isRestorable = false
            window.delegate = self
            window.center()
            mainWindow = window
        }
        loginItem.refresh()
        NSApp.unhide(nil)
        if mainWindow?.isMiniaturized == true { mainWindow?.deminiaturize(nil) }
        mainWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func quitCompletely() {
        allowsTermination = true
        NSApp.terminate(nil)
    }

    private func installApplicationMenu() {
        let bar = NSMenu()
        func submenu(_ title: String) -> NSMenu {
            let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
            let menu = NSMenu(title: title)
            item.submenu = menu
            bar.addItem(item)
            return menu
        }
        let appMenu = submenu("NahtKey")
        for key in ["h", "q"] {
            let title = key == "h" ? "Ẩn NahtKey" : "Ẩn cửa sổ"
            let item = appMenu.addItem(withTitle: title, action: #selector(hideFromMenu(_:)), keyEquivalent: key)
            item.target = self
        }
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Thoát hoàn toàn NahtKey", action: #selector(quitFromMenu(_:)), keyEquivalent: "").target = self
        let file = submenu("Tệp")
        file.addItem(withTitle: "Đóng cửa sổ", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        let edit = submenu("Sửa")
        edit.addItem(withTitle: "Hoàn tác", action: Selector(("undo:")), keyEquivalent: "z")
        let redo = edit.addItem(withTitle: "Làm lại", action: Selector(("redo:")), keyEquivalent: "z")
        redo.keyEquivalentModifierMask = [.command, .shift]
        edit.addItem(.separator())
        for (title, action, key) in [("Cắt", "cut:", "x"), ("Sao chép", "copy:", "c"),
                                     ("Dán", "paste:", "v"), ("Chọn tất cả", "selectAll:", "a")] {
            edit.addItem(withTitle: title, action: Selector(action), keyEquivalent: key)
        }
        let windows = submenu("Cửa sổ")
        windows.addItem(withTitle: "Thu nhỏ", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        windows.addItem(withTitle: "Thu phóng", action: #selector(NSWindow.performZoom(_:)), keyEquivalent: "")
        NSApp.windowsMenu = windows
        NSApp.mainMenu = bar
    }

    private var isSystemTermination: Bool {
        guard let event = NSAppleEventManager.shared().currentAppleEvent,
              let reason = event.paramDescriptor(forKeyword: AEKeyword(kAEQuitReason))?.enumCodeValue else { return false }
        return [kAEQuitAll, kAEShutDown, kAERestart, kAEReallyLogOut, kAELogOut]
            .map { OSType($0) }.contains(reason)
    }
}
