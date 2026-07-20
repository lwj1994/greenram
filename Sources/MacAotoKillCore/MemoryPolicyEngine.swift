import Darwin
import Foundation

public enum CleanupRuleGroup: Equatable {
    case autoQuit
    case ordinary
}

public enum CleanupTrigger: Equatable {
    case autoQuitRule
    case systemMemory
    case appMemory(limitBytes: UInt64)
}

public enum CleanupExclusion: Equatable {
    case ownApplication
    case frontmost
    case whitelisted
    case backgroundTime(required: TimeInterval, actual: TimeInterval)
    case memoryGateNotReached
}

public struct CleanupDecision: Equatable {
    public let ruleGroup: CleanupRuleGroup
    public let backgroundDuration: TimeInterval
    public let backgroundThreshold: TimeInterval
    public let trigger: CleanupTrigger?
    public let exclusion: CleanupExclusion?

    public var isEligible: Bool { exclusion == nil && trigger != nil }
}

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
        forceTerminateImmediately: Bool = false
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
            let didSubmit: Bool
            if configuration.forceTerminateImmediately {
                didSubmit = terminator?.forceQuit(app) ?? false
            } else {
                didSubmit = terminator?.requestQuit(app, forceIfNeeded: false) ?? false
            }
            if didSubmit {
                recentQuitRequestsByBundleID[app.bundleID] = now
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
        return decision(for: app, now: now).isEligible
    }

    public func decision(for app: AppRuntimeState, now: Date = Date()) -> CleanupDecision {
        let isAutoQuitApp = configuration.isAutoQuitApp(app.bundleID)
        let group: CleanupRuleGroup = isAutoQuitApp ? .autoQuit : .ordinary
        let threshold = configuration.backgroundDurationThreshold(for: app.bundleID)
        let duration = app.backgroundDuration(now: now)

        func excluded(_ exclusion: CleanupExclusion) -> CleanupDecision {
            CleanupDecision(
                ruleGroup: group,
                backgroundDuration: duration,
                backgroundThreshold: threshold,
                trigger: nil,
                exclusion: exclusion
            )
        }

        guard app.pid != ProcessInfo.processInfo.processIdentifier,
              !AppIdentity.isOwnBundleIdentifier(app.bundleID) else {
            return excluded(.ownApplication)
        }
        guard !app.isFrontmost else { return excluded(.frontmost) }
        guard !app.isWhitelisted else { return excluded(.whitelisted) }
        guard duration >= threshold else {
            return excluded(.backgroundTime(required: threshold, actual: duration))
        }

        let trigger: CleanupTrigger
        if isAutoQuitApp {
            trigger = .autoQuitRule
        } else if configuration.isAppMemoryLimitExceeded(app),
                  let limit = configuration.memoryLimit(for: app.bundleID) {
            trigger = .appMemory(limitBytes: limit)
        } else if configuration.isMemoryLimitExceeded {
            trigger = .systemMemory
        } else {
            return excluded(.memoryGateNotReached)
        }

        return CleanupDecision(
            ruleGroup: group,
            backgroundDuration: duration,
            backgroundThreshold: threshold,
            trigger: trigger,
            exclusion: nil
        )
    }

    public func score(_ app: AppRuntimeState, now: Date = Date()) -> Double {
        app.backgroundDuration(now: now)
    }

    private func hasRecentQuitRequest(for bundleID: String, now: Date) -> Bool {
        guard let lastRequestedAt = recentQuitRequestsByBundleID[bundleID] else { return false }
        return now.timeIntervalSince(lastRequestedAt) < duplicateQuitCooldown
    }
}
