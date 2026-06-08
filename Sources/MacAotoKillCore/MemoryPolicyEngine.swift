import Darwin
import Foundation

public struct MemoryPolicyConfiguration: Equatable {
    public var autoReleaseEnabled: Bool
    public var minimumBackgroundDuration: TimeInterval
    public var minimumBackgroundDurationsByBundleID: [String: TimeInterval]
    public var isMemoryLimitExceeded: Bool
    public var maxAppsPerSweep: Int
    public var forceTerminateImmediately: Bool

    public init(
        autoReleaseEnabled: Bool = true,
        minimumBackgroundDuration: TimeInterval = MemoryPolicyDefaults.minimumBackgroundDuration,
        minimumBackgroundDurationsByBundleID: [String: TimeInterval] = [:],
        isMemoryLimitExceeded: Bool = false,
        maxAppsPerSweep: Int = 3,
        forceTerminateImmediately: Bool = true
    ) {
        self.autoReleaseEnabled = autoReleaseEnabled
        self.minimumBackgroundDuration = minimumBackgroundDuration
        self.minimumBackgroundDurationsByBundleID = minimumBackgroundDurationsByBundleID
        self.isMemoryLimitExceeded = isMemoryLimitExceeded
        self.maxAppsPerSweep = maxAppsPerSweep
        self.forceTerminateImmediately = forceTerminateImmediately
    }

    public func autoQuitBackgroundDuration(for bundleID: String) -> TimeInterval? {
        minimumBackgroundDurationsByBundleID[bundleID]
    }

    public func isAutoQuitApp(_ bundleID: String) -> Bool {
        autoQuitBackgroundDuration(for: bundleID) != nil
    }
}

public final class MemoryPolicyEngine {
    public var configuration: MemoryPolicyConfiguration
    private weak var terminator: AppTerminating?
    private weak var logger: EventLogging?
    private var recentQuitRequestsByBundleID: [String: Date] = [:]
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

    public func handleAutomaticRelease(
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
            .filter { !hasRecentQuitRequest(for: $0.bundleID, now: now) }
            .prefix(configuration.maxAppsPerSweep)

        guard !targets.isEmpty else {
            logger?.append(localizerProvider().t("event.noEligibleApps"))
            return
        }

        for app in targets {
            recentQuitRequestsByBundleID[app.bundleID] = now
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
            .filter { shouldTerminate($0, now: now) }
            .sorted { lhs, rhs in
                let lhsDuration = lhs.backgroundDuration(now: now)
                let rhsDuration = rhs.backgroundDuration(now: now)
                if lhsDuration == rhsDuration {
                    return lhs.memoryBytes > rhs.memoryBytes
                }
                return lhsDuration > rhsDuration
            }
    }

    public func shouldTerminate(_ app: AppRuntimeState, now: Date = Date()) -> Bool {
        guard app.pid != ProcessInfo.processInfo.processIdentifier else { return false }
        guard !app.isFrontmost else { return false }
        guard !app.isWhitelisted else { return false }

        let isAutoQuitApp = configuration.isAutoQuitApp(app.bundleID)
        let backgroundDurationThreshold = configuration.autoQuitBackgroundDuration(for: app.bundleID)
            ?? configuration.minimumBackgroundDuration

        guard app.backgroundDuration(now: now) >= backgroundDurationThreshold else { return false }
        return isAutoQuitApp || configuration.isMemoryLimitExceeded
    }

    public func score(_ app: AppRuntimeState, now: Date = Date()) -> Double {
        app.backgroundDuration(now: now)
    }

    private func hasRecentQuitRequest(for bundleID: String, now: Date) -> Bool {
        guard let lastRequestedAt = recentQuitRequestsByBundleID[bundleID] else { return false }
        return now.timeIntervalSince(lastRequestedAt) < duplicateQuitCooldown
    }
}
