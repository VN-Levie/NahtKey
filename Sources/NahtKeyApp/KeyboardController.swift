import AppKit
import ApplicationServices
import Carbon
import Combine
import NahtKeyCore

/// The tap runs on the main run loop. No I/O or text logging occurs in its callback.
@MainActor
final class KeyboardController: ObservableObject {
    @Published private(set) var isEnabled = false
    @Published private(set) var hasPermission = AXIsProcessTrusted()
    @Published private(set) var otherInputApps: [String] = []
    @Published private(set) var errorMessage: String?
    @Published private(set) var inputMethod: InputMethod = .vni

    private let engine = VNIEngine()
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private var permissionTimer: Timer?
    private var workspaceObserver: NSObjectProtocol?
    private var lastInputPID: pid_t?
    private let ownBundleID = Bundle.main.bundleIdentifier ?? "vn.nahtkey.mac"
    private let eventSource = KeyboardController.makeEventSource()
    private var protectAutocomplete = false
    private var consumedKeys = Set<Int64>()
    private var focusObserver: AXObserver?
    private var focusApplication: AXUIElement?
    private var focusedElement: AXUIElement?
    private var secureFocus = false
    private static let eventMarker: Int64 = 0x4E4148544B4559

    init() {
        inputMethod = InputMethod(rawValue: UserDefaults.standard.string(forKey: "inputMethod") ?? "vni") ?? .vni
        engine.inputMethod = inputMethod
        refreshEnvironment()
        workspaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.refreshEnvironment()
            }
        }
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refreshEnvironment() }
        }
    }

    func updateCorrections(_ corrections: [String: String]) {
        engine.reset()
        engine.corrections = corrections
    }

    func refreshEnvironment() {
        hasPermission = AXIsProcessTrusted()
        _ = currentInputApplication()
        if IsSecureEventInputEnabled() { engine.reset() }
        let competitors: Set<String> = ["com.trankynam.GoTiengViet", "com.tuyenmai.openkey", "com.lamquangminh.evkey"]
        otherInputApps = NSWorkspace.shared.runningApplications.compactMap { app in
            guard let id = app.bundleIdentifier else { return nil }
            let name = app.localizedName ?? id
            return competitors.contains(id) || name.lowercased().contains("evkey") ? name : nil
        }.sorted()
        if !hasPermission && isEnabled { stop() }
    }

    func requestPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        hasPermission = AXIsProcessTrustedWithOptions(options)
        if !hasPermission {
            openPermissionSettings()
        }
    }

    func openPermissionSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    func setEnabled(_ enabled: Bool) {
        if enabled { start() } else { stop() }
    }

    func toggle() { setEnabled(!isEnabled) }

    func setInputMethod(_ method: InputMethod) {
        guard method != inputMethod else { return }
        inputMethod = method
        engine.inputMethod = method
        UserDefaults.standard.set(method.rawValue, forKey: "inputMethod")
    }

    static func makeEventSource() -> CGEventSource? {
        guard let source = CGEventSource(stateID: .privateState) else { return nil }
        // Synthetic replacement must never suppress the user's next physical keys.
        let allowed: CGEventFilterMask = [.permitLocalMouseEvents, .permitLocalKeyboardEvents, .permitSystemDefinedEvents]
        source.localEventsSuppressionInterval = 0
        source.setLocalEventsFilterDuringSuppressionState(allowed, state: .eventSuppressionStateSuppressionInterval)
        source.setLocalEventsFilterDuringSuppressionState(allowed, state: .eventSuppressionStateRemoteMouseDrag)
        return source
    }

    private func currentInputApplication() -> NSRunningApplication? {
        let app = NSWorkspace.shared.frontmostApplication
        if lastInputPID != app?.processIdentifier {
            engine.reset()
            lastInputPID = app?.processIdentifier
            watchFocus(of: app)
        }
        return app
    }

    private func watchFocus(of app: NSRunningApplication?) {
        if let focusObserver {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(focusObserver), .commonModes)
        }
        focusObserver = nil
        focusApplication = nil
        focusedElement = nil
        secureFocus = false
        guard hasPermission, let app else { return }
        let application = AXUIElementCreateApplication(app.processIdentifier)
        AXUIElementSetMessagingTimeout(application, 0.03)
        focusApplication = application
        var observer: AXObserver?
        guard AXObserverCreate(app.processIdentifier, { _, _, _, context in
            guard let context else { return }
            MainActor.assumeIsolated {
                Unmanaged<KeyboardController>.fromOpaque(context).takeUnretainedValue().refreshFocusedElement()
            }
        }, &observer) == .success, let observer else { return }
        focusObserver = observer
        AXObserverAddNotification(observer, application, kAXFocusedUIElementChangedNotification as CFString,
                                  Unmanaged.passUnretained(self).toOpaque())
        CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .commonModes)
        refreshFocusedElement()
    }

    private func refreshFocusedElement() {
        guard let application = focusApplication else { return }
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(application, kAXFocusedUIElementAttribute as CFString, &value) == .success,
              let value, CFGetTypeID(value) == AXUIElementGetTypeID() else { return }
        let element = value as! AXUIElement
        if let previous = focusedElement, !CFEqual(previous, element) { engine.reset() }
        focusedElement = element
        var subrole: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXSubroleAttribute as CFString, &subrole)
        secureFocus = (subrole as? String) == kAXSecureTextFieldSubrole as String
        if secureFocus { engine.reset() }
    }

    private func start() {
        refreshEnvironment()
        guard hasPermission else {
            errorMessage = "Cấp quyền Trợ năng cho NahtKey để bật bộ gõ."
            return
        }
        if let tap {
            engine.reset()
            CGEvent.tapEnable(tap: tap, enable: true)
            isEnabled = true
            errorMessage = nil
            return
        }
        let mask = (1 << CGEventType.keyDown.rawValue)
            | (1 << CGEventType.keyUp.rawValue)
            | (1 << CGEventType.flagsChanged.rawValue)
            | (1 << CGEventType.leftMouseDown.rawValue)
            | (1 << CGEventType.rightMouseDown.rawValue)
        let context = Unmanaged.passUnretained(self).toOpaque()
        guard let newTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap,
            eventsOfInterest: CGEventMask(mask), callback: { proxy, type, event, context in
                guard let context else { return Unmanaged.passUnretained(event) }
                return MainActor.assumeIsolated {
                    let controller = Unmanaged<KeyboardController>.fromOpaque(context).takeUnretainedValue()
                    return controller.handle(proxy: proxy, type: type, event: event)
                }
            }, userInfo: context
        ) else {
            errorMessage = "Chưa bắt được bàn phím. Kiểm tra quyền Trợ năng rồi mở lại NahtKey."
            return
        }
        guard let newSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, newTap, 0) else {
            CFMachPortInvalidate(newTap)
            errorMessage = "Không thể khởi tạo bộ gõ."
            return
        }
        tap = newTap
        source = newSource
        CFRunLoopAddSource(CFRunLoopGetMain(), newSource, .commonModes)
        CGEvent.tapEnable(tap: newTap, enable: true)
        isEnabled = true
        errorMessage = nil
        engine.reset()
    }

    private func stop() {
        if let tap { CGEvent.tapEnable(tap: tap, enable: false) }
        engine.reset()
        isEnabled = false
        consumedKeys.removeAll()
    }

    private func handle(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        let pass = Unmanaged.passUnretained(event)
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            engine.reset()
            if isEnabled, hasPermission, let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return pass
        }
        guard isEnabled else { return pass }
        guard event.getIntegerValueField(.eventSourceUserData) != Self.eventMarker else { return pass }
        let key = event.getIntegerValueField(.keyboardEventKeycode)
        if type == .keyUp {
            return consumedKeys.remove(key) != nil ? nil : pass
        }
        // Refresh process/focus before consulting secureFocus, which belongs to
        // the previously watched application until this transition is handled.
        let activeApp = type == .keyDown ? currentInputApplication() : nil
        // Password entry is owned by macOS; discard any partially composed word.
        guard !IsSecureEventInputEnabled(), !secureFocus else { engine.reset(); return pass }
        if type == .leftMouseDown || type == .rightMouseDown { engine.reset(); return pass }
        let flags = event.flags
        if type == .flagsChanged {
            if !flags.intersection([.maskCommand, .maskControl, .maskAlternate]).isEmpty { engine.reset() }
            return pass
        }
        guard type == .keyDown else { return pass }
        // Dictionary editors accept literal aliases. The built-in lab uses the same pure engine.
        guard let activeApp, activeApp.bundleIdentifier != ownBundleID else {
            engine.reset()
            return pass
        }
        protectAutocomplete = ReplacementPlan.protectsAutocomplete(bundleID: activeApp.bundleIdentifier ?? "")
        guard flags.intersection([.maskCommand, .maskControl, .maskAlternate]).isEmpty else {
            engine.reset()
            return pass
        }
        if key == 51 { // Physical Backspace removes a visible grapheme, not one raw VNI digit.
            let edit = engine.backspace()
            if edit.deleteCount == 1 && edit.insertText.isEmpty { return pass }
            if edit.deleteCount == 0 && edit.insertText.isEmpty { return pass }
            post(edit, proxy: proxy)
            consumedKeys.insert(key)
            return nil
        }
        if [36, 48, 49, 76].contains(key) { // Return, Tab, Space, keypad Return
            post(engine.finish(), proxy: proxy)
            return pass
        }
        if [53, 115, 116, 117, 119, 121, 123, 124, 125, 126].contains(key) {
            engine.reset()
            return pass
        }
        var length = 0
        var units = [UniChar](repeating: 0, count: 8)
        event.keyboardGetUnicodeString(maxStringLength: units.count, actualStringLength: &length, unicodeString: &units)
        guard length > 0, length <= units.count else { engine.reset(); return pass }
        let text = String(utf16CodeUnits: units, count: length)
        guard text.count == 1, let character = text.first,
              let ascii = character.asciiValue else { engine.reset(); return pass }
        if (65...90).contains(ascii) || (97...122).contains(ascii) || (48...57).contains(ascii) {
            let edit = engine.process(character)
            if edit.deleteCount == 0 && edit.insertText == text { return pass }
            post(edit, proxy: proxy)
            consumedKeys.insert(key)
            return nil
        }
        if ascii >= 32 && ascii < 127 {
            post(engine.finish(), proxy: proxy)
        } else {
            engine.reset()
        }
        return pass
    }

    private func post(_ edit: TextEdit, proxy: CGEventTapProxy) {
        guard edit.deleteCount > 0 || !edit.insertText.isEmpty else { return }
        for operation in ReplacementPlan.operations(for: edit, protectAutocomplete: protectAutocomplete) {
            switch operation {
            case .backspace:
                postKey(51, down: true, proxy: proxy)
                postKey(51, down: false, proxy: proxy)
            case .selectPreviousCharacter:
                postKey(123, down: true, flags: .maskShift, proxy: proxy)
                postKey(123, down: false, flags: .maskShift, proxy: proxy)
            case .text(let text):
                postText(text, proxy: proxy)
            }
        }
    }

    private func postText(_ text: String, proxy: CGEventTapProxy) {
        let units = Array(text.utf16)
        for down in [true, false] {
            guard let event = CGEvent(keyboardEventSource: eventSource, virtualKey: 0, keyDown: down) else { continue }
            event.flags = .maskNonCoalesced
            event.setIntegerValueField(.eventSourceUserData, value: Self.eventMarker)
            event.keyboardSetUnicodeString(stringLength: units.count, unicodeString: units)
            event.tapPostEvent(proxy)
        }
    }

    private func postKey(_ key: CGKeyCode, down: Bool, flags: CGEventFlags = [], proxy: CGEventTapProxy) {
        guard let event = CGEvent(keyboardEventSource: eventSource, virtualKey: key, keyDown: down) else { return }
        event.flags = flags.union(.maskNonCoalesced)
        event.setIntegerValueField(.eventSourceUserData, value: Self.eventMarker)
        event.tapPostEvent(proxy)
    }
}
