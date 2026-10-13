import Carbon
import CoreGraphics

/// Unicode still rides on a virtual-key down/up pair. Reusing a physically held
/// key can lose the synthetic down in the target, even with a private CG source.
enum KeyboardEventBatch {
    private static let textKeys: [CGKeyCode] = [
        kVK_ANSI_A, kVK_ANSI_B, kVK_ANSI_C, kVK_ANSI_D, kVK_ANSI_E,
        kVK_ANSI_F, kVK_ANSI_G, kVK_ANSI_H, kVK_ANSI_I, kVK_ANSI_J,
        kVK_ANSI_K, kVK_ANSI_L, kVK_ANSI_M, kVK_ANSI_N, kVK_ANSI_O,
        kVK_ANSI_P, kVK_ANSI_Q, kVK_ANSI_R, kVK_ANSI_S, kVK_ANSI_T,
        kVK_ANSI_U, kVK_ANSI_V, kVK_ANSI_W, kVK_ANSI_X, kVK_ANSI_Y, kVK_ANSI_Z
    ].map(CGKeyCode.init)

    static func make(_ operations: [ReplacementOperation], source: CGEventSource?, marker: Int64,
                     isPhysicallyDown: (CGKeyCode) -> Bool = {
                         CGEventSource.keyState(.hidSystemState, key: $0)
                     }) -> [CGEvent]? {
        let hasText = operations.contains { if case .text = $0 { return true }; return false }
        let carrier = hasText ? textKeys.first(where: { !isPhysicallyDown($0) }) : nil
        guard !hasText || carrier != nil else { return nil }

        // Construct the entire burst before posting any deletion. A failed
        // allocation/carrier selection must not leave a half-applied edit.
        var events: [CGEvent] = []
        for operation in operations {
            let key: CGKeyCode
            let text: String?
            switch operation {
            case .backspace: key = CGKeyCode(kVK_Delete); text = nil
            case .text(let value): key = carrier!; text = value
            }
            for down in [true, false] {
                guard let event = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: down) else {
                    return nil
                }
                event.flags = .maskNonCoalesced
                event.setIntegerValueField(.eventSourceUserData, value: marker)
                event.setIntegerValueField(.keyboardEventAutorepeat, value: 0)
                if let text {
                    let units = Array(text.utf16)
                    event.keyboardSetUnicodeString(stringLength: units.count, unicodeString: units)
                }
                events.append(event)
            }
        }
        return events
    }
}
