import XCTest
@testable import MacAotoKillCore

final class ProcessTreeSnapshotTests: XCTestCase {
    func testAggregateIncludesAllDescendants() {
        let snapshot = ProcessTreeSnapshot(entries: [
            ProcessTreeEntry(pid: 10, parentPID: 1, residentMemoryBytes: 100),
            ProcessTreeEntry(pid: 11, parentPID: 10, residentMemoryBytes: 40),
            ProcessTreeEntry(pid: 12, parentPID: 10, residentMemoryBytes: 50),
            ProcessTreeEntry(pid: 13, parentPID: 11, residentMemoryBytes: 10),
            ProcessTreeEntry(pid: 99, parentPID: 1, residentMemoryBytes: 500)
        ])

        let aggregate = snapshot.aggregate(rootPID: 10)

        XCTAssertEqual(aggregate.totalMemoryBytes, 200)
        XCTAssertEqual(aggregate.descendantMemoryBytes, 100)
        XCTAssertEqual(aggregate.descendantCount, 3)
    }
}
