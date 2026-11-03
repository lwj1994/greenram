import XCTest
@testable import MacAotoKillCore

final class IdleChildProcessReaperTests: XCTestCase {
    private final class TerminatorSpy: ProcessGroupTerminating {
        private(set) var terminatedPIDs: [[pid_t]] = []
        var result = true

        func terminate(_ entries: [ProcessTreeEntry]) -> Bool {
            terminatedPIDs.append(entries.map(\.pid))
            return result
        }
    }

    private final class LoggerSpy: EventLogging {
        private(set) var messages: [String] = []

        func append(_ message: String) {
            messages.append(message)
        }
    }

    private let megabyte: UInt64 = 1024 * 1024
    private let gigabyte: UInt64 = 1024 * 1024 * 1024
    private let start = Date(timeIntervalSince1970: 1_000_000)

    func testTerminatesWholeIdleChainUnderWhitelistedApp() {
        let terminator = TerminatorSpy()
        let logger = LoggerSpy()
        let reaper = makeReaper(terminator: terminator, logger: logger)

        reaper.observe(claudeTree(), now: start)
        let groups = reaper.reap(claudeTree(), apps: [claudeApp()], now: start.addingTimeInterval(31 * 60))

        XCTAssertEqual(groups.map { $0.entries.map(\.pid) }, [[300, 301, 302, 303]])
        XCTAssertEqual(terminator.terminatedPIDs, [[300, 301, 302, 303]])
        XCTAssertEqual(logger.messages.count, 1)
        XCTAssertTrue(logger.messages[0].contains("Claude"))
        XCTAssertTrue(logger.messages[0].contains("bash[300], puro[301], dart[302], dart[303]"))
        XCTAssertTrue(logger.messages[0].contains("idle 31 min"))
    }

    func testCPUActivityAnywhereInGroupKeepsItAlive() {
        let terminator = TerminatorSpy()
        let reaper = makeReaper(terminator: terminator)

        reaper.observe(claudeTree(analyzerCPU: 100), now: start)
        reaper.observe(claudeTree(analyzerCPU: 105), now: start.addingTimeInterval(20 * 60))
        reaper.reap(claudeTree(analyzerCPU: 105), apps: [claudeApp()], now: start.addingTimeInterval(31 * 60))
        XCTAssertTrue(terminator.terminatedPIDs.isEmpty)

        reaper.reap(claudeTree(analyzerCPU: 105), apps: [claudeApp()], now: start.addingTimeInterval(51 * 60))
        XCTAssertEqual(terminator.terminatedPIDs, [[300, 301, 302, 303]])
    }

    func testSlowCPUDriftStillCountsAsIdle() {
        let terminator = TerminatorSpy()
        let reaper = makeReaper(terminator: terminator)

        reaper.observe(claudeTree(analyzerCPU: 100), now: start)
        reaper.observe(claudeTree(analyzerCPU: 101), now: start.addingTimeInterval(10 * 60))
        reaper.observe(claudeTree(analyzerCPU: 102), now: start.addingTimeInterval(20 * 60))
        reaper.reap(claudeTree(analyzerCPU: 102.5), apps: [claudeApp()], now: start.addingTimeInterval(31 * 60))

        XCTAssertEqual(terminator.terminatedPIDs, [[300, 301, 302, 303]])
    }

    func testProcessesNotObservedLongEnoughAreKept() {
        let terminator = TerminatorSpy()
        let reaper = makeReaper(terminator: terminator)

        reaper.reap(claudeTree(), apps: [claudeApp()], now: start)
        reaper.reap(claudeTree(), apps: [claudeApp()], now: start.addingTimeInterval(29 * 60))

        XCTAssertTrue(terminator.terminatedPIDs.isEmpty)
    }

    func testFrontmostAppChildrenAreKept() {
        let terminator = TerminatorSpy()
        let reaper = makeReaper(terminator: terminator)

        reaper.observe(claudeTree(), now: start)
        reaper.reap(claudeTree(), apps: [claudeApp(isFrontmost: true)], now: start.addingTimeInterval(31 * 60))

        XCTAssertTrue(terminator.terminatedPIDs.isEmpty)
    }

    func testGroupsBelowMemoryFloorAreKept() {
        let terminator = TerminatorSpy()
        let reaper = makeReaper(terminator: terminator)
        let tree = claudeTree(analyzerMemory: 10 * megabyte)

        reaper.observe(tree, now: start)
        reaper.reap(tree, apps: [claudeApp()], now: start.addingTimeInterval(31 * 60))

        XCTAssertTrue(terminator.terminatedPIDs.isEmpty)
    }

    func testGroupContainingGreenRAMItselfIsKept() {
        let terminator = TerminatorSpy()
        let reaper = makeReaper(terminator: terminator)
        let tree = ProcessTreeSnapshot(entries: [
            entry(100, parent: 1, path: "/Applications/Claude.app/Contents/MacOS/Claude", memory: 500 * megabyte),
            entry(300, parent: 100, path: "/bin/bash", memory: 2 * megabyte),
            entry(ProcessInfo.processInfo.processIdentifier, parent: 300, path: "/Users/me/greenram/.build/debug/GreenRAM", memory: gigabyte)
        ])

        reaper.observe(tree, now: start)
        reaper.reap(tree, apps: [claudeApp()], now: start.addingTimeInterval(31 * 60))

        XCTAssertTrue(terminator.terminatedPIDs.isEmpty)
    }

    func testTerminalJobsAndBundledHelpersAreKept() {
        let terminator = TerminatorSpy()
        let reaper = makeReaper(terminator: terminator)
        let tree = ProcessTreeSnapshot(entries: [
            entry(500, parent: 1, path: "/Applications/Ghostty.app/Contents/MacOS/ghostty", memory: 200 * megabyte),
            entry(501, parent: 500, path: "/usr/bin/login", memory: megabyte, tty: true),
            entry(502, parent: 501, path: "/bin/zsh", memory: 5 * megabyte, tty: true),
            entry(503, parent: 502, path: "/Users/me/.puro/dart-sdk/bin/dart", memory: 5 * gigabyte, tty: true),
            entry(600, parent: 1, path: "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome", memory: gigabyte),
            entry(601, parent: 600, path: "/Applications/Google Chrome.app/Contents/Frameworks/Helper.app/Contents/MacOS/Google Chrome Helper", memory: 2 * gigabyte)
        ])
        let apps = [
            makeApp(pid: 500, bundleID: "com.mitchellh.ghostty", name: "Ghostty"),
            makeApp(pid: 600, bundleID: "com.google.Chrome", name: "Chrome")
        ]

        reaper.observe(tree, now: start)
        reaper.reap(tree, apps: apps, now: start.addingTimeInterval(31 * 60))

        XCTAssertTrue(terminator.terminatedPIDs.isEmpty)
    }

    func testFailedGroupIsLoggedOnceAndNotRetried() {
        let terminator = TerminatorSpy()
        terminator.result = false
        let logger = LoggerSpy()
        let reaper = makeReaper(terminator: terminator, logger: logger)

        reaper.observe(claudeTree(), now: start)
        reaper.reap(claudeTree(), apps: [claudeApp()], now: start.addingTimeInterval(31 * 60))
        reaper.reap(claudeTree(), apps: [claudeApp()], now: start.addingTimeInterval(32 * 60))

        XCTAssertEqual(terminator.terminatedPIDs.count, 1)
        XCTAssertEqual(logger.messages, ["Failed to clean idle child processes of Claude: bash[300], puro[301], dart[302], dart[303]"])
    }

    func testChildProcessSummariesGroupByLabelAndMarkCleanable() {
        let summaries = ChildProcessSummary.summaries(
            appPID: 100,
            in: claudeTree(),
            cleanablePIDs: [300, 301, 302, 303],
            label: { $0.name }
        )

        XCTAssertEqual(summaries.first, ChildProcessSummary(
            label: "dart",
            processCount: 2,
            memoryBytes: 9 * gigabyte + 40 * megabyte,
            cleanableCount: 2
        ))
        XCTAssertEqual(summaries.map(\.label), ["dart", "claude", "node", "puro", "bash", "disclaimer"])
        XCTAssertEqual(summaries.first { $0.label == "node" }?.cleanableCount, 0)
    }

    /// Claude.app → disclaimer → claude CLI → bash → puro → dart mcp-server → dart language-server，
    /// claude CLI 下还有一个小的 node MCP。
    private func claudeTree(analyzerCPU: TimeInterval = 100, analyzerMemory: UInt64? = nil) -> ProcessTreeSnapshot {
        ProcessTreeSnapshot(entries: [
            entry(100, parent: 1, path: "/Applications/Claude.app/Contents/MacOS/Claude", memory: 500 * megabyte),
            entry(101, parent: 100, path: "/Applications/Claude.app/Contents/Helpers/disclaimer", memory: megabyte),
            entry(200, parent: 101, path: "/Users/me/Library/Application Support/Claude/claude-code/claude.app/Contents/MacOS/claude", memory: 350 * megabyte),
            entry(300, parent: 200, path: "/bin/bash", memory: 2 * megabyte),
            entry(301, parent: 300, path: "/Users/me/.puro/bin/puro", memory: 20 * megabyte),
            entry(302, parent: 301, path: "/Users/me/.puro/dart-sdk/bin/dart", memory: 40 * megabyte),
            entry(303, parent: 302, path: "/Users/me/.puro/dart-sdk/bin/dart", memory: analyzerMemory ?? 9 * gigabyte, cpu: analyzerCPU),
            entry(310, parent: 200, path: "/opt/homebrew/bin/node", memory: 60 * megabyte)
        ])
    }

    private func entry(
        _ pid: pid_t,
        parent: pid_t,
        path: String,
        memory: UInt64,
        cpu: TimeInterval = 10,
        tty: Bool = false
    ) -> ProcessTreeEntry {
        ProcessTreeEntry(
            pid: pid,
            parentPID: parent,
            memoryBytes: memory,
            name: (path as NSString).lastPathComponent,
            executablePath: path,
            cpuTime: cpu,
            startTime: 1_000,
            hasControllingTerminal: tty
        )
    }

    private func claudeApp(isFrontmost: Bool = false) -> AppRuntimeState {
        makeApp(pid: 100, bundleID: "com.anthropic.claudefordesktop", name: "Claude", isFrontmost: isFrontmost)
    }

    private func makeApp(pid: pid_t, bundleID: String, name: String, isFrontmost: Bool = false) -> AppRuntimeState {
        AppRuntimeState(
            pid: pid,
            bundleID: bundleID,
            displayName: name,
            launchDate: nil,
            lastForegroundAt: nil,
            lastBackgroundAt: nil,
            memoryBytes: 0,
            isFrontmost: isFrontmost,
            isWhitelisted: true
        )
    }

    private func makeReaper(terminator: TerminatorSpy, logger: LoggerSpy? = nil) -> IdleChildProcessReaper {
        IdleChildProcessReaper(
            terminator: terminator,
            logger: logger,
            localizerProvider: { Localizer(languageCode: "en") },
            labelProvider: { $0.name }
        )
    }
}
