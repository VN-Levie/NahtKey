import AppKit
import Carbon

enum StartupPolicy {
    static func isLoginEvent(_ event: NSAppleEventDescriptor?) -> Bool {
        guard let event, event.eventClass == AEEventClass(kCoreEventClass),
              event.eventID == AEEventID(kAEOpenApplication) else { return false }
        return event.paramDescriptor(forKeyword: AEKeyword(keyAEPropData))?.enumCodeValue
            == OSType(keyAELaunchedAsLogInItem)
    }

    static func isBackgroundLaunch(event: NSAppleEventDescriptor?, arguments: [String]) -> Bool {
        arguments.contains("--background") || isLoginEvent(event)
    }
}
