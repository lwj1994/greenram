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

    func testCandidatesIncludeLowAndMediumRiskBackgroundApps() {
        let now = Date()
        let lowRisk = makeApp(name: "Idle Shopper", lastBackgroundAt: now.addingTimeInterval(-60), risk: .low)
        let mediumRisk = makeApp(name: "Browser", lastBackgroundAt: now.addingTimeInterval(-60), risk: .medium)
        let engine = makeEngine()

        let candidates = engine.candidates(for: [lowRisk, mediumRisk], now: now)

        XCTAssertEqual(Set(candidates.map(\.displayName)), ["Idle Shopper", "Browser"])
    }

    func testPolicyNeverTargetsFrontmostWhitelistedOrHighRiskApps() {
        let now = Date()
        let engine = makeEngine()
        let apps = [
            makeApp(name: "Front", lastBackgroundAt: now.addingTimeInterval(-60), isFrontmost: true),
            makeApp(name: "Pinned", lastBackgroundAt: now.addingTimeInterval(-60), isWhitelisted: true),
            makeApp(name: "Terminal", lastBackgroundAt: now.addingTimeInterval(-60), risk: .high)
        ]

        let candidates = engine.candidates(for: apps, now: now)

        XCTAssertTrue(candidates.isEmpty)
    }

    func testHandleLimitExceededForceQuitsAtMostConfiguredNumberOfApps() {
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
                lastBackgroundAt: now.addingTimeInterval(-60),
                memoryBytes: UInt64(300 + $0) * 1024 * 1024,
                risk: .low
            )
        }

        engine.handleLimitExceeded(states: apps, now: now)

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
            lastBackgroundAt: now.addingTimeInterval(-60),
            memoryBytes: 512 * 1024 * 1024,
            risk: .low
        )

        engine.handleManualRelease(states: [app], now: now)

        XCTAssertEqual(terminator.forceQuitApps.map(\.displayName), ["Background App"])
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
        name: String,
        lastBackgroundAt: Date?,
        memoryBytes: UInt64 = 512 * 1024 * 1024,
        isFrontmost: Bool = false,
        isWhitelisted: Bool = false,
        risk: RiskLevel = .low
    ) -> AppRuntimeState {
        AppRuntimeState(
            pid: pid,
            bundleID: "test.\(name.replacingOccurrences(of: " ", with: "-"))",
            displayName: name,
            launchDate: nil,
            lastForegroundAt: nil,
            lastBackgroundAt: lastBackgroundAt,
            memoryBytes: memoryBytes,
            isFrontmost: isFrontmost,
            isWhitelisted: isWhitelisted,
            riskLevel: risk
        )
    }
}
