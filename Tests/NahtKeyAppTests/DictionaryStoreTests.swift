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
