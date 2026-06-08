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
        let idleLongEnough = makeApp(bundleID: "test.idle-shopper", name: "Idle Shopper", lastBackgroundAt: now.addingTimeInterval(-31 * 60))
        let alsoIdleLongEnough = makeApp(bundleID: "test.browser", name: "Browser", lastBackgroundAt: now.addingTimeInterval(-45 * 60))
        let engine = makeEngine(autoQuitDurations: [
            "test.idle-shopper": 30 * 60,
            "test.browser": 30 * 60
        ])

        let candidates = engine.candidates(for: [idleLongEnough, alsoIdleLongEnough], now: now)

        XCTAssertEqual(Set(candidates.map(\.displayName)), ["Idle Shopper", "Browser"])
    }

    func testUnlistedAppsRequireMemoryLimitAndDefaultBackgroundThreshold() {
        let now = Date()
        let listedApp = makeApp(bundleID: "test.listed", name: "Listed", lastBackgroundAt: now.addingTimeInterval(-31 * 60))
        let idleUnlistedApp = makeApp(bundleID: "test.unlisted-idle", name: "Unlisted Idle", lastBackgroundAt: now.addingTimeInterval(-31 * 60))
        let recentUnlistedApp = makeApp(bundleID: "test.unlisted-recent", name: "Unlisted Recent", lastBackgroundAt: now.addingTimeInterval(-29 * 60))
        let belowLimitEngine = makeEngine(autoQuitDurations: [
            "test.listed": 30 * 60
        ])
        let exceededLimitEngine = makeEngine(
            autoQuitDurations: ["test.listed": 30 * 60],
            isMemoryLimitExceeded: true
        )

        let apps = [listedApp, idleUnlistedApp, recentUnlistedApp]

        XCTAssertEqual(belowLimitEngine.candidates(for: apps, now: now).map(\.bundleID), ["test.listed"])
        XCTAssertEqual(Set(exceededLimitEngine.candidates(for: apps, now: now).map(\.bundleID)), ["test.listed", "test.unlisted-idle"])
    }

    func testAutoQuitAppsDoNotWaitForMemoryLimit() {
        let now = Date()
        let engine = makeEngine(autoQuitDurations: [
            "test.auto-quit": 30 * 60
        ])
        let app = makeApp(bundleID: "test.auto-quit", name: "Auto Quit", lastBackgroundAt: now.addingTimeInterval(-31 * 60))

        XCTAssertEqual(engine.candidates(for: [app], now: now).map(\.bundleID), ["test.auto-quit"])
    }

    func testPolicyNeverTargetsFrontmostWhitelistedOrRecentlyBackgroundedApps() {
        let now = Date()
        let engine = makeEngine(
            autoQuitDurations: [
                "test.front": 30 * 60,
                "test.pinned": 30 * 60,
                "test.recent": 30 * 60
            ],
            isMemoryLimitExceeded: true
        )
        let apps = [
            makeApp(bundleID: "test.front", name: "Front", lastBackgroundAt: now.addingTimeInterval(-31 * 60), isFrontmost: true),
            makeApp(bundleID: "test.pinned", name: "Pinned", lastBackgroundAt: now.addingTimeInterval(-31 * 60), isWhitelisted: true),
            makeApp(bundleID: "test.recent", name: "Recent", lastBackgroundAt: now.addingTimeInterval(-29 * 60))
        ]

        let candidates = engine.candidates(for: apps, now: now)

        XCTAssertTrue(candidates.isEmpty)
    }

    func testAutomaticReleaseForceQuitsAtMostConfiguredNumberOfApps() {
        let now = Date()
        let terminator = TerminatorSpy()
        let logger = LoggerSpy()
        let bundleIDs = (0..<4).map { "test.app-\($0)" }
        let engine = MemoryPolicyEngine(
            configuration: MemoryPolicyConfiguration(
                minimumBackgroundDurationsByBundleID: Dictionary(uniqueKeysWithValues: bundleIDs.map { ($0, 30 * 60) }),
                maxAppsPerSweep: 2
            ),
            terminator: terminator,
            logger: logger
        )
        let apps = (0..<4).map {
            makeApp(
                pid: pid_t(1_000 + $0),
                bundleID: "test.app-\($0)",
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
            configuration: MemoryPolicyConfiguration(
                autoReleaseEnabled: false,
                minimumBackgroundDurationsByBundleID: ["test.background": 30 * 60]
            ),
            terminator: terminator,
            logger: logger
        )
        let app = makeApp(
            pid: 1_000,
            bundleID: "test.background",
            name: "Background App",
            lastBackgroundAt: now.addingTimeInterval(-31 * 60),
            memoryBytes: 512 * 1024 * 1024
        )

        engine.handleManualRelease(states: [app], now: now)

        XCTAssertEqual(terminator.forceQuitApps.map(\.displayName), ["Background App"])
    }

    func testAutoQuitListUsesPerAppBackgroundThresholds() {
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

        XCTAssertEqual(candidates.map(\.bundleID), ["test.short"])
    }

    func testDuplicateQuitCooldownUsesBundleID() {
        let now = Date()
        let terminator = TerminatorSpy()
        let logger = LoggerSpy()
        let engine = MemoryPolicyEngine(
            configuration: MemoryPolicyConfiguration(
                minimumBackgroundDurationsByBundleID: ["test.same-app": 30 * 60]
            ),
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
            configuration: MemoryPolicyConfiguration(
                minimumBackgroundDurationsByBundleID: [
                    "test.original": 30 * 60,
                    "test.reused-pid": 30 * 60
                ]
            ),
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

    private func makeEngine(
        autoQuitDurations: [String: TimeInterval] = [:],
        isMemoryLimitExceeded: Bool = false
    ) -> MemoryPolicyEngine {
        MemoryPolicyEngine(
            configuration: MemoryPolicyConfiguration(
                minimumBackgroundDurationsByBundleID: autoQuitDurations,
                isMemoryLimitExceeded: isMemoryLimitExceeded
            ),
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
