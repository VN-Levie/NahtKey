import Foundation
import XCTest
@testable import NahtKeyApp

final class DictionaryStoreTests: XCTestCase {
    @MainActor func testLegacyMergePreservesUserOverridesAndDoesNotReseedDeletedSuggestions() throws {
        let url = temporaryURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let userID = UUID()
        let legacy: [String: Any] = ["version": 1, "entries": [["id": userID.uuidString, "raw": "abn5", "replacement": "riêng"]]]
        try JSONSerialization.data(withJSONObject: legacy).write(to: url)
        let store = DictionaryStore(fileURL: url)
        XCTAssertEqual(store.corrections["abn5"], "riêng")
        XCTAssertEqual(store.corrections["haoc85"], "hoặc")
        let suggestion = try XCTUnwrap(store.entries.first { $0.raw == "haoc85" })
        try store.remove(id: suggestion.id)
        let reloaded = DictionaryStore(fileURL: url)
        XCTAssertNil(reloaded.corrections["haoc85"])
        XCTAssertEqual(reloaded.corrections["abn5"], "riêng")
    }

    private func temporaryURL() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("NahtKeyTests-\(UUID().uuidString)", isDirectory: true)
            .appendingPathComponent("corrections.json")
    }

    @MainActor func testCreateEditDeleteSurvivesReload() throws {
        let url = temporaryURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let store = DictionaryStore(fileURL: url)
        XCTAssertEqual(store.corrections["abn5"], "bạn")
        XCTAssertEqual(store.corrections["ab5n"], "bạn")
        try store.add(raw: "cna62", replacement: "cần")
        let entry = try XCTUnwrap(store.entries.first { $0.raw == "cna62" })
        try store.update(id: entry.id, raw: "cna6ntest", replacement: "cần")
        let reloaded = DictionaryStore(fileURL: url)
        XCTAssertNil(reloaded.corrections["cna62"])
        XCTAssertEqual(reloaded.corrections["cna6ntest"], "cần")
        try reloaded.remove(id: entry.id)
        XCTAssertNil(DictionaryStore(fileURL: url).corrections["cna6ntest"])
    }

    @MainActor func testUnicodeCorrectionAndEditPersistInCanonicalForm() throws {
        let url = temporaryURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let store = DictionaryStore(fileURL: url)
        try store.add(raw: "càu".decomposedStringWithCanonicalMapping,
                      replacement: "của".decomposedStringWithCanonicalMapping)
        let saved = try XCTUnwrap(store.entries.first { $0.raw == "càu" })
        XCTAssertEqual(Array(saved.raw.utf8), Array("càu".utf8))
        XCTAssertEqual(Array(saved.replacement.utf8), Array("của".utf8))

        let reloaded = DictionaryStore(fileURL: url)
        XCTAssertEqual(reloaded.corrections["càu"], "của")
        let document = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        let rows = try XCTUnwrap(document["entries"] as? [[String: Any]])
        let storedRow = try XCTUnwrap(rows.first { ($0["id"] as? String) == saved.id.uuidString })
        XCTAssertEqual(Array(try XCTUnwrap(storedRow["raw"] as? String).utf8), Array("càu".utf8))
        XCTAssertEqual(Array(try XCTUnwrap(storedRow["replacement"] as? String).utf8), Array("của".utf8))

        try reloaded.update(id: saved.id, raw: "CÀU".decomposedStringWithCanonicalMapping,
                            replacement: "CỦA".decomposedStringWithCanonicalMapping)
        try reloaded.add(raw: "càu", replacement: "của")
        let afterEdit = DictionaryStore(fileURL: url)
        XCTAssertEqual(afterEdit.corrections["CÀU"], "CỦA")
        XCTAssertEqual(afterEdit.corrections["càu"], "của")
        XCTAssertEqual(afterEdit.entries.first { $0.id == saved.id }?.raw, "CÀU")
    }

    @MainActor func testCanonicalDuplicatesCannotBeAddedOrRenamed() throws {
        let url = temporaryURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let store = DictionaryStore(fileURL: url)
        try store.add(raw: "càu", replacement: "của")
        try store.add(raw: "khca", replacement: "khác")
        let other = try XCTUnwrap(store.entries.first { $0.raw == "khca" })
        let before = store.entries
        let beforeData = try Data(contentsOf: url)
        XCTAssertThrowsError(try store.add(raw: "càu".decomposedStringWithCanonicalMapping, replacement: "khác"))
        XCTAssertThrowsError(try store.update(id: other.id, raw: "càu".decomposedStringWithCanonicalMapping, replacement: "khác"))
        XCTAssertEqual(store.entries, before)
        XCTAssertEqual(try Data(contentsOf: url), beforeData)
    }

    @MainActor func testUnicodeAliasLimitsCountCharactersAndRejectSeparators() throws {
        let url = temporaryURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let store = DictionaryStore(fileURL: url)
        let longest = String(repeating: "ấ", count: 64)
        try store.add(raw: longest, replacement: "hợp")
        try store.add(raw: "東京42", replacement: "Tokyo")
        XCTAssertEqual(store.corrections[longest], "hợp")
        XCTAssertEqual(store.corrections["東京42"], "Tokyo")
        let before = store.entries
        for invalid in ["", String(repeating: "ấ", count: 65), "cà u", "càu!", "càu\n", "càu\u{200D}", "🙂"] {
            XCTAssertThrowsError(try store.add(raw: invalid, replacement: "của"), "Unexpected valid alias: \(invalid)")
        }
        XCTAssertEqual(store.entries, before)
    }

    @MainActor func testLoadingDecomposedUnicodeNormalizesInMemoryWithoutRewritingFile() throws {
        let url = temporaryURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let document: [String: Any] = [
            "version": 1,
            "seedRevision": SuggestedCorrections.revision,
            "entries": [["id": UUID().uuidString, "raw": "càu".decomposedStringWithCanonicalMapping,
                         "replacement": "của".decomposedStringWithCanonicalMapping]]
        ]
        let original = try JSONSerialization.data(withJSONObject: document)
        try original.write(to: url)
        let store = DictionaryStore(fileURL: url)
        XCTAssertFalse(store.isReadOnly)
        XCTAssertNil(store.errorMessage)
        let entry = try XCTUnwrap(store.entries.first)
        XCTAssertEqual(Array(entry.raw.utf8), Array("càu".utf8))
        XCTAssertEqual(Array(entry.replacement.utf8), Array("của".utf8))
        XCTAssertEqual(try Data(contentsOf: url), original)
    }

    @MainActor func testLoadingCanonicalDuplicateConflictPreservesOriginalFile() throws {
        let url = temporaryURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let document: [String: Any] = [
            "version": 1,
            "entries": [
                ["id": UUID().uuidString, "raw": "càu", "replacement": "của"],
                ["id": UUID().uuidString, "raw": "càu".decomposedStringWithCanonicalMapping, "replacement": "khác"]
            ]
        ]
        let original = try JSONSerialization.data(withJSONObject: document)
        try original.write(to: url)
        let store = DictionaryStore(fileURL: url)
        XCTAssertTrue(store.isReadOnly)
        XCTAssertNotNil(store.errorMessage)
        XCTAssertTrue(store.entries.isEmpty)
        XCTAssertThrowsError(try store.add(raw: "mới", replacement: "đúng"))
        XCTAssertEqual(try Data(contentsOf: url), original)
    }

    @MainActor func testInvalidAndDuplicateEntriesLeaveDictionaryUnchanged() throws {
        let url = temporaryURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let store = DictionaryStore(fileURL: url)
        let before = store.entries
        XCTAssertThrowsError(try store.add(raw: "abn5", replacement: "khác"))
        XCTAssertThrowsError(try store.add(raw: "a b", replacement: "bạn"))
        XCTAssertThrowsError(try store.add(raw: "valid", replacement: "hai từ"))
        XCTAssertThrowsError(try store.add(raw: "valid", replacement: "\n"))
        XCTAssertEqual(store.entries, before)
    }

    @MainActor func testCorruptFileIsPreservedAndCannotBeOverwritten() throws {
        let url = temporaryURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let damaged = Data("{broken JSON".utf8)
        try damaged.write(to: url)
        let store = DictionaryStore(fileURL: url)
        XCTAssertTrue(store.isReadOnly)
        XCTAssertNotNil(store.errorMessage)
        XCTAssertThrowsError(try store.add(raw: "abn5", replacement: "bạn"))
        XCTAssertEqual(try Data(contentsOf: url), damaged)
    }

    @MainActor func testFailedSaveDoesNotPublishUnsavedChanges() throws {
        let url = temporaryURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let store = DictionaryStore(fileURL: url)
        let before = store.entries
        try FileManager.default.moveItem(at: url, to: url.appendingPathExtension("saved"))
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false)
        XCTAssertThrowsError(try store.add(raw: "cna62", replacement: "cần"))
        XCTAssertEqual(store.entries, before)
        XCTAssertNotNil(store.errorMessage)
    }
}
