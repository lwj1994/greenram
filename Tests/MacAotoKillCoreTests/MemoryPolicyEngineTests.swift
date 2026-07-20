import XCTest
@testable import MacAotoKillCore

final class MemoryPolicyEngineTests: XCTestCase {
    private final class TerminatorSpy: AppTerminating {
        private(set) var quitApps: [AppRuntimeState] = []
        private(set) var forceQuitApps: [AppRuntimeState] = []

        var shouldSucceed = true

        func requestQuit(_ app: AppRuntimeState, forceIfNeeded: Bool) -> Bool {
            quitApps.append(app)
            return shouldSucceed
        }

        func forceQuit(_ app: AppRuntimeState) -> Bool {
            forceQuitApps.append(app)
            return shouldSucceed
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
        let engine = makeEngine(autoQuitBundleIDs: ["test.idle-shopper", "test.browser"])

        let candidates = engine.candidates(for: [idleLongEnough, alsoIdleLongEnough], now: now)

        XCTAssertEqual(Set(candidates.map(\.displayName)), ["Idle Shopper", "Browser"])
    }

    func testUnlistedAppsRequireMemoryLimitAndDefaultBackgroundThreshold() {
        let now = Date()
        let listedApp = makeApp(bundleID: "test.listed", name: "Listed", lastBackgroundAt: now.addingTimeInterval(-31 * 60))
        let idleUnlistedApp = makeApp(bundleID: "test.unlisted-idle", name: "Unlisted Idle", lastBackgroundAt: now.addingTimeInterval(-31 * 60))
        let recentUnlistedApp = makeApp(bundleID: "test.unlisted-recent", name: "Unlisted Recent", lastBackgroundAt: now.addingTimeInterval(-29 * 60))
        let belowLimitEngine = makeEngine(autoQuitBundleIDs: ["test.listed"])
        let exceededLimitEngine = makeEngine(
            autoQuitBundleIDs: ["test.listed"],
            isMemoryLimitExceeded: true
        )

        let apps = [listedApp, idleUnlistedApp, recentUnlistedApp]

        XCTAssertEqual(belowLimitEngine.candidates(for: apps, now: now).map(\.bundleID), ["test.listed"])
        XCTAssertEqual(Set(exceededLimitEngine.candidates(for: apps, now: now).map(\.bundleID)), ["test.listed", "test.unlisted-idle"])
    }

    func testAutoQuitAppsDoNotWaitForMemoryLimit() {
        let now = Date()
        let engine = makeEngine(autoQuitBundleIDs: ["test.auto-quit"])
        let app = makeApp(bundleID: "test.auto-quit", name: "Auto Quit", lastBackgroundAt: now.addingTimeInterval(-31 * 60))

        XCTAssertEqual(engine.candidates(for: [app], now: now).map(\.bundleID), ["test.auto-quit"])
    }

    func testDecisionExplainsAutoQuitEligibility() {
        let now = Date()
        let engine = makeEngine(autoQuitBundleIDs: ["test.auto-quit"])
        let app = makeApp(
            bundleID: "test.auto-quit",
            name: "Auto Quit",
            lastBackgroundAt: now.addingTimeInterval(-31 * 60)
        )

        let decision = engine.decision(for: app, now: now)

        XCTAssertTrue(decision.isEligible)
        XCTAssertEqual(decision.ruleGroup, .autoQuit)
        XCTAssertEqual(decision.trigger, .autoQuitRule)
        XCTAssertNil(decision.exclusion)
    }

    func testDecisionExplainsBackgroundTimeExclusion() {
        let now = Date()
        let engine = makeEngine(autoQuitBundleIDs: ["test.recent"])
        let app = makeApp(
            bundleID: "test.recent",
            name: "Recent",
            lastBackgroundAt: now.addingTimeInterval(-10 * 60)
        )

        let decision = engine.decision(for: app, now: now)

        XCTAssertFalse(decision.isEligible)
        XCTAssertEqual(decision.ruleGroup, .autoQuit)
        XCTAssertEqual(
            decision.exclusion,
            .backgroundTime(required: 30 * 60, actual: 10 * 60)
        )
    }

    func testDecisionPrefersAppMemoryTriggerWhenBothMemoryGatesAreReached() {
        let now = Date()
        let limit = UInt64(1_024 * 1024 * 1024)
        let engine = makeEngine(
            memoryLimitsByBundleID: ["test.large": limit],
            isMemoryLimitExceeded: true
        )
        let app = makeApp(
            bundleID: "test.large",
            name: "Large",
            lastBackgroundAt: now.addingTimeInterval(-31 * 60),
            memoryBytes: limit + 1
        )

        XCTAssertEqual(engine.decision(for: app, now: now).trigger, .appMemory(limitBytes: limit))
    }

    func testPolicyNeverTargetsFrontmostWhitelistedOrRecentlyBackgroundedApps() {
        let now = Date()
        let engine = makeEngine(
            autoQuitBundleIDs: ["test.front", "test.pinned", "test.recent"],
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

    func testWhitelistOverridesAllCleanupRules() {
        let now = Date()
        let engine = MemoryPolicyEngine(
            configuration: MemoryPolicyConfiguration(
                minimumBackgroundDuration: 30 * 60,
                minimumBackgroundDurationsByBundleID: ["test.protected": TimeInterval(10 * 60)],
                autoQuitBundleIDs: ["test.protected"],
                memoryLimitsByBundleID: ["test.protected": UInt64(512 * 1024 * 1024)],
                isMemoryLimitExceeded: true
            ),
            terminator: TerminatorSpy(),
            logger: LoggerSpy()
        )
        let app = makeApp(
            bundleID: "test.protected",
            name: "Protected",
            lastBackgroundAt: now.addingTimeInterval(-60 * 60),
            memoryBytes: 2 * 1024 * 1024 * 1024,
            isWhitelisted: true
        )

        XCTAssertFalse(engine.shouldTerminate(app, now: now))
        XCTAssertTrue(engine.candidates(for: [app], now: now).isEmpty)
    }

    func testPolicyNeverTargetsOwnBundleIdentifier() {
        let now = Date()
        let engine = makeEngine(
            autoQuitBundleIDs: [AppIdentity.bundleIdentifier],
            isMemoryLimitExceeded: true
        )
        let app = makeApp(
            pid: 42_000,
            bundleID: AppIdentity.bundleIdentifier,
            name: "GreenRAM",
            lastBackgroundAt: now.addingTimeInterval(-31 * 60)
        )

        XCTAssertFalse(engine.shouldTerminate(app, now: now))
        XCTAssertTrue(engine.candidates(for: [app], now: now).isEmpty)
    }

    func testAutomaticReleaseForceQuitsAtMostConfiguredNumberOfApps() {
        let now = Date()
        let terminator = TerminatorSpy()
        let logger = LoggerSpy()
        let bundleIDs = (0..<4).map { "test.app-\($0)" }
        let engine = MemoryPolicyEngine(
            configuration: MemoryPolicyConfiguration(
                autoQuitBundleIDs: Set(bundleIDs),
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

        XCTAssertEqual(terminator.quitApps.count, 2)
        XCTAssertTrue(terminator.forceQuitApps.isEmpty)
    }

    func testManualReleaseIgnoresAutoReleaseSwitch() {
        let now = Date()
        let terminator = TerminatorSpy()
        let logger = LoggerSpy()
        let engine = MemoryPolicyEngine(
            configuration: MemoryPolicyConfiguration(
                autoReleaseEnabled: false,
                autoQuitBundleIDs: ["test.background"]
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

        XCTAssertEqual(terminator.quitApps.map(\.displayName), ["Background App"])
    }

    func testAutoQuitListUsesPerAppBackgroundThresholds() {
        let now = Date()
        let engine = MemoryPolicyEngine(
            configuration: MemoryPolicyConfiguration(
                minimumBackgroundDuration: 30 * 60,
                minimumBackgroundDurationsByBundleID: [
                    "test.short": TimeInterval(10 * 60),
                    "test.long": TimeInterval(60 * 60)
                ],
                autoQuitBundleIDs: ["test.short", "test.long"]
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

    func testPerAppBackgroundThresholdAffectsOrdinaryAppsWithoutMakingThemAutoQuit() {
        let now = Date()
        let recentOrdinaryApp = makeApp(
            bundleID: "test.ordinary",
            name: "Short Ordinary",
            lastBackgroundAt: now.addingTimeInterval(-11 * 60)
        )
        let oldOrdinaryApp = makeApp(
            bundleID: "test.ordinary",
            name: "Old Ordinary",
            lastBackgroundAt: now.addingTimeInterval(-31 * 60)
        )
        let autoQuitApp = makeApp(
            bundleID: "test.auto-short",
            name: "Auto Short",
            lastBackgroundAt: now.addingTimeInterval(-11 * 60)
        )
        let belowLimitEngine = MemoryPolicyEngine(
            configuration: MemoryPolicyConfiguration(
                minimumBackgroundDuration: 30 * 60,
                minimumBackgroundDurationsByBundleID: [
                    "test.ordinary": TimeInterval(10 * 60),
                    "test.auto-short": TimeInterval(10 * 60)
                ],
                autoQuitBundleIDs: ["test.auto-short"]
            ),
            terminator: TerminatorSpy(),
            logger: LoggerSpy()
        )
        let exceededLimitEngine = MemoryPolicyEngine(
            configuration: MemoryPolicyConfiguration(
                minimumBackgroundDuration: 30 * 60,
                minimumBackgroundDurationsByBundleID: [
                    "test.ordinary": TimeInterval(10 * 60),
                    "test.auto-short": TimeInterval(10 * 60)
                ],
                autoQuitBundleIDs: ["test.auto-short"],
                isMemoryLimitExceeded: true
            ),
            terminator: TerminatorSpy(),
            logger: LoggerSpy()
        )

        XCTAssertEqual(belowLimitEngine.candidates(for: [recentOrdinaryApp, autoQuitApp], now: now).map(\.bundleID), ["test.auto-short"])
        XCTAssertEqual(exceededLimitEngine.candidates(for: [recentOrdinaryApp], now: now).map(\.bundleID), ["test.ordinary"])
        XCTAssertEqual(exceededLimitEngine.candidates(for: [oldOrdinaryApp], now: now).map(\.bundleID), ["test.ordinary"])
    }

    func testPerAppMemoryLimitCanGateOrdinaryApps() {
        let now = Date()
        let underLimitApp = makeApp(
            bundleID: "test.memory",
            name: "Under Limit",
            lastBackgroundAt: now.addingTimeInterval(-31 * 60),
            memoryBytes: 900 * 1024 * 1024
        )
        let overLimitApp = makeApp(
            bundleID: "test.memory",
            name: "Over Limit",
            lastBackgroundAt: now.addingTimeInterval(-31 * 60),
            memoryBytes: 1_100 * 1024 * 1024
        )
        let recentOverLimitApp = makeApp(
            bundleID: "test.memory",
            name: "Recent Over Limit",
            lastBackgroundAt: now.addingTimeInterval(-29 * 60),
            memoryBytes: 1_100 * 1024 * 1024
        )
        let engine = MemoryPolicyEngine(
            configuration: MemoryPolicyConfiguration(
                minimumBackgroundDuration: 30 * 60,
                memoryLimitsByBundleID: ["test.memory": UInt64(1_024 * 1024 * 1024)]
            ),
            terminator: TerminatorSpy(),
            logger: LoggerSpy()
        )

        XCTAssertTrue(engine.candidates(for: [underLimitApp], now: now).isEmpty)
        XCTAssertTrue(engine.candidates(for: [recentOverLimitApp], now: now).isEmpty)
        XCTAssertEqual(engine.candidates(for: [overLimitApp], now: now).map(\.bundleID), ["test.memory"])
    }

    func testPerAppMemoryLimitUsesPerAppBackgroundThreshold() {
        let now = Date()
        let app = makeApp(
            bundleID: "test.short-memory",
            name: "Short Memory",
            lastBackgroundAt: now.addingTimeInterval(-11 * 60),
            memoryBytes: 1_100 * 1024 * 1024
        )
        let engine = MemoryPolicyEngine(
            configuration: MemoryPolicyConfiguration(
                minimumBackgroundDuration: 30 * 60,
                minimumBackgroundDurationsByBundleID: ["test.short-memory": TimeInterval(10 * 60)],
                memoryLimitsByBundleID: ["test.short-memory": UInt64(1_024 * 1024 * 1024)]
            ),
            terminator: TerminatorSpy(),
            logger: LoggerSpy()
        )

        XCTAssertEqual(engine.candidates(for: [app], now: now).map(\.bundleID), ["test.short-memory"])
    }

    func testDuplicateQuitCooldownUsesBundleID() {
        let now = Date()
        let terminator = TerminatorSpy()
        let logger = LoggerSpy()
        let engine = MemoryPolicyEngine(
            configuration: MemoryPolicyConfiguration(
                autoQuitBundleIDs: ["test.same-app"]
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

        XCTAssertEqual(terminator.quitApps.map(\.pid), [1_000])
    }

    func testDuplicateQuitCooldownAllowsSamePIDWithDifferentBundleID() {
        let now = Date()
        let terminator = TerminatorSpy()
        let logger = LoggerSpy()
        let engine = MemoryPolicyEngine(
            configuration: MemoryPolicyConfiguration(
                autoQuitBundleIDs: ["test.original", "test.reused-pid"]
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

        XCTAssertEqual(terminator.quitApps.map(\.bundleID), ["test.original", "test.reused-pid"])
    }

    func testFailedQuitRequestDoesNotStartDuplicateCooldown() {
        let now = Date()
        let terminator = TerminatorSpy()
        terminator.shouldSucceed = false
        let engine = MemoryPolicyEngine(
            configuration: MemoryPolicyConfiguration(autoQuitBundleIDs: ["test.retry"]),
            terminator: terminator,
            logger: LoggerSpy()
        )
        let app = makeApp(
            pid: 1_000,
            bundleID: "test.retry",
            name: "Retry",
            lastBackgroundAt: now.addingTimeInterval(-31 * 60)
        )

        engine.handleAutomaticRelease(states: [app], now: now)
        engine.handleAutomaticRelease(states: [app], now: now.addingTimeInterval(60))

        XCTAssertEqual(terminator.quitApps.count, 2)
    }

    func testExplicitImmediateTerminationUsesForceQuit() {
        let now = Date()
        let terminator = TerminatorSpy()
        let engine = MemoryPolicyEngine(
            configuration: MemoryPolicyConfiguration(
                autoQuitBundleIDs: ["test.force"],
                forceTerminateImmediately: true
            ),
            terminator: terminator,
            logger: LoggerSpy()
        )
        let app = makeApp(
            bundleID: "test.force",
            name: "Force",
            lastBackgroundAt: now.addingTimeInterval(-31 * 60)
        )

        engine.handleAutomaticRelease(states: [app], now: now)

        XCTAssertEqual(terminator.forceQuitApps.map(\.bundleID), ["test.force"])
        XCTAssertTrue(terminator.quitApps.isEmpty)
    }

    private func makeEngine(
        autoQuitBundleIDs: Set<String> = [],
        customBackgroundDurations: [String: TimeInterval] = [:],
        memoryLimitsByBundleID: [String: UInt64] = [:],
        isMemoryLimitExceeded: Bool = false
    ) -> MemoryPolicyEngine {
        MemoryPolicyEngine(
            configuration: MemoryPolicyConfiguration(
                minimumBackgroundDurationsByBundleID: customBackgroundDurations,
                autoQuitBundleIDs: autoQuitBundleIDs,
                memoryLimitsByBundleID: memoryLimitsByBundleID,
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
