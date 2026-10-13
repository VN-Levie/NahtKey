import Foundation
import XCTest
@testable import NahtKeyApp

final class DictionaryTransferTests: XCTestCase {
    private func directory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("NahtKeyTransferTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func document(_ entries: [CorrectionEntry], version: Int = 1, seedRevision: Int? = nil) throws -> Data {
        var value: [String: Any] = [
            "version": version,
            "entries": entries.map { ["id": $0.id.uuidString, "raw": $0.raw, "replacement": $0.replacement] }
        ]
        if let seedRevision { value["seedRevision"] = seedRevision }
        return try JSONSerialization.data(withJSONObject: value)
    }

    @MainActor private func store(at url: URL, entries: [CorrectionEntry] = []) throws -> DictionaryStore {
        try document(entries, seedRevision: SuggestedCorrections.revision).write(to: url)
        let result = DictionaryStore(fileURL: url)
        XCTAssertFalse(result.isReadOnly)
        return result
    }

    @MainActor func testExportAndImportRoundTripAllEntriesWithoutMutatingSource() throws {
        let folder = try directory()
        defer { try? FileManager.default.removeItem(at: folder) }
        let source = try store(at: folder.appendingPathComponent("source.json"))
        try source.add(raw: "càu".decomposedStringWithCanonicalMapping, replacement: "của".decomposedStringWithCanonicalMapping)
        try source.add(raw: "abc123", replacement: "đúng")
        let originalEntries = source.entries
        let originalBytes = try Data(contentsOf: source.fileURL)
        let exportedURL = folder.appendingPathComponent("export.json")
        let exportedData = try source.exportLibraryData()
        try source.exportLibrary(to: exportedURL)
        XCTAssertEqual(try Data(contentsOf: exportedURL), exportedData)
        XCTAssertEqual(source.entries, originalEntries)
        XCTAssertEqual(try Data(contentsOf: source.fileURL), originalBytes)

        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: exportedData) as? [String: Any])
        XCTAssertEqual(json["version"] as? Int, 1)
        let rows = try XCTUnwrap(json["entries"] as? [[String: Any]])
        let unicode = try XCTUnwrap(rows.first { ($0["raw"] as? String) == "càu" })
        XCTAssertEqual(Array(try XCTUnwrap(unicode["raw"] as? String).utf8), Array("càu".utf8))
        XCTAssertEqual(Array(try XCTUnwrap(unicode["replacement"] as? String).utf8), Array("của".utf8))

        let target = try store(at: folder.appendingPathComponent("target.json"))
        let report = try target.importLibrary(from: exportedURL)
        XCTAssertEqual(report, DictionaryImportReport(added: 2, updated: 0, unchanged: 0, duplicates: 0, conflicts: 0))
        XCTAssertEqual(target.entries, originalEntries)
        XCTAssertEqual(DictionaryStore(fileURL: target.fileURL).entries, originalEntries)
    }

    @MainActor func testPreferImportedUpdatesValuesKeepsLocalIDsAndTreatsCaseSeparately() throws {
        let folder = try directory()
        defer { try? FileManager.default.removeItem(at: folder) }
        let local = CorrectionEntry(raw: "càu", replacement: "riêng")
        let same = CorrectionEntry(raw: "same", replacement: "giữ")
        let target = try store(at: folder.appendingPathComponent("local.json"), entries: [local, same])
        let data = try document([
            CorrectionEntry(raw: "càu".decomposedStringWithCanonicalMapping, replacement: "của"),
            CorrectionEntry(raw: "same", replacement: "giữ"),
            CorrectionEntry(raw: "Càu", replacement: "Của")
        ])
        let report = try target.importLibrary(data: data)
        XCTAssertEqual(report, DictionaryImportReport(added: 1, updated: 1, unchanged: 1, duplicates: 0, conflicts: 1))
        XCTAssertEqual(target.entries.first { $0.raw == "càu" }?.id, local.id)
        XCTAssertEqual(target.entries.first { $0.raw == "same" }?.id, same.id)
        XCTAssertEqual(target.corrections["càu"], "của")
        XCTAssertEqual(target.corrections["Càu"], "Của")
    }

    @MainActor func testKeepExistingPolicyStillAddsNewEntries() throws {
        let folder = try directory()
        defer { try? FileManager.default.removeItem(at: folder) }
        let local = CorrectionEntry(raw: "càu", replacement: "riêng")
        let target = try store(at: folder.appendingPathComponent("local.json"), entries: [local])
        let report = try target.importLibrary(data: document([
            CorrectionEntry(raw: "càu", replacement: "của"), CorrectionEntry(raw: "fresh", replacement: "mới")
        ]), conflictPolicy: .keepExisting)
        XCTAssertEqual(report, DictionaryImportReport(added: 1, updated: 0, unchanged: 1, duplicates: 0, conflicts: 1))
        XCTAssertEqual(target.entries.first { $0.raw == "càu" }, local)
        XCTAssertEqual(target.corrections["fresh"], "mới")
    }

    @MainActor func testCanonicalDuplicatesCollapseAndLastValidatedOccurrenceWins() throws {
        let folder = try directory()
        defer { try? FileManager.default.removeItem(at: folder) }
        let target = try store(at: folder.appendingPathComponent("local.json"))
        let lastID = UUID()
        let report = try target.importLibrary(data: document([
            CorrectionEntry(raw: "càu", replacement: "khác"),
            CorrectionEntry(raw: "càu".decomposedStringWithCanonicalMapping, replacement: "của"),
            CorrectionEntry(id: lastID, raw: "càu", replacement: "của".decomposedStringWithCanonicalMapping)
        ]))
        XCTAssertEqual(report, DictionaryImportReport(added: 1, updated: 0, unchanged: 0, duplicates: 2, conflicts: 1))
        XCTAssertEqual(target.entries, [CorrectionEntry(id: lastID, raw: "càu", replacement: "của")])
        XCTAssertEqual(Array(target.entries[0].replacement.utf8), Array("của".utf8))
    }

    @MainActor func testImportedUUIDCollisionsNeverReplaceOrDuplicateLocalIdentities() throws {
        let folder = try directory()
        defer { try? FileManager.default.removeItem(at: folder) }
        let original = CorrectionEntry(raw: "local", replacement: "cũ")
        let freeID = UUID()
        let target = try store(at: folder.appendingPathComponent("local.json"), entries: [original])
        let data = try document([
            CorrectionEntry(id: freeID, raw: "local", replacement: "mới"),
            CorrectionEntry(id: original.id, raw: "first", replacement: "một"),
            CorrectionEntry(id: original.id, raw: "second", replacement: "hai"),
            CorrectionEntry(id: freeID, raw: "third", replacement: "ba")
        ])
        let report = try target.importLibrary(data: data)
        XCTAssertEqual(report.added, 3)
        XCTAssertEqual(report.updated, 1)
        XCTAssertEqual(target.entries.first { $0.raw == "local" }?.id, original.id)
        XCTAssertEqual(target.entries.first { $0.raw == "third" }?.id, freeID)
        XCTAssertEqual(Set(target.entries.map(\.id)).count, target.entries.count)
        let afterFirstImport = target.entries
        let bytes = try Data(contentsOf: target.fileURL)
        let repeated = try target.importLibrary(data: data)
        XCTAssertEqual(repeated.unchanged, 4)
        XCTAssertEqual(target.entries, afterFirstImport)
        XCTAssertEqual(try Data(contentsOf: target.fileURL), bytes)
    }

    @MainActor func testEveryEntryMustValidateEvenWhenALaterDuplicateWouldReplaceIt() throws {
        let folder = try directory()
        defer { try? FileManager.default.removeItem(at: folder) }
        let target = try store(at: folder.appendingPathComponent("local.json"), entries: [CorrectionEntry(raw: "local", replacement: "giữ")])
        let before = target.entries
        let bytes = try Data(contentsOf: target.fileURL)
        let data = try document([
            CorrectionEntry(raw: "fresh", replacement: "mới"),
            CorrectionEntry(raw: "càu", replacement: "hai từ"),
            CorrectionEntry(raw: "càu", replacement: "của")
        ])
        XCTAssertThrowsError(try target.importLibrary(data: data))
        XCTAssertEqual(target.entries, before)
        XCTAssertEqual(try Data(contentsOf: target.fileURL), bytes)

        for invalid in [Data("{broken".utf8), try document([], version: 2),
                        try document([CorrectionEntry(raw: "bad alias", replacement: "đúng")])] {
            XCTAssertThrowsError(try target.importLibrary(data: invalid))
            XCTAssertEqual(target.entries, before)
            XCTAssertEqual(try Data(contentsOf: target.fileURL), bytes)
        }
    }

    @MainActor func testFailedAtomicImportDoesNotPublishPartialMergeOrAlterDestination() throws {
        let folder = try directory()
        defer { try? FileManager.default.removeItem(at: folder) }
        let target = try store(at: folder.appendingPathComponent("local.json"), entries: [CorrectionEntry(raw: "local", replacement: "giữ")])
        let before = target.entries
        let originalBytes = try Data(contentsOf: target.fileURL)
        let backup = folder.appendingPathComponent("original.json")
        try FileManager.default.moveItem(at: target.fileURL, to: backup)
        try FileManager.default.createDirectory(at: target.fileURL, withIntermediateDirectories: false)
        let sentinel = target.fileURL.appendingPathComponent("sentinel")
        let sentinelBytes = Data("preserve".utf8)
        try sentinelBytes.write(to: sentinel)

        XCTAssertThrowsError(try target.importLibrary(data: document([
            CorrectionEntry(raw: "local", replacement: "đổi"), CorrectionEntry(raw: "fresh", replacement: "mới")
        ])))
        XCTAssertEqual(target.entries, before)
        XCTAssertEqual(try Data(contentsOf: backup), originalBytes)
        XCTAssertEqual(try Data(contentsOf: sentinel), sentinelBytes)
        XCTAssertNotNil(target.errorMessage)
    }

    @MainActor func testImportedSeedRevisionCannotReseedDeletedSuggestionsOrSpoofMigrationProgress() throws {
        let folder = try directory()
        defer { try? FileManager.default.removeItem(at: folder) }
        let target = DictionaryStore(fileURL: folder.appendingPathComponent("local.json"))
        let removed = try XCTUnwrap(target.entries.first { $0.raw == "abn5" })
        try target.remove(id: removed.id)
        try target.importLibrary(data: document([CorrectionEntry(raw: "importOne", replacement: "một")], seedRevision: 0))
        XCTAssertNil(DictionaryStore(fileURL: target.fileURL).corrections["abn5"])
        try target.importLibrary(data: document([CorrectionEntry(raw: "importTwo", replacement: "hai")], seedRevision: Int.max))
        let saved = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: target.fileURL)) as? [String: Any])
        XCTAssertEqual(saved["seedRevision"] as? Int, SuggestedCorrections.revision)
        XCTAssertNil(DictionaryStore(fileURL: target.fileURL).corrections["abn5"])
    }

    @MainActor func testDamagedLibraryCannotBeOverwrittenByImportOrExportedAsEmptyData() throws {
        let folder = try directory()
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appendingPathComponent("damaged.json")
        let damaged = Data("{broken".utf8)
        try damaged.write(to: url)
        let target = DictionaryStore(fileURL: url)
        let originalError = target.errorMessage
        XCTAssertTrue(target.isReadOnly)
        XCTAssertThrowsError(try target.importLibrary(data: document([CorrectionEntry(raw: "fresh", replacement: "mới")])))
        XCTAssertThrowsError(try target.exportLibraryData())
        let exportURL = folder.appendingPathComponent("export.json")
        XCTAssertThrowsError(try target.exportLibrary(to: exportURL))
        XCTAssertFalse(FileManager.default.fileExists(atPath: exportURL.path))
        XCTAssertEqual(try Data(contentsOf: url), damaged)
        XCTAssertTrue(target.entries.isEmpty)
        XCTAssertEqual(target.errorMessage, originalError)
    }

    @MainActor func testSizeBoundAndNonFileInputRejectWithoutChangingTheLibrary() throws {
        let folder = try directory()
        defer { try? FileManager.default.removeItem(at: folder) }
        let target = try store(at: folder.appendingPathComponent("local.json"))
        let before = target.entries
        let bytes = try Data(contentsOf: target.fileURL)
        XCTAssertThrowsError(try target.importLibrary(data: Data(repeating: 32, count: DictionaryStore.maximumImportBytes + 1)))
        let tooLarge = folder.appendingPathComponent("large.json")
        try Data().write(to: tooLarge)
        let handle = try FileHandle(forWritingTo: tooLarge)
        try handle.truncate(atOffset: UInt64(DictionaryStore.maximumImportBytes + 1))
        try handle.close()
        XCTAssertThrowsError(try target.importLibrary(from: tooLarge))
        XCTAssertThrowsError(try target.importLibrary(from: folder))
        XCTAssertEqual(target.entries, before)
        XCTAssertEqual(try Data(contentsOf: target.fileURL), bytes)
    }

    @MainActor func testExportFailureAndExportToLocalLibraryNeverMutateStore() throws {
        let folder = try directory()
        defer { try? FileManager.default.removeItem(at: folder) }
        let target = try store(at: folder.appendingPathComponent("local.json"), entries: [CorrectionEntry(raw: "local", replacement: "giữ")])
        let before = target.entries
        let bytes = try Data(contentsOf: target.fileURL)
        let originalError = target.errorMessage
        XCTAssertThrowsError(try target.exportLibrary(to: folder))
        XCTAssertThrowsError(try target.exportLibrary(to: target.fileURL))
        XCTAssertEqual(target.entries, before)
        XCTAssertEqual(try Data(contentsOf: target.fileURL), bytes)
        XCTAssertEqual(target.errorMessage, originalError)
    }
}
