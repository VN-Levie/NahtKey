import AppKit
import SwiftUI
import UniformTypeIdentifiers
import NahtKeyCore

struct DictionaryView: View {
    @ObservedObject var store: DictionaryStore
    var inputMethod: InputMethod = .vni
    @State private var query = ""
    @State private var selection: UUID?
    @State private var editor: EditorTarget?
    @State private var deletion: CorrectionEntry?
    @State private var transferMessage: String?
    @State private var transferFailed = false

    private struct EditorTarget: Identifiable {
        let id = UUID()
        let entry: CorrectionEntry?
    }

    private var filteredEntries: [CorrectionEntry] {
        let search = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !search.isEmpty else { return store.entries }
        return store.entries.filter {
            $0.raw.localizedStandardContains(search) || $0.replacement.localizedStandardContains(search)
        }
    }

    private var selectedEntry: CorrectionEntry? {
        filteredEntries.first { $0.id == selection }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Thư viện cá nhân")
                        .font(.title2.weight(.semibold))
                    Text("Sửa chuỗi gõ hoặc từ khi kết thúc từ.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 16)
                Button { importLibrary() } label: {
                    Label("Nhập…", systemImage: "square.and.arrow.down")
                }
                .disabled(store.isReadOnly)
                .accessibilityIdentifier("import-library")
                Button { exportLibrary() } label: {
                    Label("Xuất…", systemImage: "square.and.arrow.up")
                }
                .disabled(store.isReadOnly)
                .accessibilityIdentifier("export-library")
                Button {
                    editor = EditorTarget(entry: nil)
                } label: {
                    Label("Thêm từ", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut("n", modifiers: .command)
                .disabled(store.isReadOnly)
                .accessibilityIdentifier("add-correction")
            }

            if let message = transferMessage {
                Label(message, systemImage: transferFailed ? "exclamationmark.circle" : "checkmark.circle")
                    .font(.callout)
                    .foregroundStyle(transferFailed ? Color.red : Color.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
            }

            if let message = store.errorMessage {
                Label(message, systemImage: "exclamationmark.triangle.fill")
                    .font(.callout)
                    .foregroundStyle(.orange)
                    .textSelection(.enabled)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
            }

            HStack {
                HStack(spacing: 7) {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    TextField("Tìm chuỗi gõ, từ cần sửa hoặc từ thay thế", text: $query)
                        .textFieldStyle(.plain)
                        .accessibilityLabel("Tìm trong thư viện")
                    if !query.isEmpty {
                        Button { query = "" } label: { Image(systemName: "xmark.circle.fill") }
                            .buttonStyle(.plain)
                            .foregroundStyle(.secondary)
                            .accessibilityLabel("Xóa tìm kiếm")
                    }
                }
                .padding(8)
                .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 7))
                .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(.quaternary))
                Text("\(store.entries.count) mục")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 48, alignment: .trailing)
            }

            Table(filteredEntries, selection: $selection) {
                TableColumn("Chuỗi gõ hoặc từ cần sửa") { entry in
                    Text(entry.raw)
                        .font(.system(.body, design: .monospaced))
                        .onTapGesture(count: 2) { edit(entry) }
                }
                TableColumn("Thay bằng") { entry in
                    Text(entry.replacement)
                        .font(.body.weight(.medium))
                        .onTapGesture(count: 2) { edit(entry) }
                }
            }
            .accessibilityIdentifier("dictionary-table")
            .overlay {
                if filteredEntries.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: query.isEmpty ? "text.badge.plus" : "magnifyingglass")
                            .font(.system(size: 26))
                            .foregroundStyle(.tertiary)
                        Text(query.isEmpty ? "Chưa có từ nào" : "Không tìm thấy từ")
                            .font(.headline)
                        Text(query.isEmpty ? "Chọn Thêm từ để tạo quy tắc đầu tiên." : "Thử một chuỗi gõ hoặc từ khác.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    .allowsHitTesting(false)
                }
            }
            .contextMenu {
                Button("Sửa") { if let entry = selectedEntry { edit(entry) } }
                    .disabled(selectedEntry == nil || store.isReadOnly)
                Button("Xóa…", role: .destructive) { deletion = selectedEntry }
                    .disabled(selectedEntry == nil || store.isReadOnly)
            }
            .frame(minHeight: 180)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.quaternary))

            HStack(spacing: 10) {
                Button { if let entry = selectedEntry { edit(entry) } } label: {
                    Label("Sửa", systemImage: "pencil")
                }
                .disabled(selectedEntry == nil || store.isReadOnly)
                .accessibilityIdentifier("edit-correction")
                Button(role: .destructive) { deletion = selectedEntry } label: {
                    Label("Xóa…", systemImage: "trash")
                }
                .disabled(selectedEntry == nil || store.isReadOnly)
                .accessibilityIdentifier("delete-correction")
                Spacer()
                Text("Ví dụ: abn5 → bạn · càu → của")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(24)
        .sheet(item: $editor) { target in
            CorrectionEditor(store: store, entry: target.entry, inputMethod: inputMethod)
        }
        .confirmationDialog("Xóa quy tắc này?", isPresented: Binding(
            get: { deletion != nil },
            set: { if !$0 { deletion = nil } }
        ), titleVisibility: .visible) {
            if let entry = deletion {
                Button("Xóa \(entry.raw)", role: .destructive) {
                    do {
                        try store.remove(id: entry.id)
                        selection = nil
                    } catch {
                        store.errorMessage = error.localizedDescription
                    }
                    deletion = nil
                }
            }
            Button("Hủy", role: .cancel) { deletion = nil }
        } message: {
            if let entry = deletion { Text("\(entry.raw) → \(entry.replacement)") }
        }
    }

    private func importLibrary() {
        guard !store.isReadOnly else { return }
        let panel = NSOpenPanel()
        panel.title = "Nhập thư viện"
        panel.prompt = "Nhập"
        panel.message = "Các mục trùng sẽ dùng giá trị trong tệp nhập."
        panel.allowedContentTypes = [.json]
        panel.allowsOtherFileTypes = false
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        present(panel) { response in
            guard response == .OK, let url = panel.url else { return }
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            do {
                let report = try store.importLibrary(from: url, conflictPolicy: .preferImported)
                var message = "Đã nhập: \(report.added) thêm, \(report.updated) cập nhật, \(report.unchanged) giữ nguyên."
                if report.duplicates > 0 { message += " Đã gộp \(report.duplicates) mục trùng." }
                transferMessage = message
                transferFailed = false
            } catch {
                transferMessage = "Không thể nhập thư viện: \(error.localizedDescription)"
                transferFailed = true
            }
        }
    }

    private func exportLibrary() {
        guard !store.isReadOnly else { return }
        let panel = NSSavePanel()
        panel.title = "Xuất thư viện"
        panel.prompt = "Xuất"
        panel.allowedContentTypes = [.json]
        panel.allowsOtherFileTypes = false
        panel.nameFieldStringValue = "NahtKey-library.json"
        panel.isExtensionHidden = false
        present(panel) { response in
            guard response == .OK, let url = panel.url else { return }
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            do {
                try store.exportLibrary(to: url)
                transferMessage = "Đã xuất \(store.entries.count) mục."
                transferFailed = false
            } catch {
                transferMessage = "Không thể xuất thư viện: \(error.localizedDescription)"
                transferFailed = true
            }
        }
    }

    private func present(_ panel: NSSavePanel, completion: @escaping (NSApplication.ModalResponse) -> Void) {
        if let window = NSApp.keyWindow {
            panel.beginSheetModal(for: window, completionHandler: completion)
        } else {
            panel.begin(completionHandler: completion)
        }
    }

    private func edit(_ entry: CorrectionEntry) {
        guard !store.isReadOnly else { return }
        selection = entry.id
        editor = EditorTarget(entry: entry)
    }
}

private struct CorrectionEditor: View {
    @ObservedObject var store: DictionaryStore
    let entry: CorrectionEntry?
    let inputMethod: InputMethod
    @Environment(\.dismiss) private var dismiss
    @State private var raw: String
    @State private var replacement: String
    @State private var validationMessage: String?

    init(store: DictionaryStore, entry: CorrectionEntry?, inputMethod: InputMethod) {
        self.store = store
        self.entry = entry
        self.inputMethod = inputMethod
        _raw = State(initialValue: entry?.raw ?? "")
        _replacement = State(initialValue: entry?.replacement ?? "")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(entry == nil ? "Thêm từ" : "Sửa từ")
                .font(.title2.weight(.semibold))

            VStack(alignment: .leading, spacing: 7) {
                Text("Chuỗi gõ hoặc từ cần sửa").font(.headline)
                VietnameseTextField(text: $raw, inputMethod: inputMethod,
                                    placeholder: "Ví dụ: abn5 hoặc càu",
                                    accessibilityLabel: "Chuỗi gõ hoặc từ cần sửa",
                                    accessibilityIdentifier: "correction-raw", onSubmit: save)
                    .frame(height: 22)
                Text("Chuỗi gõ hoặc từ có dấu; tối đa 64 ký tự, không có khoảng trắng.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 7) {
                Text("Thay bằng").font(.headline)
                VietnameseTextField(text: $replacement, inputMethod: inputMethod,
                                    placeholder: "Ví dụ: bạn hoặc của", onSubmit: save)
                    .frame(height: 22)
                Text("Gõ \(inputMethod.displayName) tại đây. Một từ, không có khoảng trắng.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let message = validationMessage {
                Label(message, systemImage: "exclamationmark.circle")
                    .font(.callout)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack {
                Spacer()
                Button("Hủy") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Lưu") { save() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .disabled(raw.isEmpty || replacement.isEmpty || store.isReadOnly)
                    .accessibilityIdentifier("save-correction")
            }
        }
        .padding(24)
        .frame(width: 420)
    }

    private func save() {
        do {
            if let entry {
                try store.update(id: entry.id, raw: raw, replacement: replacement)
            } else {
                try store.add(raw: raw, replacement: replacement)
            }
            dismiss()
        } catch {
            validationMessage = error.localizedDescription
        }
    }
}
