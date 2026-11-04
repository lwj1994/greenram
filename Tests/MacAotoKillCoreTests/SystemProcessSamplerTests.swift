import Darwin
import XCTest
@testable import MacAotoKillCore

final class SystemProcessSamplerTests: XCTestCase {
    func testSummarizeExcludesAppTreesAndSortsByMemory() {
        let tree = ProcessTreeSnapshot(entries: [
            ProcessTreeEntry(pid: 100, parentPID: 1, memoryBytes: 0, executablePath: "/Applications/Xcode.app/Contents/MacOS/Xcode"),
            ProcessTreeEntry(pid: 101, parentPID: 100, memoryBytes: 0, executablePath: "/usr/bin/sourcekit-lsp"),
            ProcessTreeEntry(pid: 200, parentPID: 1, memoryBytes: 0, executablePath: "/usr/libexec/mds", userID: 0),
            ProcessTreeEntry(pid: 201, parentPID: 1, memoryBytes: 0, executablePath: "/usr/libexec/trustd")
        ])

        let summary = SystemProcessSampler.summarize(
            tree: tree,
            appPIDs: [100],
            memoryByPID: [100: 900, 101: 800, 200: 300, 201: 500]
        )

        XCTAssertEqual(summary.processes.map(\.pid), [201, 200])
        XCTAssertEqual(summary.processes.map(\.name), ["trustd", "mds"])
        XCTAssertEqual(summary.totalMemoryBytes, 800)
        XCTAssertTrue(summary.processes[1].isRoot)
    }

    func testSummarizeDropsProcessesWithoutMemoryReading() {
        let tree = ProcessTreeSnapshot(entries: [
            ProcessTreeEntry(pid: 200, parentPID: 1, memoryBytes: 0, executablePath: "/usr/libexec/mds")
        ])

        XCTAssertTrue(SystemProcessSampler.summarize(tree: tree, appPIDs: [], memoryByPID: [:]).processes.isEmpty)
    }

    func testCriticalProcessesAreProtected() {
        XCTAssertTrue(SystemProcessTerminator.isProtected(ProcessTreeEntry(pid: 1, parentPID: 0, memoryBytes: 0, executablePath: "/sbin/launchd")))
        XCTAssertTrue(SystemProcessTerminator.isProtected(ProcessTreeEntry(pid: 400, parentPID: 1, memoryBytes: 0, executablePath: "/System/Library/PrivateFrameworks/SkyLight.framework/Resources/WindowServer")))
        XCTAssertTrue(SystemProcessTerminator.isProtected(ProcessTreeEntry(pid: ProcessInfo.processInfo.processIdentifier, parentPID: 1, memoryBytes: 0)))
        XCTAssertFalse(SystemProcessTerminator.isProtected(ProcessTreeEntry(pid: 500, parentPID: 1, memoryBytes: 0, executablePath: "/usr/libexec/mds")))
    }

    func testTerminateRefusesProtectedProcess() {
        let entry = ProcessTreeEntry(pid: 1, parentPID: 0, memoryBytes: 0, executablePath: "/sbin/launchd", userID: 0)

        XCTAssertEqual(SystemProcessTerminator.terminate(entry), .failed("protected system process"))
    }
}
