import Foundation

/// Only explicit toggles update a profile. Focus changes and permission loss do not.
struct ApplicationTypingState {
    var globalEnabled: Bool
    private(set) var applications: [String: Bool]
    private(set) var activeApplication: String?

    init(globalEnabled: Bool = true, applications: [String: Bool] = [:]) {
        self.globalEnabled = globalEnabled
        self.applications = applications
    }

    mutating func activate(_ bundleID: String?, ownBundleID: String) {
        guard let bundleID, !bundleID.isEmpty, bundleID != ownBundleID else { return }
        activeApplication = bundleID
    }

    func desiredEnabled(rememberPerApplication: Bool) -> Bool {
        guard rememberPerApplication, let activeApplication else { return globalEnabled }
        return applications[activeApplication] ?? globalEnabled
    }

    mutating func setEnabled(_ enabled: Bool, rememberPerApplication: Bool) {
        if rememberPerApplication, let activeApplication {
            applications[activeApplication] = enabled
        } else {
            globalEnabled = enabled
        }
    }

    mutating func clearApplications() { applications.removeAll() }
}
