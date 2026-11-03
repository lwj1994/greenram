import Darwin
import Foundation

public struct MemoryPolicyConfiguration: Equatable {
    public var autoReleaseEnabled: Bool
    public var minimumBackgroundDuration: TimeInterval
    public var minimumBackgroundDurationsByBundleID: [String: TimeInterval]
    public var autoQuitBundleIDs: Set<String>
    public var memoryLimitsByBundleID: [String: UInt64]
    public var isMemoryLimitExceeded: Bool
    public var maxAppsPerSweep: Int
    public var forceTerminateImmediately: Bool

    public init(
        autoReleaseEnabled: Bool = true,
        minimumBackgroundDuration: TimeInterval = MemoryPolicyDefaults.minimumBackgroundDuration,
        minimumBackgroundDurationsByBundleID: [String: TimeInterval] = [:],
        autoQuitBundleIDs: Set<String> = [],
        memoryLimitsByBundleID: [String: UInt64] = [:],
        isMemoryLimitExceeded: Bool = false,
        maxAppsPerSweep: Int = 3,
        forceTerminateImmediately: Bool = true
    ) {
        self.autoReleaseEnabled = autoReleaseEnabled
        self.minimumBackgroundDuration = minimumBackgroundDuration
        self.minimumBackgroundDurationsByBundleID = minimumBackgroundDurationsByBundleID
        self.autoQuitBundleIDs = autoQuitBundleIDs
        self.memoryLimitsByBundleID = memoryLimitsByBundleID
        self.isMemoryLimitExceeded = isMemoryLimitExceeded
        self.maxAppsPerSweep = maxAppsPerSweep
        self.forceTerminateImmediately = forceTerminateImmediately
    }

    public func customBackgroundDuration(for bundleID: String) -> TimeInterval? {
        minimumBackgroundDurationsByBundleID[bundleID]
    }

    public func backgroundDurationThreshold(for bundleID: String) -> TimeInterval {
        return customBackgroundDuration(for: bundleID) ?? minimumBackgroundDuration
    }

    public func isAutoQuitApp(_ bundleID: String) -> Bool {
        autoQuitBundleIDs.contains(bundleID)
    }

    public func memoryLimit(for bundleID: String) -> UInt64? {
        memoryLimitsByBundleID[bundleID]
    }

    public func isAppMemoryLimitExceeded(_ app: AppRuntimeState) -> Bool {
        guard let limit = memoryLimit(for: app.bundleID) else { return false }
        return app.memoryBytes >= limit
    }
}

/// App 在清理规则下的当前状态，用于界面展示。
public enum AppCleanupStatus: Hashable {
    /// 白名单 App 或 GreenRAM 自己，永不清理。
    case protected
    /// 当前前台 App。
    case foreground
    /// 已满足清理条件。
    case cleanable
    /// 尚未满足清理条件。
    case waiting
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
        guard !AppIdentity.isOwnBundleIdentifier(app.bundleID) else { return false }
        guard !app.isFrontmost else { return false }
        guard !app.isWhitelisted else { return false }

        let isAutoQuitApp = configuration.isAutoQuitApp(app.bundleID)
        let backgroundDurationThreshold = configuration.backgroundDurationThreshold(for: app.bundleID)

        guard app.backgroundDuration(now: now) >= backgroundDurationThreshold else { return false }
        return isAutoQuitApp || configuration.isMemoryLimitExceeded || configuration.isAppMemoryLimitExceeded(app)
    }

    public func cleanupStatus(_ app: AppRuntimeState, now: Date = Date()) -> AppCleanupStatus {
        if app.isWhitelisted
            || app.pid == ProcessInfo.processInfo.processIdentifier
            || AppIdentity.isOwnBundleIdentifier(app.bundleID) {
            return .protected
        }
        if app.isFrontmost {
            return .foreground
        }
        return shouldTerminate(app, now: now) ? .cleanable : .waiting
    }

    public func score(_ app: AppRuntimeState, now: Date = Date()) -> Double {
        app.backgroundDuration(now: now)
    }

    private func hasRecentQuitRequest(for bundleID: String, now: Date) -> Bool {
        guard let lastRequestedAt = recentQuitRequestsByBundleID[bundleID] else { return false }
        return now.timeIntervalSince(lastRequestedAt) < duplicateQuitCooldown
    }
}
