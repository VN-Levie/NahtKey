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
    @Published private(set) var preferences: KeyboardPreferences

    private let engine = TypingSession()
    private var allCorrections: [String: String] = [:]
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private var permissionTimer: Timer?
    private var workspaceObserver: NSObjectProtocol?
    private var lastInputPID: pid_t?
    private let ownBundleID = Bundle.main.bundleIdentifier ?? "vn.nahtkey.mac"
    private let eventSource = KeyboardController.makeEventSource()
    private var commitSpaceAsText = false
    private var isSafariAddressField = false
    private var safariWordHadRewrite = false
    private var resyncAfterSafariBackspace = false
    private var trustedSafariTail = false
    private var keyDelivery = KeyDeliveryState()
    private var focusObserver: AXObserver?
    private var focusApplication: AXUIElement?
    private var focusedElement: AXUIElement?
    private var secureFocus = false
    private var wantsEnabled = true
    private var applicationState: ApplicationTypingState
    private var toggleGesture = ModifierToggleState()
    private static let eventMarker: Int64 = 0x4E4148544B4559

    init() {
        preferences = KeyboardPreferences.load(from: .standard)
        applicationState = ApplicationTypingState(
            globalEnabled: UserDefaults.standard.object(forKey: "typingEnabled") as? Bool ?? true,
            applications: UserDefaults.standard.dictionary(forKey: "applicationTypingEnabled") as? [String: Bool] ?? [:])
        engine.options = preferences.typing
        wantsEnabled = applicationState.globalEnabled
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
        allCorrections = corrections
        resetComposition()
        engine.corrections = DictionaryStore.activeCorrections(corrections, expandPhrases: preferences.expandPhrases)
    }

    func updatePreferences(_ change: (inout KeyboardPreferences) -> Void) {
        var updated = preferences
        change(&updated)
        guard updated != preferences else { return }
        preferences = updated
        updated.save(to: .standard)
        engine.options = updated.typing
        engine.corrections = DictionaryStore.activeCorrections(allCorrections, expandPhrases: updated.expandPhrases)
        resetComposition()
        toggleGesture.reset()
        applyDesiredEnabledState()
    }

    func clearApplicationPreferences() {
        applicationState.clearApplications()
        UserDefaults.standard.removeObject(forKey: "applicationTypingEnabled")
        applyDesiredEnabledState()
    }

    private func applyDesiredEnabledState() {
        let desired = applicationState.desiredEnabled(rememberPerApplication: preferences.rememberPerApplication)
        wantsEnabled = desired
        guard desired != isEnabled else { return }
        if desired { start(refresh: false) } else { stop() }
    }

    func refreshEnvironment() {
        let previouslyPermitted = hasPermission
        hasPermission = AXIsProcessTrusted()
        _ = currentInputApplication()
        if IsSecureEventInputEnabled() { resetComposition(); keyDelivery.reset(); toggleGesture.reset() }
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
        applicationState.setEnabled(enabled, rememberPerApplication: preferences.rememberPerApplication)
        UserDefaults.standard.set(applicationState.globalEnabled, forKey: "typingEnabled")
        UserDefaults.standard.set(applicationState.applications, forKey: "applicationTypingEnabled")
        wantsEnabled = enabled
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

    private func resetComposition() {
        engine.reset()
        safariWordHadRewrite = false
        resyncAfterSafariBackspace = false
        trustedSafariTail = false
    }

    private func currentInputApplication() -> NSRunningApplication? {
        let app = NSWorkspace.shared.frontmostApplication
        if lastInputPID != app?.processIdentifier {
            resetComposition()
            lastInputPID = app?.processIdentifier
            watchFocus(of: app)
            applicationState.activate(app?.bundleIdentifier, ownBundleID: ownBundleID)
            applyDesiredEnabledState()
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
        isSafariAddressField = false
        secureFocus = false
        guard hasPermission, let app else { return }
        let application = AXUIElementCreateApplication(app.processIdentifier)
        AXUIElementSetMessagingTimeout(application, app.bundleIdentifier == SafariAddressBarContext.safariBundleIdentifier
            ? SafariAddressBarContext.messagingTimeout : 0.03)
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
        let wasSafariAddressField = isSafariAddressField
        isSafariAddressField = false
        guard let application = focusApplication else { return }
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(application, kAXFocusedUIElementAttribute as CFString, &value) == .success,
              let value, CFGetTypeID(value) == AXUIElementGetTypeID() else {
            focusedElement = nil
            if wasSafariAddressField { resetComposition() }
            return
        }
        // ARIA comboboxes can report their active result as AX focus while
        // keyboard input still belongs to the owning field. Normalize that
        // relationship before deciding whether composition moved to another field.
        let element = TextInputFocus.resolve(observed: value as! AXUIElement, previous: focusedElement)
        if let previous = focusedElement, !CFEqual(previous, element) {
            resetComposition()
        }
        focusedElement = element
        var subrole: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXSubroleAttribute as CFString, &subrole)
        var protected: CFTypeRef?
        AXUIElementCopyAttributeValue(element, "AXProtectedContent" as CFString, &protected)
        secureFocus = (subrole as? String) == kAXSecureTextFieldSubrole as String || (protected as? Bool) == true
        if secureFocus { resetComposition(); keyDelivery.reset() }
        if !secureFocus, let pid = lastInputPID {
            isSafariAddressField = SafariAddressBarContext.identifies(element: element,
                bundleID: NSRunningApplication(processIdentifier: pid)?.bundleIdentifier ?? "")
        }
    }

    private func start(refresh: Bool = true, activate: Bool = true) {
        if refresh { refreshEnvironment() }
        guard hasPermission else {
            errorMessage = "Cấp quyền Trợ năng cho NahtKey để bật bộ gõ."
            return
        }
        if let tap {
            resetComposition()
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
        resetComposition()
    }

    private func stop() {
        // Keep the lightweight modifier listener alive so Ctrl+Shift can enable
        // typing again. Off-mode events are returned before reading text content.
        if let tap { CGEvent.tapEnable(tap: tap, enable: hasPermission) }
        resetComposition()
        isEnabled = false
        keyDelivery.reset()
        errorMessage = nil
    }

    private func handle(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        let pass = Unmanaged.passUnretained(event)
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            resetComposition()
            keyDelivery.reset()
            toggleGesture.reset()
            if hasPermission, let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return pass
        }
        guard event.getIntegerValueField(.eventSourceUserData) != Self.eventMarker else { return pass }
        if IsSecureEventInputEnabled() {
            resetComposition()
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
            if toggleGesture.flagsChanged(event.flags, shortcut: preferences.toggleShortcut) {
                resetComposition()
                toggle()
            }
        } else if type == .keyDown || type == .leftMouseDown || type == .rightMouseDown
                    || type == .leftMouseDragged || type == .rightMouseDragged {
            // Only invalidate an active modifier gesture; ordinary typing must
            // not require an extra failed Ctrl+Shift before the next toggle.
            toggleGesture.usedOtherInput(flags: event.flags)
        }
        let activeApp = type == .keyDown ? currentInputApplication() : nil
        guard isEnabled else { return pass }
        let key = event.getIntegerValueField(.keyboardEventKeycode)
        // Refresh process/focus before consulting secureFocus, which belongs to
        // the previously watched application until this transition is handled.
        // Password entry is owned by macOS; discard any partially composed word.
        guard !IsSecureEventInputEnabled(), !secureFocus else { resetComposition(); return pass }
        if type == .leftMouseDown || type == .rightMouseDown || type == .leftMouseDragged || type == .rightMouseDragged {
            resetComposition(); return pass
        }
        let flags = event.flags
        if type == .flagsChanged {
            if !flags.intersection([.maskCommand, .maskControl, .maskAlternate]).isEmpty { resetComposition() }
            return pass
        }
        guard type == .keyDown else { return pass }
        // NahtKey's editing fields and lab compose locally with the same engine.
        guard let activeApp, activeApp.bundleIdentifier != ownBundleID else {
            resetComposition()
            return pass
        }
        commitSpaceAsText = ReplacementPlan.commitsSpaceAsText(bundleID: activeApp.bundleIdentifier ?? "")
        guard flags.intersection([.maskCommand, .maskControl, .maskAlternate]).isEmpty else {
            resetComposition()
            return pass
        }
        if activeApp.bundleIdentifier == SafariAddressBarContext.safariBundleIdentifier {
            // Cmd+L and Safari type-ahead can change the field before its AX
            // notification arrives. Refresh at the start of a word, not on every
            // ordinary letter. Backspace needs the current native selection.
            if engine.rendered.isEmpty || key == 51 { refreshFocusedElement() }
            if engine.rendered.isEmpty {
                // Establish a tail caret before forwarding the first native
                // letter. Printable keys and our own replacements keep it at
                // the tail even while Safari's AX selection lags behind.
                let context = currentSafariAddressContext()
                trustedSafariTail = context?.isAtTail == true && context?.selection.length == 0
            }
            guard !secureFocus else { resetComposition(); return pass }
        }
        if key == 51 { // Physical Backspace removes a visible grapheme, not one raw VNI digit.
            let previousWord = engine.rendered
            let context = currentSafariAddressContext()
            let clearingCompletion = context?.isAtTail == true
                && (context?.selection.length ?? 0) > 0
                && focusedElement.map {
                    CaretWordReader.hasInlineCompletion(after: previousWord, in: $0,
                        messagingTimeout: SafariAddressBarContext.messagingTimeout)
                } == true
            if isSafariAddressField && !safariWordHadRewrite && !previousWord.isEmpty && !clearingCompletion {
                // Native type-ahead may appear after the AX snapshot, just
                // before this Backspace is delivered. Let Safari decide what
                // it deletes, then recover the visible word on the next key.
                resetComposition()
                resyncAfterSafariBackspace = true
                return pass
            }
            guard let edit = Self.backspaceEdit(in: engine, clearingInlineCompletion: clearingCompletion) else { return pass }
            safariWordHadRewrite = true
            if edit.deleteCount == 1 && edit.insertText.isEmpty { return pass }
            if edit.deleteCount == 0 && edit.insertText.isEmpty { return pass }
            guard post(edit, proxy: proxy, previousWord: previousWord) else { resetComposition(); return pass }
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
                else { resetComposition(); return pass }
                return nil
            }
            if !post(edit, proxy: proxy, previousWord: previousWord) { resetComposition() }
            if key != 49 { resetComposition() } // Return/Tab may submit or move to another field.
            return pass
        }
        if key == 53, preferences.restoreWithEscape {
            let previousWord = engine.rendered
            if let edit = engine.restoreRaw() {
                guard post(edit, proxy: proxy, previousWord: previousWord) else { resetComposition(); return pass }
                return nil
            }
        }
        if [53, 115, 116, 117, 119, 121, 123, 124, 125, 126].contains(key) {
            resetComposition()
            return pass
        }
        var length = 0
        var units = [UniChar](repeating: 0, count: 8)
        event.keyboardGetUnicodeString(maxStringLength: units.count, actualStringLength: &length, unicodeString: &units)
        guard length > 0, length <= units.count else { resetComposition(); return pass }
        let text = String(utf16CodeUnits: units, count: length)
        guard text.count == 1, let character = text.first,
              let ascii = character.asciiValue else { resetComposition(); return pass }
        if (65...90).contains(ascii) || (97...122).contains(ascii) || (48...57).contains(ascii) {
            if engine.rendered.isEmpty { safariWordHadRewrite = false }
            guard resumeWordIfNeeded(for: character) else { return pass }
            let previousWord = engine.rendered
            let edit = engine.process(character)
            safariWordHadRewrite = safariWordHadRewrite || edit.deleteCount > 0
            if edit.deleteCount == 0 && edit.insertText == text { return pass }
            guard post(edit, proxy: proxy, previousWord: previousWord) else { resetComposition(); return pass }
            return nil
        }
        if ascii >= 32 && ascii < 127 {
            let previousWord = engine.rendered
            if !post(engine.finish(boundary: character), proxy: proxy, previousWord: previousWord) { resetComposition() }
        } else {
            resetComposition()
        }
        return pass
    }

    private func resumeWordIfNeeded(for character: Character) -> Bool {
        guard engine.rendered.isEmpty else { return true }
        let mustResync = resyncAfterSafariBackspace
        let modifiers = inputMethod == .vni ? "0123456789" : "sfrxjzaweod"
        guard mustResync || modifiers.contains(String(character).lowercased()),
              !IsSecureEventInputEnabled() else { return true }
        refreshFocusedElement()
        guard !secureFocus, let focusedElement else {
            if mustResync && !secureFocus { resyncAfterSafariBackspace = true }
            return !mustResync
        }
        if mustResync && !isSafariAddressField {
            resyncAfterSafariBackspace = false
            return false
        }
        let word = CaretWordReader.word(beforeCaretIn: focusedElement,
            messagingTimeout: isSafariAddressField ? SafariAddressBarContext.messagingTimeout : 0.02)
        if mustResync && isSafariAddressField {
            let ready = Self.restoreAfterUncertainBackspace(in: engine, word: word)
            resyncAfterSafariBackspace = !ready
            if ready { safariWordHadRewrite = true }
            // If AX still cannot answer, forward this native key without
            // starting a partial word; retry with visible text on the next key.
            return ready
        }
        if let word {
            engine.resume(word)
            safariWordHadRewrite = true // Resumed text has no known delivery history.
        }
        return true
    }

    static func restoreAfterUncertainBackspace(in session: TypingSession, word: String?) -> Bool {
        if let word { session.resume(word); return true }
        return false
    }

    static func backspaceEdit(in session: TypingSession, clearingInlineCompletion: Bool) -> TextEdit? {
        // Safari's native Backspace removes only the selected suggestion. The
        // tracked word and its history must remain intact for the next modifier.
        clearingInlineCompletion ? nil : session.backspace()
    }

    private func currentSafariAddressContext() -> SafariAddressBarContext? {
        guard isSafariAddressField, !secureFocus, let focusedElement else { return nil }
        return SafariAddressBarContext.readSelection(inVerifiedAddressField: focusedElement)
    }

    private func cachedSafariFocusIsCurrent() -> Bool {
        guard isSafariAddressField, let application = focusApplication, let focusedElement else { return false }
        var value: CFTypeRef?
        let focusResult = AXUIElementCopyAttributeValue(application, kAXFocusedUIElementAttribute as CFString, &value)
        guard focusResult == .success,
              let value, CFGetTypeID(value) == AXUIElementGetTypeID(),
              CFEqual(value, focusedElement) else {
            isSafariAddressField = false
            self.focusedElement = nil
            return false
        }
        return true
    }

    private func post(_ edit: TextEdit, proxy: CGEventTapProxy, previousWord: String = "") -> Bool {
        guard edit.deleteCount > 0 || !edit.insertText.isEmpty else { return true }
        // Never use a cached address-field classification after an undelivered
        // focus notification. Abort the replacement before posting any deletion.
        if isSafariAddressField && !cachedSafariFocusIsCurrent() { return false }
        // Mouse/navigation/modifier/focus changes clear this proof together
        // with composition. Do not re-decide it from a lagging AX range.
        let ownsSafariTail = isSafariAddressField && trustedSafariTail
        let context = edit.deleteCount > 0 && !ownsSafariTail ? currentSafariAddressContext() : nil
        let needsCompletionCheck = !ownsSafariTail && (context.map { $0.selection.length > 0 } ?? true)
        let clearCompletion = needsCompletionCheck && commitSpaceAsText && edit.deleteCount > 0 && !edit.insertText.isEmpty
            && !secureFocus && focusedElement.map {
                CaretWordReader.hasInlineCompletion(after: previousWord, in: $0,
                    allowingPendingPrefix: context?.isAtTail == true,
                    messagingTimeout: isSafariAddressField ? SafariAddressBarContext.messagingTimeout : 0.02)
            } == true
        let prepareSafariTail = ownsSafariTail || context?.permitsCompletionClearing(verifiedInlineCompletion: clearCompletion) == true
        let operations = ReplacementPlan.operations(for: edit, clearInlineCompletion: clearCompletion,
                                                    prepareSafariTail: prepareSafariTail)
        guard let events = KeyboardEventBatch.make(operations, source: eventSource, marker: Self.eventMarker,
                                                   isPhysicallyDown: { key in
            self.keyDelivery.hasForwardedDown(key) || CGEventSource.keyState(.hidSystemState, key: key)
        })
        else { return false }
        for event in events { event.tapPostEvent(proxy) }
        return true
    }
}
