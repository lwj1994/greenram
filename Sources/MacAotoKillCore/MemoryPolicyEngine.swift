import Darwin
import Foundation

public struct MemoryPolicyConfiguration: Equatable {
    public var autoReleaseEnabled: Bool
    public var minimumMemoryBytes: UInt64
    public var maxAppsPerSweep: Int
    public var forceTerminateImmediately: Bool

    public init(
        autoReleaseEnabled: Bool = true,
        minimumMemoryBytes: UInt64 = 250 * 1024 * 1024,
        maxAppsPerSweep: Int = 3,
        forceTerminateImmediately: Bool = true
    ) {
        self.autoReleaseEnabled = autoReleaseEnabled
        self.minimumMemoryBytes = minimumMemoryBytes
        self.maxAppsPerSweep = maxAppsPerSweep
        self.forceTerminateImmediately = forceTerminateImmediately
    }
}

public final class MemoryPolicyEngine {
    public var configuration: MemoryPolicyConfiguration
    private weak var terminator: AppTerminating?
    private weak var logger: EventLogging?
    private var recentQuitRequestsByPID: [pid_t: Date] = [:]
    private let duplicateQuitCooldown: TimeInterval = 10 * 60
    private let localizerProvider: () -> Localizer

    public init(
        configuration: MemoryPolicyConfiguration = MemoryPolicyConfiguration(),
        terminator: AppTerminating?,
        logger: EventLogging?,
        localizerProvider: @escaping () -> Localizer = { Localizer() }
    ) {
        self.configuration = configuration
        self.terminator = terminator
        self.logger = logger
        self.localizerProvider = localizerProvider
    }

    public func handleLimitExceeded(
        states: [AppRuntimeState],
        now: Date = Date()
    ) {
        handleRelease(states: states, now: now, respectsAutoReleaseSetting: true)
    }

    public func handleManualRelease(
        states: [AppRuntimeState],
        now: Date = Date()
    ) {
        handleRelease(states: states, now: now, respectsAutoReleaseSetting: false)
    }

    private func handleRelease(
        states: [AppRuntimeState],
        now: Date,
        respectsAutoReleaseSetting: Bool
    ) {
        guard !respectsAutoReleaseSetting || configuration.autoReleaseEnabled else {
            logger?.append(localizerProvider().t("event.autoReleaseDisabledIgnored"))
            return
        }

        let targets = candidates(for: states, now: now)
            .filter { !hasRecentQuitRequest(for: $0.pid, now: now) }
            .prefix(configuration.maxAppsPerSweep)

        guard !targets.isEmpty else {
            logger?.append(localizerProvider().t("event.noEligibleApps"))
            return
        }

        for app in targets {
            recentQuitRequestsByPID[app.pid] = now
            if configuration.forceTerminateImmediately {
                terminator?.forceQuit(app)
            } else {
                terminator?.requestQuit(app, forceIfNeeded: false)
            }
        }
    }

    public func candidates(
        for states: [AppRuntimeState],
        now: Date = Date()
    ) -> [AppRuntimeState] {
        states
            .filter { shouldTerminate($0) }
            .sorted { score($0, now: now) > score($1, now: now) }
    }

    public func shouldTerminate(_ app: AppRuntimeState) -> Bool {
        guard app.pid != ProcessInfo.processInfo.processIdentifier else { return false }
        guard !app.isFrontmost else { return false }
        guard !app.isWhitelisted else { return false }
        guard app.riskLevel != .high else { return false }
        guard app.memoryBytes >= configuration.minimumMemoryBytes else { return false }
        return true
    }

    public func score(_ app: AppRuntimeState, now: Date = Date()) -> Double {
        let memoryScore = Double(app.memoryBytes) / Double(1024 * 1024)
        let idleHours = app.backgroundDuration(now: now) / 3600
        let riskPenalty: Double = {
            switch app.riskLevel {
            case .low:
                return 0
            case .medium:
                return 300
            case .high:
                return 10_000
            }
        }()
        return memoryScore + idleHours * 120 - riskPenalty
    }

    private func hasRecentQuitRequest(for pid: pid_t, now: Date) -> Bool {
        guard let lastRequestedAt = recentQuitRequestsByPID[pid] else { return false }
        return now.timeIntervalSince(lastRequestedAt) < duplicateQuitCooldown
    }
}
