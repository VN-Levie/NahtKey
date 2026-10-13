import CoreGraphics

/// One toggle on release of a clean Ctrl+Shift gesture. No characters are stored.
struct ModifierToggleState {
    private var armed = false
    private var blocked = false

    mutating func flagsChanged(_ flags: CGEventFlags) -> Bool {
        let chord: CGEventFlags = [.maskControl, .maskShift]
        let held = flags.intersection(chord)
        let extra = !flags.intersection([.maskCommand, .maskAlternate, .maskSecondaryFn]).isEmpty
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
