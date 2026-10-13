import AppKit
import Combine
import NahtKeyCore

/// App-owned rather than view-owned, so hiding or redrawing a window never creates
/// a second status item and never removes the user's way to reopen NahtKey.
@MainActor
final class NativeStatusItemController: NSObject, NSMenuDelegate {
    private let keyboard: KeyboardController
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let menu = NSMenu(title: "NahtKey")
    private let toggleItem = NSMenuItem(title: "Bật bộ gõ (Ctrl + Shift)", action: nil, keyEquivalent: "")
    private let vniItem = NSMenuItem(title: "VNI", action: nil, keyEquivalent: "")
    private let telexItem = NSMenuItem(title: "Telex", action: nil, keyEquivalent: "")
    private let openWindow: () -> Void
    private let quit: () -> Void
    private let enabledIcon: NSImage?
    private let disabledIcon: NSImage?
    private var observation: AnyCancellable?
    private var removed = false

    init(keyboard: KeyboardController, openWindow: @escaping () -> Void, quit: @escaping () -> Void) {
        self.keyboard = keyboard
        self.openWindow = openWindow
        self.quit = quit
        let icon = Self.makeIcon()
        enabledIcon = icon
        disabledIcon = Self.makeDisabledIcon(from: icon)
        super.init()
        configureMenu()
        statusItem.menu = menu
        if let button = statusItem.button {
            button.title = ""
            button.imagePosition = .imageOnly
            button.image = enabledIcon
            button.setAccessibilityIdentifier("NahtKeyStatusItem")
        }
        observation = keyboard.$isEnabled.combineLatest(keyboard.$inputMethod).sink { [weak self] enabled, method in
            self?.refresh(enabled: enabled, method: method)
        }
    }

    func shutdown() {
        guard !removed else { return }
        removed = true
        observation?.cancel()
        observation = nil
        menu.cancelTracking()
        statusItem.menu = nil
        menu.delegate = nil
        NSStatusBar.system.removeStatusItem(statusItem)
    }

    func menuWillOpen(_ menu: NSMenu) {
        refresh(enabled: keyboard.isEnabled, method: keyboard.inputMethod)
    }

    @objc private func toggleInput(_ sender: NSMenuItem) { keyboard.toggle() }

    @objc private func selectMethod(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let method = InputMethod(rawValue: raw) else { return }
        keyboard.setInputMethod(method)
    }

    @objc private func showMainWindow(_ sender: NSMenuItem) { openWindow() }
    @objc private func quitApplication(_ sender: NSMenuItem) { quit() }

    private func configureMenu() {
        menu.delegate = self
        menu.autoenablesItems = false
        toggleItem.target = self
        toggleItem.action = #selector(toggleInput(_:))
        menu.addItem(toggleItem)
        menu.addItem(.separator())
        let methods = NSMenu(title: "Kiểu gõ")
        methods.autoenablesItems = false
        for (method, item) in [(InputMethod.vni, vniItem), (InputMethod.telex, telexItem)] {
            item.target = self
            item.action = #selector(selectMethod(_:))
            item.representedObject = method.rawValue
            methods.addItem(item)
        }
        let methodsItem = NSMenuItem(title: "Kiểu gõ", action: nil, keyEquivalent: "")
        methodsItem.submenu = methods
        menu.addItem(methodsItem)
        menu.addItem(.separator())
        let openItem = NSMenuItem(title: "Mở NahtKey…", action: #selector(showMainWindow(_:)), keyEquivalent: "")
        openItem.target = self
        menu.addItem(openItem)
        menu.addItem(.separator())
        let quitItem = NSMenuItem(title: "Thoát hoàn toàn NahtKey", action: #selector(quitApplication(_:)), keyEquivalent: "")
        quitItem.target = self
        menu.addItem(quitItem)
    }

    private func refresh(enabled: Bool, method: InputMethod) {
        toggleItem.state = enabled ? .on : .off
        vniItem.state = method == .vni ? .on : .off
        telexItem.state = method == .telex ? .on : .off
        statusItem.button?.image = enabled ? enabledIcon : disabledIcon
        statusItem.button?.appearsDisabled = false
        let status = "NahtKey, \(method.displayName), \(enabled ? "đang bật" : "đang tắt")"
        statusItem.button?.setAccessibilityLabel(status)
        statusItem.button?.toolTip = "\(status)\nCtrl + Shift: bật/tắt. Bấm để mở menu."
    }

    private static func makeDisabledIcon(from base: NSImage?) -> NSImage? {
        guard let base else { return nil }
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { bounds in
            base.draw(in: bounds)
            let slash = NSBezierPath()
            slash.move(to: NSPoint(x: 2.5, y: 2.0))
            slash.line(to: NSPoint(x: 15.5, y: 11.0))
            slash.lineCapStyle = .round
            // A transparent halo keeps the slash legible where it crosses the mark.
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current?.compositingOperation = .clear
            slash.lineWidth = 2.6
            NSColor.black.setStroke()
            slash.stroke()
            NSGraphicsContext.restoreGraphicsState()
            slash.lineWidth = 1.0
            NSColor.black.setStroke()
            slash.stroke()
            return true
        }
        image.isTemplate = true
        return image
    }

    private static func makeIcon() -> NSImage? {
        let image: NSImage?
        if let url = Bundle.main.url(forResource: "NahtKeyMenuBar", withExtension: "png") {
            image = NSImage(contentsOf: url)
        } else {
            image = NSImage(systemSymbolName: "keyboard", accessibilityDescription: "NahtKey")
        }
        image?.isTemplate = true
        image?.size = NSSize(width: 18, height: 18)
        return image
    }
}
