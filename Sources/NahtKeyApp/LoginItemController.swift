import Combine
import Foundation
import ServiceManagement

@MainActor
protocol LoginItemService {
    var status: SMAppService.Status { get }
    func register() throws
    func unregister() throws
    func openSettings()
}

@MainActor
private struct MainAppLoginItemService: LoginItemService {
    var status: SMAppService.Status { SMAppService.mainApp.status }
    func register() throws { try SMAppService.mainApp.register() }
    func unregister() throws { try SMAppService.mainApp.unregister() }
    func openSettings() { SMAppService.openSystemSettingsLoginItems() }
}

/// The system is the source of truth. Creating or refreshing this controller
/// never registers the application or changes the user's login preferences.
@MainActor
final class LoginItemController: ObservableObject {
    @Published private(set) var status: SMAppService.Status = .notRegistered
    @Published private(set) var errorMessage: String?
    private let service: any LoginItemService

    var isEnabled: Bool { status == .enabled || status == .requiresApproval }
    var requiresApproval: Bool { status == .requiresApproval }

    var statusMessage: String? {
        switch status {
        case .enabled, .notRegistered:
            return nil
        case .requiresApproval:
            return "Cần cho phép trong Mục đăng nhập."
        case .notFound:
            return "macOS chưa tìm thấy mục khởi động của NahtKey."
        @unknown default:
            return "Không đọc được trạng thái khởi động cùng macOS."
        }
    }

    init(service: (any LoginItemService)? = nil) {
        self.service = service ?? MainAppLoginItemService()
        refresh()
    }

    func refresh() {
        status = service.status
    }

    func setEnabled(_ enabled: Bool) {
        // A setting may have changed outside NahtKey since the last activation.
        refresh()
        guard enabled != isEnabled else { return }
        defer { refresh() }
        do {
            if enabled {
                try service.register()
            } else {
                try service.unregister()
            }
            errorMessage = nil
        } catch {
            let action = enabled ? "bật" : "tắt"
            errorMessage = "Không thể \(action) khởi động cùng macOS: \(error.localizedDescription)"
        }
    }

    func openSettings() {
        service.openSettings()
    }
}
