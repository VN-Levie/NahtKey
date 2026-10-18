import ApplicationServices
import Foundation

/// Chromium can expose the selected suggestion as AX focus while DOM focus and
/// keyboard input remain in its combobox. Resolve that explicit ownership only;
/// labels, field values and the contents of suggestions are never inspected.
enum TextInputFocus {
    struct Metadata {
        var role: String
        var subrole: String = ""
        var protectedContent = false
        var expanded = false
        var editable = false

        var isProtected: Bool {
            protectedContent || subrole == (kAXSecureTextFieldSubrole as String)
                || role == "AXSecureTextField"
        }

        var isTextInput: Bool {
            [kAXTextFieldRole as String, kAXTextAreaRole as String,
             kAXComboBoxRole as String, "AXSecureTextField"].contains(role)
        }

        var isBoundary: Bool {
            ["AXWebArea", kAXWindowRole as String, kAXApplicationRole as String,
             kAXSystemWideRole as String].contains(role)
        }

        var isOwner: Bool {
            role == (kAXComboBoxRole as String) && editable && expanded && !isProtected
        }
    }

    /// An injectable metadata graph keeps ownership, ambiguity and bounds tests
    /// independent of a running browser and Accessibility permission.
    struct Graph<Element> {
        var same: (Element, Element) -> Bool
        var metadata: (Element) -> Metadata?
        var parent: (Element) -> Element?
        var children: (Element, Int) -> [Element]?
        var owns: (Element, Int) -> [Element]?
        var withinBudget: () -> Bool = { true }
    }

    static func resolve(observed: AXUIElement, previous: AXUIElement?) -> AXUIElement {
        let reader = AccessibilityReader()
        return resolve(observed: observed, previous: previous, graph: Graph(
            same: { CFEqual($0, $1) }, metadata: reader.metadata,
            parent: reader.parent, children: reader.children, owns: reader.owns,
            withinBudget: { reader.withinBudget }
        ))
    }

    static func resolve<Element>(observed: Element, previous: Element?, graph: Graph<Element>,
                                 maximumParents: Int = 6, maximumNodes: Int = 64) -> Element {
        var snapshots: [(Element, Metadata)] = []
        func metadata(_ element: Element) -> Metadata? {
            if let cached = snapshots.first(where: { graph.same($0.0, element) }) { return cached.1 }
            guard snapshots.count < maximumNodes, graph.withinBudget(),
                  let value = graph.metadata(element) else { return nil }
            snapshots.append((element, value))
            return value
        }
        guard let initial = metadata(observed), !initial.isTextInput, !initial.isProtected,
              !initial.isBoundary else { return observed }

        var ancestors = [observed]
        var current = observed
        for _ in 0..<max(0, maximumParents) {
            guard graph.withinBudget(), let parent = graph.parent(current),
                  !ancestors.contains(where: { graph.same($0, parent) }),
                  let parentInfo = metadata(parent), !parentInfo.isProtected,
                  !parentInfo.isTextInput, !parentInfo.isBoundary else { return observed }
            ancestors.append(parent)
            current = parent

            // The combobox is outside its suggestion list. Do not enumerate
            // suggestion rows, nor re-enter the descendant branch just climbed.
            if parentInfo.role == (kAXListRole as String) { continue }
            var queue = [parent]
            var visited: [Element] = []
            var candidates: [Element] = []
            while !queue.isEmpty {
                let node = queue.removeFirst()
                if visited.contains(where: { graph.same($0, node) }) { continue }
                visited.append(node)
                guard let info = metadata(node), graph.withinBudget() else { return observed }
                if info.isProtected || info.isBoundary { continue }
                if info.isOwner {
                    guard let owned = graph.owns(node, maximumNodes) else { return observed }
                    if owned.contains(where: { owner in ancestors.contains { graph.same(owner, $0) } }) {
                        candidates.append(node)
                        if candidates.count > 1 { return observed }
                    }
                }
                if info.isTextInput || info.role == (kAXListRole as String) { continue }
                guard let children = graph.children(node, maximumNodes) else { return observed }
                for child in children where !ancestors.dropLast().contains(where: { graph.same($0, child) }) {
                    if !visited.contains(where: { graph.same($0, child) })
                        && !queue.contains(where: { graph.same($0, child) }) {
                        guard visited.count + queue.count < maximumNodes else { return observed }
                        queue.append(child)
                    }
                }
                // Prior focus is a traversal hint, never proof of uniqueness.
                // Still inspect the whole scope before returning any owner.
                if let previous, let index = queue.firstIndex(where: { graph.same($0, previous) }) {
                    queue.insert(queue.remove(at: index), at: 0)
                }
            }
            // Complete the nearest common-ancestor scope before accepting one
            // owner, so sibling comboboxes with ambiguous AXOwns fail closed.
            if let candidate = candidates.first, graph.withinBudget() { return candidate }
        }
        return observed
    }

    private final class AccessibilityReader {
        private let deadline = ProcessInfo.processInfo.systemUptime + 0.04
        private var reads = 0
        var withinBudget: Bool { reads < 192 && ProcessInfo.processInfo.systemUptime < deadline }

        private func prepare(_ element: AXUIElement) -> Bool {
            let remaining = deadline - ProcessInfo.processInfo.systemUptime
            guard reads < 192, remaining > 0 else { return false }
            reads += 1
            let timeout = max(Float.leastNonzeroMagnitude, Float(min(0.01, remaining)))
            AXUIElementSetMessagingTimeout(element, timeout)
            return true
        }

        func metadata(_ element: AXUIElement) -> Metadata? {
            guard prepare(element) else { return nil }
            // Character counts/ranges on result rows can require Chromium to
            // traverse an entire changing result tree. Only the combobox needs
            // that metadata; inspecting suggestions must not stall input.
            let names = [kAXRoleAttribute, kAXSubroleAttribute, "AXProtectedContent"]
            var values: CFArray?
            guard AXUIElementCopyMultipleAttributeValues(element, names as CFArray,
                    AXCopyMultipleAttributeOptions(rawValue: 0), &values) == .success,
                  let values = values as? [AnyObject], values.count == names.count,
                  let role = values[0] as? String else { return nil }
            var metadata = Metadata(role: role, subrole: values[1] as? String ?? "",
                                    protectedContent: values[2] as? Bool == true)
            guard role == kAXComboBoxRole as String, !metadata.isProtected else { return metadata }
            guard prepare(element) else { return nil }
            let inputNames = [kAXExpandedAttribute, kAXSelectedTextRangeAttribute, kAXNumberOfCharactersAttribute]
            var inputValues: CFArray?
            guard AXUIElementCopyMultipleAttributeValues(element, inputNames as CFArray,
                    AXCopyMultipleAttributeOptions(rawValue: 0), &inputValues) == .success,
                  let inputValues = inputValues as? [AnyObject], inputValues.count == inputNames.count else { return nil }
            metadata.expanded = inputValues[0] as? Bool == true
            metadata.editable = CFGetTypeID(inputValues[1]) == AXValueGetTypeID()
                && AXValueGetType(inputValues[1] as! AXValue) == .cfRange
                && (inputValues[2] as? NSNumber).map { $0.intValue >= 0 } == true
            return metadata
        }

        func parent(_ element: AXUIElement) -> AXUIElement? {
            guard prepare(element) else { return nil }
            var value: CFTypeRef?
            guard AXUIElementCopyAttributeValue(element, kAXParentAttribute as CFString, &value) == .success,
                  let value, CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
            return (value as! AXUIElement)
        }

        func children(_ element: AXUIElement, limit: Int) -> [AXUIElement]? {
            elements(kAXChildrenAttribute, of: element, limit: limit)
        }

        func owns(_ element: AXUIElement, limit: Int) -> [AXUIElement]? {
            elements("AXOwns", of: element, limit: limit)
        }

        private func elements(_ name: String, of element: AXUIElement, limit: Int) -> [AXUIElement]? {
            guard prepare(element) else { return nil }
            var count: CFIndex = 0
            let result = AXUIElementGetAttributeValueCount(element, name as CFString, &count)
            if result == .attributeUnsupported || result == .noValue { return [] }
            guard result == .success, count >= 0, count <= limit else { return nil }
            if count == 0 { return [] }
            guard prepare(element) else { return nil }
            var values: CFArray?
            guard AXUIElementCopyAttributeValues(element, name as CFString, 0, count, &values) == .success,
                  let values = values as? [AnyObject], values.count == count,
                  values.allSatisfy({ CFGetTypeID($0) == AXUIElementGetTypeID() }) else { return nil }
            return values.map { $0 as! AXUIElement }
        }
    }
}
