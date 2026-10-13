import SwiftUI
import NahtKeyCore

struct TypingLabView: View {
    @ObservedObject var store: DictionaryStore
    var inputMethod: InputMethod = .vni
    @State private var input = ""
    @FocusState private var isInputFocused: Bool

    private var preview: String {
        let engine = VNIEngine(corrections: store.corrections, inputMethod: inputMethod)
        var output = ""
        func apply(_ edit: TextEdit) {
            output.removeLast(min(edit.deleteCount, output.count))
            output.append(edit.insertText)
        }
        for character in input {
            if character.unicodeScalars.count == 1, let scalar = character.unicodeScalars.first,
               (65...90).contains(scalar.value) || (97...122).contains(scalar.value) || (48...57).contains(scalar.value) {
                apply(engine.process(character))
            } else {
                apply(engine.finish())
                output.append(character)
            }
        }
        return output
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 5) {
                Text("Thử bộ gõ")
                    .font(.title2.weight(.semibold))
                Text("Nhập chuỗi phím \(inputMethod.displayName). Nhấn Space hoặc dấu câu để sửa từ.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                Text("Thử nhanh:").font(.callout).foregroundStyle(.secondary)
                sampleButton("abn5 ␣", raw: "abn5 ")
                sampleButton("ab5n ␣", raw: "ab5n ")
                if inputMethod == .vni {
                    sampleButton("tie6ng1 Vie6t5 ␣", raw: "tie6ng1 Vie6t5 ")
                } else {
                    sampleButton("tieengs Vieetj ␣", raw: "tieengs Vieetj ")
                }
                Spacer()
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Phím gốc").font(.headline)
                    Spacer()
                    Button("Xóa") { input = ""; isInputFocused = true }
                        .disabled(input.isEmpty)
                }
                TextEditor(text: $input)
                    .font(.system(.body, design: .monospaced))
                    .focused($isInputFocused)
                    .padding(7)
                    .background(Color(nsColor: .textBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.quaternary))
                    .frame(minHeight: 100, maxHeight: .infinity)
                    .accessibilityLabel("Chuỗi phím gốc để thử bộ gõ")
                    .accessibilityIdentifier("typing-lab-input")
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Kết quả").font(.headline)
                ScrollView {
                    Text(input.isEmpty ? "Kết quả gõ sẽ hiện ở đây" : preview)
                        .font(.system(size: 20))
                        .foregroundStyle(input.isEmpty ? .secondary : .primary)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                        .padding(14)
                }
                .frame(minHeight: 100, maxHeight: .infinity)
                .background(Color.accentColor.opacity(0.045), in: RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.quaternary))
                .accessibilityIdentifier("typing-lab-output")
            }

            Label("Đây là ô thử trong NahtKey. Bật bộ gõ để dùng ở ứng dụng khác.", systemImage: "info.circle")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding(24)
    }

    private func sampleButton(_ label: String, raw: String) -> some View {
        Button(label) {
            input = raw
            isInputFocused = true
        }
        .font(.system(.callout, design: .monospaced))
    }
}
