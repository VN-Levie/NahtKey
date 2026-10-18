import CoreGraphics

/// One toggle on release of a clean selected modifier gesture. No characters are stored.
struct ModifierToggleState {
    private var armed = false
    private var blocked = false

    mutating func flagsChanged(_ flags: CGEventFlags, shortcut: ToggleShortcut = .controlShift) -> Bool {
        let chord: CGEventFlags
        switch shortcut {
        case .controlShift: chord = [.maskControl, .maskShift]
        case .commandShift: chord = [.maskCommand, .maskShift]
        case .controlOption: chord = [.maskControl, .maskAlternate]
        case .disabled: reset(); return false
        }
        let held = flags.intersection(chord)
        let modifiers: CGEventFlags = [.maskControl, .maskShift, .maskCommand, .maskAlternate, .maskSecondaryFn]
        let extra = !flags.intersection(modifiers.subtracting(chord)).isEmpty
        if extra {
            armed = false
            blocked = true
            return false
        }
        if held.isEmpty {
            let shouldToggle = armed && !blocked
            reset()
            return shouldToggle
        }
        if held == chord {
            if !blocked { armed = true }
            return false
        }
        if armed && !blocked {
            armed = false
            blocked = true // Require release of both modifiers before rearming.
            return true
        }
        return false
    }

    mutating func usedOtherInput(flags: CGEventFlags) {
        guard !flags.intersection([.maskControl, .maskShift, .maskCommand, .maskAlternate, .maskSecondaryFn]).isEmpty else { return }
        armed = false
        blocked = true
    }

    mutating func reset() {
        armed = false
        blocked = false
    }
}
