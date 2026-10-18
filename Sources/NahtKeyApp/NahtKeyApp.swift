import AppKit
import SwiftUI
import NahtKeyCore

@main
enum NahtKeyApp {
    @MainActor static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        let instance = SingleInstanceCoordinator()
        do { try instance.acquire() }
        catch {
            // Fail closed: inability to establish ownership must not create a
            // second event tap. No application services have been initialized.
            let alert = NSAlert()
            alert.messageText = "Không thể khởi động NahtKey"
            alert.informativeText = "Không thể kiểm tra phiên đang chạy. Hãy kiểm tra quyền truy cập thư mục dữ liệu NahtKey rồi mở lại."
            alert.runModal()
            return
        }
        if instance.isPrimary {
            let lifecycle = ApplicationLifecycle()
            instance.handleReopen { [weak lifecycle] in lifecycle?.requestMainWindow() }
            app.delegate = lifecycle
            // SwiftUI renders only an explicitly opened window; no default
            // Window scene can flash at login.
            withExtendedLifetime((instance, lifecycle)) { app.run() }
        } else {
            let lifecycle = DuplicateInstanceLifecycle(instance: instance)
            app.delegate = lifecycle
            withExtendedLifetime((instance, lifecycle)) { app.run() }
        }
    }
}

struct MainView: View {
    @ObservedObject var dictionary: DictionaryStore
    @ObservedObject var keyboard: KeyboardController
    @ObservedObject var loginItem: LoginItemController
    @ObservedObject var navigation: MainWindowNavigation

    private let brandImage = Bundle.main.url(forResource: "NahtKeyIcon", withExtension: "png")
        .flatMap { NSImage(contentsOf: $0) } ?? NSImage(named: "NahtKeyIcon")

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 14) {
                    Group {
                        if let brandImage {
                            Image(nsImage: brandImage).resizable().scaledToFit()
                        } else {
                            Image(systemName: "keyboard.fill")
                                .font(.system(size: 27)).foregroundStyle(.teal)
                        }
                    }
                    .frame(width: 48, height: 48)
                    .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("NahtKey").font(.title2.weight(.semibold))
                        Text("\(keyboard.inputMethod.displayName) \(keyboard.isEnabled ? "đang bật" : "đang tắt")")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Picker("Kiểu gõ", selection: Binding(get: { keyboard.inputMethod }, set: keyboard.setInputMethod)) {
                        Text("VNI").tag(InputMethod.vni)
                        Text("Telex").tag(InputMethod.telex)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 150)
                    .accessibilityIdentifier("input-method-picker")
                    if keyboard.hasPermission {
                        Toggle("Bật bộ gõ", isOn: Binding(get: { keyboard.isEnabled }, set: keyboard.setEnabled))
                            .toggleStyle(.switch).fixedSize()
                    } else {
                        Button("Cấp quyền Trợ năng…") { keyboard.requestPermission() }
                            .buttonStyle(.borderedProminent)
                    }
                }
                LoginItemSettingsView(controller: loginItem)
                if !keyboard.hasPermission {
                    Text("Cho phép NahtKey trong System Settings → Privacy & Security → Accessibility để gõ trong ứng dụng khác.")
                        .font(.callout).foregroundStyle(.secondary)
                    HStack {
                        Text("Bạn vẫn có thể quản lý từ và dùng ô thử gõ bên dưới.")
                            .font(.callout).foregroundStyle(.secondary)
                        Spacer()
                        Button("Kiểm tra lại") { keyboard.refreshEnvironment() }
                    }
                }
                if !keyboard.otherInputApps.isEmpty {
                    Label("Tắt chế độ tiếng Việt trong \(keyboard.otherInputApps.joined(separator: ", ")) trước khi bật NahtKey.", systemImage: "exclamationmark.triangle")
                        .font(.callout).foregroundStyle(.orange)
                }
                if let error = keyboard.errorMessage {
                    Text(error).font(.callout).foregroundStyle(.red)
                }
            }
            .padding(20)
            Divider()
            TabView(selection: $navigation.selectedTab) {
                DictionaryView(store: dictionary, navigation: navigation, inputMethod: keyboard.inputMethod, preferences: keyboard.preferences)
                    .tabItem { Label("Từ cá nhân", systemImage: "text.book.closed") }.tag(MainTab.dictionary)
                TypingLabView(store: dictionary, inputMethod: keyboard.inputMethod, preferences: keyboard.preferences)
                    .tabItem { Label("Thử gõ", systemImage: "keyboard") }
                    .tag(MainTab.lab)
                TypingSettingsView(keyboard: keyboard)
                    .tabItem { Label("Tùy chọn", systemImage: "slider.horizontal.3") }.tag(MainTab.settings)
            }
            .padding(14)
            HStack {
                Text("\(keyboard.inputMethod.displayName) · Unicode").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Text("\(keyboard.preferences.toggleShortcut.displayName) · Bấm biểu tượng để mở menu.")
                    .font(.caption).foregroundStyle(.secondary)
            }.padding(.horizontal, 20).padding(.bottom, 12)
        }
        .frame(minWidth: 760, minHeight: 580)
    }
}
