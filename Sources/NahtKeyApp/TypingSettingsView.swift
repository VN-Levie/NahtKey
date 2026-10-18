import SwiftUI
import NahtKeyCore

struct TypingSettingsView: View {
    @ObservedObject var keyboard: KeyboardController

    private func binding<Value>(_ keyPath: WritableKeyPath<KeyboardPreferences, Value>) -> Binding<Value> {
        Binding(get: { keyboard.preferences[keyPath: keyPath] },
                set: { value in keyboard.updatePreferences { $0[keyPath: keyPath] = value } })
    }

    var body: some View {
        Form {
            Section("Gõ và sửa dấu") {
                Toggle("Chỉnh lại vị trí dấu khi xóa chữ", isOn: binding(\.typing.normalizeToneOnBackspace))
                Picker("Cách đặt dấu", selection: binding(\.typing.tonePlacement)) {
                    ForEach(TonePlacement.allCases) { placement in
                        Text(placement.displayName).tag(placement)
                    }
                }
                Toggle("Khôi phục tiếng Anh và mã khi gõ Telex", isOn: binding(\.typing.restoreEnglishTelex))
                Text("Chỉ áp dụng cho Telex. Từ có thể hiểu là tiếng Việt vẫn giữ dấu.")
                    .font(.caption).foregroundStyle(.secondary)
                Toggle("Esc khôi phục chuỗi phím của từ đang gõ", isOn: binding(\.restoreWithEscape))
                Text("Dùng trước khi kết thúc từ. Esc tiếp theo vẫn thực hiện thao tác của ứng dụng.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("Ứng dụng") {
                Toggle("Nhớ bật/tắt tiếng Việt theo ứng dụng", isOn: binding(\.rememberPerApplication))
                Text("Tắt tùy chọn này để dùng một trạng thái chung. Kiểu gõ VNI/Telex luôn dùng chung.")
                    .font(.caption).foregroundStyle(.secondary)
                Button("Xóa trạng thái đã nhớ") { keyboard.clearApplicationPreferences() }
                    .disabled(!keyboard.preferences.rememberPerApplication)
            }
            Section("Thư viện và phím tắt") {
                Toggle("Gõ tắt thành cụm từ hoặc câu", isOn: binding(\.expandPhrases))
                Text("Các quy tắc thay một từ vẫn hoạt động khi tắt tùy chọn này.")
                    .font(.caption).foregroundStyle(.secondary)
                Picker("Bật/tắt tiếng Việt", selection: binding(\.toggleShortcut)) {
                    ForEach(ToggleShortcut.allCases) { shortcut in
                        Text(shortcut.displayName).tag(shortcut)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding(12)
    }
}
