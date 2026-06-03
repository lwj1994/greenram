import AppKit
import Darwin
import Foundation

public final class ProcessMonitor {
    private let whitelistStore: WhitelistStore
    private let riskClassifier: RiskClassifier
    private let foregroundTracker: ForegroundTracker

    public init(
        whitelistStore: WhitelistStore,
        riskClassifier: RiskClassifier,
        foregroundTracker: ForegroundTracker
    ) {
        self.whitelistStore = whitelistStore
        self.riskClassifier = riskClassifier
        self.foregroundTracker = foregroundTracker
    }

    public func sample() -> [AppRuntimeState] {
        let frontmostPID = NSWorkspace.shared.frontmostApplication?.processIdentifier
        let processTree = ProcessTreeSnapshot.capture()

        return NSWorkspace.shared.runningApplications
            .compactMap { app -> AppRuntimeState? in
                guard
                    app.activationPolicy == .regular,
                    !app.isTerminated,
                    let bundleID = app.bundleIdentifier
                else {
                    return nil
                }

                let displayName = app.localizedName
                    ?? app.bundleURL?.deletingPathExtension().lastPathComponent
                    ?? bundleID
                let timing = foregroundTracker.timing(for: bundleID)
                let aggregate = processTree.aggregate(rootPID: app.processIdentifier)
                let ownMemoryBytes = processTree.ownResidentMemoryBytes(rootPID: app.processIdentifier)

                return AppRuntimeState(
                    pid: app.processIdentifier,
                    bundleID: bundleID,
                    displayName: displayName,
                    launchDate: app.launchDate,
                    lastForegroundAt: timing.lastForegroundAt,
                    lastBackgroundAt: timing.lastBackgroundAt,
                    memoryBytes: aggregate.totalMemoryBytes,
                    isFrontmost: app.processIdentifier == frontmostPID,
                    isWhitelisted: whitelistStore.contains(bundleID),
                    riskLevel: riskClassifier.classify(bundleID: bundleID, displayName: displayName),
                    ownMemoryBytes: ownMemoryBytes,
                    descendantMemoryBytes: aggregate.descendantMemoryBytes,
                    descendantProcessCount: aggregate.descendantCount
                )
            }
            .sorted { $0.memoryBytes > $1.memoryBytes }
    }
}
