import AppKit
import SwiftUI
import NahtKeyCore

@main
struct NahtKeyApp: App {
    @NSApplicationDelegateAdaptor(ApplicationLifecycle.self) private var lifecycle
    @StateObject private var dictionary = DictionaryStore()
    @StateObject private var keyboard = KeyboardController()

    var body: some Scene {
        Window("NahtKey", id: "main") {
            MainView(dictionary: dictionary, keyboard: keyboard)
                .background(MainWindowRegistration(lifecycle: lifecycle, keyboard: keyboard))
                .onReceive(dictionary.$entries) { entries in
                    keyboard.updateCorrections(Dictionary(uniqueKeysWithValues: entries.map { ($0.raw, $0.replacement) }))
                }
        }
        .defaultSize(width: 880, height: 650)
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(replacing: .appTermination) {
                Button("Ẩn NahtKey") { lifecycle.hideToMenuBar() }
                    .keyboardShortcut("q", modifiers: .command)
            }
        }
    }
}

private struct MainView: View {
    @ObservedObject var dictionary: DictionaryStore
    @ObservedObject var keyboard: KeyboardController

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
            TabView {
                DictionaryView(store: dictionary, inputMethod: keyboard.inputMethod).tabItem { Label("Từ cá nhân", systemImage: "text.book.closed") }
                TypingLabView(store: dictionary, inputMethod: keyboard.inputMethod)
                    .tabItem { Label("Thử gõ", systemImage: "keyboard") }
            }
            .padding(14)
            HStack {
                Text("\(keyboard.inputMethod.displayName) · Unicode").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Text("Ctrl + Shift: bật/tắt · Bấm đúp biểu tượng menu để mở.")
                    .font(.caption).foregroundStyle(.secondary)
            }.padding(.horizontal, 20).padding(.bottom, 12)
        }
        .frame(minWidth: 760, minHeight: 580)
    }
}
