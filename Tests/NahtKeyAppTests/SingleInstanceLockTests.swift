import Foundation
import XCTest
@testable import NahtKeyApp

final class SingleInstanceLockTests: XCTestCase {
    private func withLockURL(_ body: (URL) throws -> Void) throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try body(directory.appendingPathComponent("instance.lock"))
    }

    func testSecondOpenIsRejectedUntilOwnerReleases() throws {
        try withLockURL { url in
            var first = try SingleInstanceLock.acquire(at: url)
            XCTAssertNotNil(first)
            XCTAssertNil(try SingleInstanceLock.acquire(at: url))
            first = nil
            XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
            let next = try SingleInstanceLock.acquire(at: url)
            XCTAssertNotNil(next, "A leftover file must not be mistaken for a running process")
            try withExtendedLifetime(next) { XCTAssertNil(try SingleInstanceLock.acquire(at: url)) }
        }
    }

    func testSimultaneousOpenHasExactlyOneOwner() throws {
        try withLockURL { url in
            let resultsLock = NSLock()
            var owners: [SingleInstanceLock] = []
            var errors: [Error] = []
            DispatchQueue.concurrentPerform(iterations: 16) { _ in
                do {
                    let owner = try SingleInstanceLock.acquire(at: url)
                    resultsLock.lock()
                    if let owner { owners.append(owner) }
                    resultsLock.unlock()
                } catch {
                    resultsLock.lock(); errors.append(error); resultsLock.unlock()
                }
            }
            XCTAssertTrue(errors.isEmpty)
            XCTAssertEqual(owners.count, 1)
            try withExtendedLifetime(owners) { XCTAssertNil(try SingleInstanceLock.acquire(at: url)) }
        }
    }

    func testFailureDoesNotGrantOwnership() throws {
        try withLockURL { url in
            let missingParent = url.appendingPathComponent("missing/instance.lock")
            XCTAssertThrowsError(try SingleInstanceLock.acquire(at: missingParent))
            let target = url.deletingLastPathComponent().appendingPathComponent("target")
            try Data("unchanged".utf8).write(to: target)
            try FileManager.default.createSymbolicLink(at: url, withDestinationURL: target)
            XCTAssertThrowsError(try SingleInstanceLock.acquire(at: url))
            XCTAssertEqual(try String(contentsOf: target), "unchanged")
        }
    }
}
