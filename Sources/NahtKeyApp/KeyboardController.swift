import AppKit
import ApplicationServices
import Carbon
import Combine
import NahtKeyCore

/// The tap runs on the main run loop. No text is logged; bounded Accessibility
/// context is read only when an explicit modifier resumes a word at the caret.
@MainActor
final class KeyboardController: ObservableObject {
    @Published private(set) var isEnabled = false
    @Published private(set) var hasPermission = AXIsProcessTrusted()
    @Published private(set) var otherInputApps: [String] = []
    @Published private(set) var errorMessage: String?
    @Published private(set) var inputMethod: InputMethod = .vni

    private let engine = TypingSession()
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private var permissionTimer: Timer?
    private var workspaceObserver: NSObjectProtocol?
    private var lastInputPID: pid_t?
    private let ownBundleID = Bundle.main.bundleIdentifier ?? "vn.nahtkey.mac"
    private let eventSource = KeyboardController.makeEventSource()
    private var commitSpaceAsText = false
    private var keyDelivery = KeyDeliveryState()
    private var focusObserver: AXObserver?
    private var focusApplication: AXUIElement?
    private var focusedElement: AXUIElement?
    private var secureFocus = false
    private var wantsEnabled = true
    private var toggleGesture = ModifierToggleState()
    private static let eventMarker: Int64 = 0x4E4148544B4559

    init() {
        wantsEnabled = UserDefaults.standard.object(forKey: "typingEnabled") as? Bool ?? true
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
        if wantsEnabled { start() }
        else if hasPermission { start(activate: false) }
    }

    func updateCorrections(_ corrections: [String: String]) {
        engine.reset()
        engine.corrections = corrections
    }

    func refreshEnvironment() {
        let previouslyPermitted = hasPermission
        hasPermission = AXIsProcessTrusted()
        _ = currentInputApplication()
        if IsSecureEventInputEnabled() { engine.reset(); keyDelivery.reset(); toggleGesture.reset() }
        let competitors: Set<String> = ["com.trankynam.GoTiengViet", "com.tuyenmai.openkey", "com.lamquangminh.evkey"]
        otherInputApps = NSWorkspace.shared.runningApplications.compactMap { app in
            guard let id = app.bundleIdentifier else { return nil }
            let name = app.localizedName ?? id
            return competitors.contains(id) || name.lowercased().contains("evkey") ? name : nil
        }.sorted()
        if !hasPermission {
            if let tap { CGEvent.tapEnable(tap: tap, enable: false) }
            if isEnabled { stop() }
        }
        if hasPermission && !previouslyPermitted { start(refresh: false, activate: wantsEnabled) }
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
        wantsEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: "typingEnabled")
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
        var protected: CFTypeRef?
        AXUIElementCopyAttributeValue(element, "AXProtectedContent" as CFString, &protected)
        secureFocus = (subrole as? String) == kAXSecureTextFieldSubrole as String || (protected as? Bool) == true
        if secureFocus { engine.reset(); keyDelivery.reset() }
    }

    private func start(refresh: Bool = true, activate: Bool = true) {
        if refresh { refreshEnvironment() }
        guard hasPermission else {
            errorMessage = "Cấp quyền Trợ năng cho NahtKey để bật bộ gõ."
            return
        }
        if let tap {
            engine.reset()
            keyDelivery.reset()
            CGEvent.tapEnable(tap: tap, enable: true)
            isEnabled = activate
            errorMessage = nil
            return
        }
        let mask = (1 << CGEventType.keyDown.rawValue)
            | (1 << CGEventType.keyUp.rawValue)
            | (1 << CGEventType.flagsChanged.rawValue)
            | (1 << CGEventType.leftMouseDown.rawValue)
            | (1 << CGEventType.rightMouseDown.rawValue)
            | (1 << CGEventType.leftMouseDragged.rawValue)
            | (1 << CGEventType.rightMouseDragged.rawValue)
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
        isEnabled = activate
        errorMessage = nil
        engine.reset()
    }

    private func stop() {
        // Keep the lightweight modifier listener alive so Ctrl+Shift can enable
        // typing again. Off-mode events are returned before reading text content.
        if let tap { CGEvent.tapEnable(tap: tap, enable: hasPermission) }
        engine.reset()
        isEnabled = false
        keyDelivery.reset()
        errorMessage = nil
    }

    private func handle(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        let pass = Unmanaged.passUnretained(event)
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            engine.reset()
            keyDelivery.reset()
            toggleGesture.reset()
            if hasPermission, let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return pass
        }
        guard event.getIntegerValueField(.eventSourceUserData) != Self.eventMarker else { return pass }
        if IsSecureEventInputEnabled() {
            engine.reset()
            keyDelivery.reset()
            toggleGesture.reset()
            return pass
        }
        let key = CGKeyCode(truncatingIfNeeded: event.getIntegerValueField(.keyboardEventKeycode))
        if type == .keyUp {
            return keyDelivery.release(key) ? pass : nil
        }
        let result = handleInput(proxy: proxy, type: type, event: event)
        if type == .keyDown && isEnabled && !secureFocus {
            keyDelivery.recordDown(key, forwarded: result != nil)
        }
        return result
    }

    private func handleInput(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        let pass = Unmanaged.passUnretained(event)
        if type == .flagsChanged {
            if toggleGesture.flagsChanged(event.flags) {
                engine.reset()
                toggle()
            }
        } else if type == .keyDown || type == .leftMouseDown || type == .rightMouseDown
                    || type == .leftMouseDragged || type == .rightMouseDragged {
            // Only invalidate an active modifier gesture; ordinary typing must
            // not require an extra failed Ctrl+Shift before the next toggle.
            toggleGesture.usedOtherInput(flags: event.flags)
        }
        guard isEnabled else { return pass }
        let key = event.getIntegerValueField(.keyboardEventKeycode)
        // Refresh process/focus before consulting secureFocus, which belongs to
        // the previously watched application until this transition is handled.
        let activeApp = type == .keyDown ? currentInputApplication() : nil
        // Password entry is owned by macOS; discard any partially composed word.
        guard !IsSecureEventInputEnabled(), !secureFocus else { engine.reset(); return pass }
        if type == .leftMouseDown || type == .rightMouseDown || type == .leftMouseDragged || type == .rightMouseDragged {
            engine.reset(); return pass
        }
        let flags = event.flags
        if type == .flagsChanged {
            if !flags.intersection([.maskCommand, .maskControl, .maskAlternate]).isEmpty { engine.reset() }
            return pass
        }
        guard type == .keyDown else { return pass }
        // NahtKey's editing fields and lab compose locally with the same engine.
        guard let activeApp, activeApp.bundleIdentifier != ownBundleID else {
            engine.reset()
            return pass
        }
        commitSpaceAsText = ReplacementPlan.commitsSpaceAsText(bundleID: activeApp.bundleIdentifier ?? "")
        guard flags.intersection([.maskCommand, .maskControl, .maskAlternate]).isEmpty else {
            engine.reset()
            return pass
        }
        if key == 51 { // Physical Backspace removes a visible grapheme, not one raw VNI digit.
            let edit = engine.backspace()
            if edit.deleteCount == 1 && edit.insertText.isEmpty { return pass }
            if edit.deleteCount == 0 && edit.insertText.isEmpty { return pass }
            guard post(edit, proxy: proxy) else { engine.reset(); return pass }
            return nil
        }
        if [36, 48, 49, 76].contains(key) { // Return, Tab, Space, keypad Return
            let previousWord = engine.rendered
            let hadWord = !engine.rendered.isEmpty
            let boundary: Character = key == 49 ? " " : (key == 48 ? "\t" : "\n")
            let edit = engine.finish(boundary: boundary)
            if key == 49 && hadWord && (commitSpaceAsText || edit.deleteCount > 0 || !edit.insertText.isEmpty) {
                // Own the completed word AND its space as one text transaction.
                // Do not mix synthetic word replacement with a physical delimiter.
                guard post(ReplacementPlan.committingSpace(after: edit), proxy: proxy, previousWord: previousWord)
                else { engine.reset(); return pass }
                return nil
            }
            if !post(edit, proxy: proxy, previousWord: previousWord) { engine.reset() }
            if key != 49 { engine.reset() } // Return/Tab may submit or move to another field.
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
            resumeWordIfNeeded(for: character)
            let previousWord = engine.rendered
            let edit = engine.process(character)
            if edit.deleteCount == 0 && edit.insertText == text { return pass }
            guard post(edit, proxy: proxy, previousWord: previousWord) else { engine.reset(); return pass }
            return nil
        }
        if ascii >= 32 && ascii < 127 {
            let previousWord = engine.rendered
            if !post(engine.finish(boundary: character), proxy: proxy, previousWord: previousWord) { engine.reset() }
        } else {
            engine.reset()
        }
        return pass
    }

    private func resumeWordIfNeeded(for character: Character) {
        guard engine.rendered.isEmpty else { return }
        let modifiers = inputMethod == .vni ? "0123456789" : "sfrxjzaweod"
        guard modifiers.contains(String(character).lowercased()), !IsSecureEventInputEnabled() else { return }
        refreshFocusedElement()
        guard !secureFocus, let focusedElement,
              let word = CaretWordReader.word(beforeCaretIn: focusedElement) else { return }
        engine.resume(word)
    }

    private func post(_ edit: TextEdit, proxy: CGEventTapProxy, previousWord: String = "") -> Bool {
        guard edit.deleteCount > 0 || !edit.insertText.isEmpty else { return true }
        let clearCompletion = commitSpaceAsText && edit.deleteCount > 0 && !edit.insertText.isEmpty
            && !secureFocus && focusedElement.map {
                CaretWordReader.hasInlineCompletion(after: previousWord, in: $0)
            } == true
        let operations = ReplacementPlan.operations(for: edit, clearInlineCompletion: clearCompletion)
        guard let events = KeyboardEventBatch.make(operations, source: eventSource, marker: Self.eventMarker,
                                                   isPhysicallyDown: { key in
            self.keyDelivery.hasForwardedDown(key) || CGEventSource.keyState(.hidSystemState, key: key)
        })
        else { return false }
        for event in events { event.tapPostEvent(proxy) }
        return true
    }
}
