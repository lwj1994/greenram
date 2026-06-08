import XCTest
@testable import MacAotoKillCore

final class MemoryPolicyEngineTests: XCTestCase {
    private final class TerminatorSpy: AppTerminating {
        private(set) var quitApps: [AppRuntimeState] = []
        private(set) var forceQuitApps: [AppRuntimeState] = []

        func requestQuit(_ app: AppRuntimeState, forceIfNeeded: Bool) {
            quitApps.append(app)
        }

        func forceQuit(_ app: AppRuntimeState) {
            forceQuitApps.append(app)
        }
    }

    private final class LoggerSpy: EventLogging {
        private(set) var messages: [String] = []

        func append(_ message: String) {
            messages.append(message)
        }
    }

    func testCandidatesIncludeAppsPastBackgroundThreshold() {
        let now = Date()
        let idleLongEnough = makeApp(name: "Idle Shopper", lastBackgroundAt: now.addingTimeInterval(-31 * 60))
        let alsoIdleLongEnough = makeApp(name: "Browser", lastBackgroundAt: now.addingTimeInterval(-45 * 60))
        let engine = makeEngine()

        let candidates = engine.candidates(for: [idleLongEnough, alsoIdleLongEnough], now: now)

        XCTAssertEqual(Set(candidates.map(\.displayName)), ["Idle Shopper", "Browser"])
    }

    func testPolicyNeverTargetsFrontmostWhitelistedOrRecentlyBackgroundedApps() {
        let now = Date()
        let engine = makeEngine()
        let apps = [
            makeApp(name: "Front", lastBackgroundAt: now.addingTimeInterval(-31 * 60), isFrontmost: true),
            makeApp(name: "Pinned", lastBackgroundAt: now.addingTimeInterval(-31 * 60), isWhitelisted: true),
            makeApp(name: "Recent", lastBackgroundAt: now.addingTimeInterval(-29 * 60))
        ]

        let candidates = engine.candidates(for: apps, now: now)

        XCTAssertTrue(candidates.isEmpty)
    }

    func testAutomaticReleaseForceQuitsAtMostConfiguredNumberOfApps() {
        let now = Date()
        let terminator = TerminatorSpy()
        let logger = LoggerSpy()
        let engine = MemoryPolicyEngine(
            configuration: MemoryPolicyConfiguration(maxAppsPerSweep: 2),
            terminator: terminator,
            logger: logger
        )
        let apps = (0..<4).map {
            makeApp(
                pid: pid_t(1_000 + $0),
                name: "App \($0)",
                lastBackgroundAt: now.addingTimeInterval(-31 * 60),
                memoryBytes: UInt64(300 + $0) * 1024 * 1024
            )
        }

        engine.handleAutomaticRelease(states: apps, now: now)

        XCTAssertEqual(terminator.forceQuitApps.count, 2)
        XCTAssertTrue(terminator.quitApps.isEmpty)
    }

    func testManualReleaseIgnoresAutoReleaseSwitch() {
        let now = Date()
        let terminator = TerminatorSpy()
        let logger = LoggerSpy()
        let engine = MemoryPolicyEngine(
            configuration: MemoryPolicyConfiguration(autoReleaseEnabled: false),
            terminator: terminator,
            logger: logger
        )
        let app = makeApp(
            pid: 1_000,
            name: "Background App",
            lastBackgroundAt: now.addingTimeInterval(-31 * 60),
            memoryBytes: 512 * 1024 * 1024
        )

        engine.handleManualRelease(states: [app], now: now)

        XCTAssertEqual(terminator.forceQuitApps.map(\.displayName), ["Background App"])
    }

    func testPerAppBackgroundThresholdOverridesGlobalThreshold() {
        let now = Date()
        let engine = MemoryPolicyEngine(
            configuration: MemoryPolicyConfiguration(
                minimumBackgroundDuration: 30 * 60,
                minimumBackgroundDurationsByBundleID: [
                    "test.short": 10 * 60,
                    "test.long": 60 * 60
                ]
            ),
            terminator: TerminatorSpy(),
            logger: LoggerSpy()
        )
        let shortOverrideApp = makeApp(
            bundleID: "test.short",
            name: "Short Override",
            lastBackgroundAt: now.addingTimeInterval(-11 * 60)
        )
        let globalApp = makeApp(
            bundleID: "test.global",
            name: "Global",
            lastBackgroundAt: now.addingTimeInterval(-31 * 60)
        )
        let longOverrideApp = makeApp(
            bundleID: "test.long",
            name: "Long Override",
            lastBackgroundAt: now.addingTimeInterval(-31 * 60)
        )

        let candidates = engine.candidates(for: [shortOverrideApp, globalApp, longOverrideApp], now: now)

        XCTAssertEqual(Set(candidates.map(\.bundleID)), ["test.short", "test.global"])
    }

    func testDuplicateQuitCooldownUsesBundleID() {
        let now = Date()
        let terminator = TerminatorSpy()
        let logger = LoggerSpy()
        let engine = MemoryPolicyEngine(
            configuration: MemoryPolicyConfiguration(),
            terminator: terminator,
            logger: logger
        )
        let firstInstance = makeApp(
            pid: 1_000,
            bundleID: "test.same-app",
            name: "Same App",
            lastBackgroundAt: now.addingTimeInterval(-31 * 60)
        )
        let relaunchedInstance = makeApp(
            pid: 2_000,
            bundleID: "test.same-app",
            name: "Same App",
            lastBackgroundAt: now.addingTimeInterval(-31 * 60)
        )

        engine.handleAutomaticRelease(states: [firstInstance], now: now)
        engine.handleAutomaticRelease(states: [relaunchedInstance], now: now.addingTimeInterval(60))

        XCTAssertEqual(terminator.forceQuitApps.map(\.pid), [1_000])
    }

    func testDuplicateQuitCooldownAllowsSamePIDWithDifferentBundleID() {
        let now = Date()
        let terminator = TerminatorSpy()
        let logger = LoggerSpy()
        let engine = MemoryPolicyEngine(
            configuration: MemoryPolicyConfiguration(),
            terminator: terminator,
            logger: logger
        )
        let originalApp = makeApp(
            pid: 1_000,
            bundleID: "test.original",
            name: "Original",
            lastBackgroundAt: now.addingTimeInterval(-31 * 60)
        )
        let reusedPIDApp = makeApp(
            pid: 1_000,
            bundleID: "test.reused-pid",
            name: "Reused PID",
            lastBackgroundAt: now.addingTimeInterval(-31 * 60)
        )

        engine.handleAutomaticRelease(states: [originalApp], now: now)
        engine.handleAutomaticRelease(states: [reusedPIDApp], now: now.addingTimeInterval(60))

        XCTAssertEqual(terminator.forceQuitApps.map(\.bundleID), ["test.original", "test.reused-pid"])
    }

    private func makeEngine() -> MemoryPolicyEngine {
        MemoryPolicyEngine(
            configuration: MemoryPolicyConfiguration(),
            terminator: TerminatorSpy(),
            logger: LoggerSpy()
        )
    }

    private func makeApp(
        pid: pid_t = 999,
        bundleID: String? = nil,
        name: String,
        lastBackgroundAt: Date?,
        memoryBytes: UInt64 = 512 * 1024 * 1024,
        isFrontmost: Bool = false,
        isWhitelisted: Bool = false
    ) -> AppRuntimeState {
        AppRuntimeState(
            pid: pid,
            bundleID: bundleID ?? "test.\(name.replacingOccurrences(of: " ", with: "-"))",
            displayName: name,
            launchDate: nil,
            lastForegroundAt: nil,
            lastBackgroundAt: lastBackgroundAt,
            memoryBytes: memoryBytes,
            isFrontmost: isFrontmost,
            isWhitelisted: isWhitelisted
        )
    }
}
