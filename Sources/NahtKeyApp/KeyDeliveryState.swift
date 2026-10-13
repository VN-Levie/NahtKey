import CoreGraphics

/// Delivery belongs to a physical press, not just its latest repeat. Once any
/// down reaches the target, its eventual up must reach the target as well.
struct KeyDeliveryState {
    private enum Delivery { case consumedOnly, forwarded }
    private var presses: [CGKeyCode: Delivery] = [:]

    mutating func recordDown(_ key: CGKeyCode, forwarded: Bool) {
        if forwarded {
            presses[key] = .forwarded
        } else if presses[key] == nil {
            presses[key] = .consumedOnly
        }
    }

    mutating func release(_ key: CGKeyCode) -> Bool {
        presses.removeValue(forKey: key) != .consumedOnly
    }

    func hasForwardedDown(_ key: CGKeyCode) -> Bool { presses[key] == .forwarded }

    mutating func reset() { presses.removeAll(keepingCapacity: true) }
}
