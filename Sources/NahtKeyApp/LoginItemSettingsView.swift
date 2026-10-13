import SwiftUI

struct LoginItemSettingsView: View {
    @ObservedObject var controller: LoginItemController

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Toggle("Khởi động cùng macOS", isOn: Binding(
                    get: { controller.isEnabled }, set: controller.setEnabled
                ))
                .toggleStyle(.switch)
                .controlSize(.small)
                .fixedSize()
                .accessibilityIdentifier("launch-at-login-toggle")
                Spacer(minLength: 8)
                if controller.requiresApproval {
                    Button("Mở cài đặt") { controller.openSettings() }
                        .controlSize(.small)
                }
            }
            if let message = controller.statusMessage {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let error = controller.errorMessage {
                Text(error)
                    .font(.callout)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
            }
        }
    }
}
