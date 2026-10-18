import ApplicationServices
import NahtKeyCore
import XCTest
@testable import NahtKeyApp

final class TextInputFocusTests: XCTestCase {
    private struct Node {
        var metadata: TextInputFocus.Metadata
        var parent: Int?
        var children: [Int] = []
        var owns: [Int] = []
    }

    private final class Fixture {
        var nodes: [Int: Node] = [
            1: Node(metadata: .init(role: kAXComboBoxRole as String, expanded: true, editable: true), parent: 5, owns: [2]),
            2: Node(metadata: .init(role: kAXListRole as String), parent: 5, children: [3, 4]),
            3: Node(metadata: .init(role: kAXStaticTextRole as String), parent: 2),
            4: Node(metadata: .init(role: kAXStaticTextRole as String), parent: 2),
            5: Node(metadata: .init(role: kAXGroupRole as String), parent: 6, children: [1, 2]),
            6: Node(metadata: .init(role: "AXWebArea"), children: [5])
        ]
        var metadataReads: [Int] = []
        var childrenReads: [Int] = []
        var available = true
        var unavailableChildren: Set<Int> = []
        var graph: TextInputFocus.Graph<Int> {
            .init(same: ==, metadata: { [self] in
                metadataReads.append($0)
                return nodes[$0]?.metadata
            }, parent: { [self] in nodes[$0]?.parent }, children: { [self] element, limit in
                childrenReads.append(element)
                guard !unavailableChildren.contains(element), let values = nodes[element]?.children,
                      values.count <= limit else { return nil }
                return values
            }, owns: { [self] element, limit in
                guard let values = nodes[element]?.owns, values.count <= limit else { return nil }
                return values
            }, withinBudget: { [self] in available })
        }

        func resolve(_ observed: Int, previous: Int? = nil, maximumParents: Int = 6,
                     maximumNodes: Int = 64) -> Int {
            TextInputFocus.resolve(observed: observed, previous: previous, graph: graph,
                                   maximumParents: maximumParents, maximumNodes: maximumNodes)
        }
    }

    func testChangingSuggestionsKeepOwnerWithBoundedAmbiguityCheck() {
        let fixture = Fixture()
        XCTAssertEqual(fixture.resolve(3, previous: 1), 1)
        XCTAssertEqual(fixture.resolve(4, previous: 1), 1)
        XCTAssertLessThanOrEqual(fixture.metadataReads.count, 12)
        XCTAssertFalse(fixture.childrenReads.contains(2), "Do not enumerate popup suggestions")
        XCTAssertFalse(fixture.childrenReads.contains(6), "Do not scan the whole web area")
    }

    func testInitialSuggestionFindsUniqueOwnerInNearbyGroup() {
        let fixture = Fixture()
        XCTAssertEqual(fixture.resolve(3), 1)
        XCTAssertFalse(fixture.childrenReads.contains(2), "Do not enumerate popup suggestions")
        XCTAssertFalse(fixture.childrenReads.contains(6), "Do not scan the whole web area")
    }

    func testLatePopupCreationRechecksOwnership() {
        let fixture = Fixture()
        fixture.nodes[1]?.metadata.expanded = false
        fixture.nodes[1]?.owns = []
        XCTAssertEqual(fixture.resolve(1, previous: 1), 1)
        fixture.nodes[1]?.metadata.expanded = true
        fixture.nodes[1]?.owns = [2]
        XCTAssertEqual(fixture.resolve(3, previous: 1), 1)

        fixture.nodes[7] = Node(metadata: .init(role: kAXListRole as String), parent: 5, children: [8])
        fixture.nodes[8] = Node(metadata: .init(role: kAXStaticTextRole as String), parent: 7)
        fixture.nodes[1]?.owns = [7]
        fixture.nodes[5]?.children = [1, 7]
        XCTAssertEqual(fixture.resolve(8, previous: 1), 1)
        XCTAssertEqual(fixture.resolve(3, previous: 1), 3, "A stale popup is no longer owned")
    }

    func testActualFocusSwitchToAnyTextInputOrSecureFieldRemainsObserved() {
        for metadata in [
            TextInputFocus.Metadata(role: kAXTextFieldRole as String),
            .init(role: kAXTextAreaRole as String),
            .init(role: kAXComboBoxRole as String),
            .init(role: kAXTextFieldRole as String, subrole: kAXSecureTextFieldSubrole as String),
            .init(role: "AXSecureTextField"),
            .init(role: kAXStaticTextRole as String, protectedContent: true)
        ] {
            let fixture = Fixture()
            fixture.nodes[9] = Node(metadata: metadata, parent: 2)
            XCTAssertEqual(fixture.resolve(9, previous: 1), 9)
            XCTAssertEqual(fixture.metadataReads, [9])
        }
    }

    func testCollapsedNoneditableProtectedAndUnrelatedComboboxesAreRejected() {
        for change in 0..<5 {
            let fixture = Fixture()
            switch change {
            case 0: fixture.nodes[1]?.metadata.expanded = false
            case 1: fixture.nodes[1]?.metadata.editable = false
            case 2: fixture.nodes[1]?.metadata.protectedContent = true
            case 3: fixture.nodes[1]?.metadata.subrole = kAXSecureTextFieldSubrole as String
            default: fixture.nodes[1]?.owns = [99]
            }
            XCTAssertEqual(fixture.resolve(3, previous: 1), 3)
        }
    }

    func testTwoOwnersInSameScopeAreAmbiguous() {
        let fixture = Fixture()
        fixture.nodes[7] = fixture.nodes[1]
        fixture.nodes[5]?.children.append(7)
        XCTAssertEqual(fixture.resolve(3), 3)
        XCTAssertEqual(fixture.resolve(3, previous: 1), 3, "Previous focus must not bypass ambiguity")
    }

    func testPopupOwnershipHandoffReplacesPreviousOwner() {
        let fixture = Fixture()
        XCTAssertEqual(fixture.resolve(3, previous: 1), 1)
        fixture.nodes[7] = fixture.nodes[1]
        fixture.nodes[1]?.owns = []
        fixture.nodes[5]?.children.append(7)
        XCTAssertEqual(fixture.resolve(3, previous: 1), 7)
    }

    func testDifferentComboOwnsNewPopupAfterTrueControlChange() {
        let fixture = Fixture()
        fixture.nodes[7] = Node(metadata: .init(role: kAXComboBoxRole as String, expanded: true, editable: true),
                                parent: 5, owns: [8])
        fixture.nodes[8] = Node(metadata: .init(role: kAXListRole as String), parent: 5, children: [9])
        fixture.nodes[9] = Node(metadata: .init(role: kAXStaticTextRole as String), parent: 8)
        fixture.nodes[5]?.children += [7, 8]
        XCTAssertEqual(fixture.resolve(9, previous: 1), 7)
    }

    func testProtectedAncestorAndWebAreaBoundaryAreNotTraversed() {
        let fixture = Fixture()
        fixture.nodes[2]?.metadata.protectedContent = true
        XCTAssertEqual(fixture.resolve(3, previous: 1), 3)
        fixture.nodes[2]?.metadata.protectedContent = false
        fixture.nodes[2]?.parent = 6
        XCTAssertEqual(fixture.resolve(3), 3)
        XCTAssertTrue(fixture.childrenReads.isEmpty)
    }

    func testParentCyclesAndChildCyclesTerminate() {
        let fixture = Fixture()
        fixture.nodes[2]?.parent = 3
        XCTAssertEqual(fixture.resolve(3), 3)
        fixture.nodes[2]?.parent = 5
        fixture.nodes[5]?.children.append(5)
        XCTAssertEqual(fixture.resolve(3), 1)
    }

    func testParentNodeAndTimeBoundsFailClosed() {
        let fixture = Fixture()
        XCTAssertEqual(fixture.resolve(3, maximumParents: 1), 3)
        XCTAssertEqual(fixture.resolve(3, maximumNodes: 3), 3)
        fixture.available = false
        XCTAssertEqual(fixture.resolve(3, previous: 1), 3)
    }

    func testIncompleteScopeDoesNotAcceptCandidateBeforeUnknownSibling() {
        let fixture = Fixture()
        fixture.nodes[7] = Node(metadata: .init(role: kAXGroupRole as String), parent: 5)
        fixture.nodes[5]?.children.append(7)
        fixture.unavailableChildren.insert(7)
        XCTAssertEqual(fixture.resolve(3), 3)
    }

    func testFirstWordCompositionSurvivesLateAndChangingSearchResults() {
        for (keys, expected) in [("bao3", "bảo"), ("dau962", "đầu")] {
            for observations in [[1, 3, 4, 1, 4, 3], [3, 4, 1, 3, 1, 4]] {
                let fixture = Fixture()
                let session = TypingSession()
                var previous: Int?
                var visible = ""
                for (index, key) in keys.enumerated() {
                    let resolved = fixture.resolve(observations[index], previous: previous)
                    if let previous, previous != resolved { session.reset() }
                    previous = resolved
                    let edit = session.process(key)
                    visible = String(visible.dropLast(edit.deleteCount)) + edit.insertText
                }
                XCTAssertEqual(visible, expected, keys)
            }
        }
    }
}
