import Foundation
import Combine

struct CorrectionEntry: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    var raw: String
    var replacement: String

    init(id: UUID = UUID(), raw: String, replacement: String) {
        self.id = id
        self.raw = raw
        self.replacement = replacement
    }
}

@MainActor
final class DictionaryStore: ObservableObject {
    @Published private(set) var entries: [CorrectionEntry] = []
    @Published var errorMessage: String?
    @Published private(set) var isReadOnly = false

    let fileURL: URL
    private var seedRevision = 0

    var corrections: [String: String] {
        Dictionary(uniqueKeysWithValues: entries.map { ($0.raw, $0.replacement) })
    }

    private struct Document: Codable {
        let version: Int
        let entries: [CorrectionEntry]
        let seedRevision: Int?
    }

    enum StoreError: LocalizedError {
        case invalidRaw, invalidReplacement, duplicateRaw, entryMissing, invalidDocument, unsupportedVersion, readOnly

        var errorDescription: String? {
            switch self {
            case .invalidRaw:
                return "Chuỗi gõ hoặc từ cần sửa phải có 1–64 chữ cái (có thể có dấu) hoặc chữ số, không có khoảng trắng hay dấu câu."
            case .invalidReplacement:
                return "Từ thay thế cần từ 1–128 ký tự, không có khoảng trắng hoặc ký tự điều khiển."
            case .duplicateRaw:
                return "Chuỗi gõ hoặc từ này đã có trong thư viện. Hãy sửa mục hiện có."
            case .entryMissing:
                return "Không tìm thấy mục này. Hãy chọn lại trong thư viện."
            case .invalidDocument:
                return "Thư viện chứa mục không hợp lệ hoặc trùng nhau. Tệp gốc được giữ nguyên."
            case .unsupportedVersion:
                return "Phiên bản thư viện này chưa được hỗ trợ. Tệp gốc được giữ nguyên."
            case .readOnly:
                return "Chưa thể lưu vì thư viện không đọc được. Sửa tệp thư viện rồi mở lại NahtKey."
            }
        }
    }

    init(fileURL: URL? = nil) {
        self.fileURL = fileURL ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("NahtKey", isDirectory: true)
            .appendingPathComponent("corrections.json")
        load()
    }

    func add(raw: String, replacement: String) throws {
        let normalized = try validatedRaw(raw, excluding: nil)
        let normalizedReplacement = replacement.precomposedStringWithCanonicalMapping
        try Self.validateReplacement(normalizedReplacement)
        try commit(entries + [CorrectionEntry(raw: normalized, replacement: normalizedReplacement)])
    }

    func update(id: UUID, raw: String, replacement: String) throws {
        guard let index = entries.firstIndex(where: { $0.id == id }) else { throw StoreError.entryMissing }
        let normalized = try validatedRaw(raw, excluding: id)
        let normalizedReplacement = replacement.precomposedStringWithCanonicalMapping
        try Self.validateReplacement(normalizedReplacement)
        var updated = entries
        updated[index].raw = normalized
        updated[index].replacement = normalizedReplacement
        try commit(updated)
    }

    func remove(id: UUID) throws {
        guard entries.contains(where: { $0.id == id }) else { throw StoreError.entryMissing }
        try commit(entries.filter { $0.id != id })
    }

    private func validatedRaw(_ value: String, excluding id: UUID?) throws -> String {
        let normalized = value.precomposedStringWithCanonicalMapping
        try Self.validateRaw(normalized)
        guard !entries.contains(where: { $0.id != id && $0.raw == normalized }) else { throw StoreError.duplicateRaw }
        return normalized
    }

    private static func validateRaw(_ value: String) throws {
        guard (1...64).contains(value.count), value.allSatisfy({ $0.isLetter || $0.isNumber }),
              value.unicodeScalars.allSatisfy({ scalar in
                  switch scalar.properties.generalCategory {
                  case .uppercaseLetter, .lowercaseLetter, .titlecaseLetter, .modifierLetter, .otherLetter,
                       .decimalNumber, .letterNumber, .otherNumber, .nonspacingMark, .spacingMark, .enclosingMark:
                      return true
                  default:
                      return false
                  }
              }) else { throw StoreError.invalidRaw }
    }

    private static func validateReplacement(_ value: String) throws {
        let forbidden = CharacterSet.whitespacesAndNewlines.union(.controlCharacters)
        guard (1...128).contains(value.count), !value.unicodeScalars.contains(where: forbidden.contains) else {
            throw StoreError.invalidReplacement
        }
    }

    private func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            let defaults = SuggestedCorrections.pairs.map { Self.canonicalized(CorrectionEntry(raw: $0.0, replacement: $0.1)) }
            seedRevision = SuggestedCorrections.revision
            do {
                try commit(defaults)
            } catch {
                // Keep a useful in-memory dictionary when first-run persistence is unavailable.
                entries = defaults.sorted { $0.raw < $1.raw }
                errorMessage = "Chưa lưu được thư viện: \(error.localizedDescription)"
            }
            return
        }
        do {
            let document = try JSONDecoder().decode(Document.self, from: Data(contentsOf: fileURL))
            guard document.version == 1 else { throw StoreError.unsupportedVersion }
            var aliases = Set<String>()
            var identifiers = Set<UUID>()
            let normalizedEntries = document.entries.map(Self.canonicalized)
            for entry in normalizedEntries {
                try Self.validateRaw(entry.raw)
                try Self.validateReplacement(entry.replacement)
                guard aliases.insert(entry.raw).inserted,
                      identifiers.insert(entry.id).inserted else { throw StoreError.invalidDocument }
            }
            entries = normalizedEntries.sorted { $0.raw < $1.raw }
            seedRevision = document.seedRevision ?? 0
        } catch {
            isReadOnly = true
            errorMessage = "Không đọc được thư viện. Tệp gốc được giữ nguyên. \(error.localizedDescription)"
        }
        if !isReadOnly && seedRevision < SuggestedCorrections.revision {
            // One-time merge: preserve conflicting user entries and don't resurrect
            // suggestions that the user subsequently deletes.
            let existing = Set(entries.map(\.raw))
            let additions = SuggestedCorrections.pairs.filter { !existing.contains($0.0) }
                .map { CorrectionEntry(raw: $0.0, replacement: $0.1) }
            let previousRevision = seedRevision
            seedRevision = SuggestedCorrections.revision
            do { try commit(entries + additions) }
            catch { seedRevision = previousRevision }
        }
    }

    private static func canonicalized(_ entry: CorrectionEntry) -> CorrectionEntry {
        CorrectionEntry(id: entry.id, raw: entry.raw.precomposedStringWithCanonicalMapping,
                        replacement: entry.replacement.precomposedStringWithCanonicalMapping)
    }

    private func commit(_ proposed: [CorrectionEntry]) throws {
        guard !isReadOnly else { throw StoreError.readOnly }
        let sorted = proposed.map(Self.canonicalized).sorted { $0.raw < $1.raw }
        do {
            let directory = fileURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(Document(version: 1, entries: sorted, seedRevision: seedRevision))
            try data.write(to: fileURL, options: .atomic)
            entries = sorted
            errorMessage = nil
        } catch {
            errorMessage = "Chưa lưu được thay đổi: \(error.localizedDescription)"
            throw error
        }
    }
}
