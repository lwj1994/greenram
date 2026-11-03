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

    func testDescendantsArePreOrdered() {
        let snapshot = ProcessTreeSnapshot(entries: [
            ProcessTreeEntry(pid: 10, parentPID: 1, residentMemoryBytes: 100),
            ProcessTreeEntry(pid: 11, parentPID: 10, residentMemoryBytes: 40),
            ProcessTreeEntry(pid: 12, parentPID: 10, residentMemoryBytes: 50),
            ProcessTreeEntry(pid: 13, parentPID: 11, residentMemoryBytes: 10)
        ])

        XCTAssertEqual(snapshot.descendants(of: 10).map(\.pid), [11, 13, 12])
        XCTAssertEqual(snapshot.descendants(of: 11).map(\.pid), [13])
    }

    func testCommandLabelKeepsLeadingArgumentsOnly() {
        XCTAssertEqual(
            ProcessCommandLabeler.label(arguments: ["/sdk/bin/dart", "language-server", "--protocol", "lsp"]),
            "dart language-server"
        )
        XCTAssertEqual(
            ProcessCommandLabeler.label(arguments: ["bash", "/flutter/bin/dart", "mcp-server"]),
            "bash dart mcp-server"
        )
        XCTAssertEqual(
            ProcessCommandLabeler.label(arguments: ["/Claude/claude.app/Contents/MacOS/claude", "--output-format", "stream-json"]),
            "claude"
        )
        XCTAssertEqual(
            ProcessCommandLabeler.label(arguments: ["npm exec figma-developer-mcp --stdio"]),
            "npm exec figma-developer-mcp --stdio"
        )
    }

    func testCaptureReadsCurrentProcessDetails() throws {
        let pid = ProcessInfo.processInfo.processIdentifier
        let entry = try XCTUnwrap(ProcessTreeSnapshot.capture().entry(for: pid))

        XCTAssertNotNil(entry.executablePath)
        XCTAssertNotNil(entry.cpuTime)
        XCTAssertGreaterThan(entry.startTime, 0)
        XCTAssertFalse(entry.name.isEmpty)
        XCTAssertTrue(ProcessTreeSnapshot.isRunning(entry))
        XCTAssertFalse(ProcessTreeSnapshot.isRunning(ProcessTreeEntry(
            pid: pid,
            parentPID: entry.parentPID,
            memoryBytes: 0,
            startTime: entry.startTime - 1
        )))
        XCTAssertFalse(ProcessCommandLabeler().label(for: entry).isEmpty)
    }
}
