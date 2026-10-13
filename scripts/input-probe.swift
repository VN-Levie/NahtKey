// Development-only fixture. Records only events delivered to its own test field.
// No global monitor, persistence, clipboard access, or network traffic.
import AppKit

final class ProbeView: NSTextView {
    var logEvent: ((String) -> Void)?
    override func keyDown(with event: NSEvent) {
        let cg = event.cgEvent
        let marker = cg?.getIntegerValueField(.eventSourceUserData) ?? 0
        logEvent?("↓ key=\(event.keyCode) chars=\(String(reflecting: event.characters ?? "")) marker=\(marker)")
        super.keyDown(with: event)
        logEvent?("  value=\(String(reflecting: string)) cursor=\(selectedRange())")
    }
    override func keyUp(with event: NSEvent) {
        logEvent?("↑ key=\(event.keyCode)")
        super.keyUp(with: event)
    }
}
final class ProbeDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    var events: [String] = []
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
    func applicationDidFinishLaunching(_ note: Notification) {
        window = NSWindow(contentRect: NSRect(x: 140, y: 160, width: 900, height: 600), styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
        window.title = "NahtKey — Input Probe"
        let root = NSView(frame: NSRect(x: 0, y: 0, width: 900, height: 600))
        window.contentView = root
        let label = NSTextField(labelWithString: "Ô thử riêng: mua7, mu7a, chua7, chu7a. Chỉ ghi sự kiện của ô này, không ghi bàn phím nơi khác.")
        label.frame = NSRect(x: 20, y: 562, width: 860, height: 24); root.addSubview(label)
        let input = ProbeView(frame: NSRect(x: 20, y: 414, width: 860, height: 138))
        input.font = .systemFont(ofSize: 24); input.isRichText = false
        input.isAutomaticTextReplacementEnabled = false; input.isAutomaticSpellingCorrectionEnabled = false
        input.setAccessibilityIdentifier("nahtkey-probe-input")
        input.setAccessibilityLabel("Ô gõ kiểm thử")
        root.addSubview(input)
        let log = NSTextView(frame: NSRect(x: 20, y: 20, width: 860, height: 378))
        log.font = .monospacedSystemFont(ofSize: 12, weight: .regular); log.isEditable = false
        log.setAccessibilityLabel("Sự kiện kiểm thử")
        let logScroll = NSScrollView(frame: NSRect(x: 20, y: 20, width: 860, height: 378))
        logScroll.hasVerticalScroller = true
        logScroll.documentView = log
        root.addSubview(logScroll)
        input.logEvent = { [weak self, weak log] line in
            guard let self, let log else { return }
            self.events.append(line)
            if self.events.count > 80 { self.events.removeFirst(self.events.count - 80) }
            log.string = self.events.joined(separator: "\n")
        }
        window.makeKeyAndOrderFront(nil); window.makeFirstResponder(input)
        NSApp.activate(ignoringOtherApps: true)
    }
}
let app = NSApplication.shared
app.setActivationPolicy(.regular)
let delegate = ProbeDelegate(); app.delegate = delegate
app.run()
