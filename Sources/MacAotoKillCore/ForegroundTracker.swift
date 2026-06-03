import AppKit
import Foundation

public struct ForegroundTiming: Equatable {
    public var lastForegroundAt: Date?
    public var lastBackgroundAt: Date?
}

public final class ForegroundTracker: NSObject {
    private var timingsByBundleID: [String: ForegroundTiming] = [:]
    private var currentBundleID: String?
    public private(set) var currentFrontmostDisplayName: String?

    public override init() {
        super.init()
    }

    deinit {
        stop()
    }

    public func start() {
        seedCurrentFrontmostApplication()
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(applicationDidActivate(_:)),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )
    }

    public func stop() {
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }

    public func timing(for bundleID: String) -> ForegroundTiming {
        timingsByBundleID[bundleID] ?? ForegroundTiming()
    }

    private func seedCurrentFrontmostApplication() {
        guard
            let app = NSWorkspace.shared.frontmostApplication,
            let bundleID = app.bundleIdentifier
        else {
            return
        }
        let now = Date()
        currentBundleID = bundleID
        currentFrontmostDisplayName = app.localizedName ?? bundleID
        timingsByBundleID[bundleID] = ForegroundTiming(
            lastForegroundAt: now,
            lastBackgroundAt: nil
        )
    }

    @objc private func applicationDidActivate(_ notification: Notification) {
        guard
            let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
            let bundleID = app.bundleIdentifier
        else {
            return
        }

        let now = Date()
        if let previousBundleID = currentBundleID, previousBundleID != bundleID {
            var previousTiming = timingsByBundleID[previousBundleID] ?? ForegroundTiming()
            previousTiming.lastBackgroundAt = now
            timingsByBundleID[previousBundleID] = previousTiming
        }

        var timing = timingsByBundleID[bundleID] ?? ForegroundTiming()
        timing.lastForegroundAt = now
        timingsByBundleID[bundleID] = timing

        currentBundleID = bundleID
        currentFrontmostDisplayName = app.localizedName ?? bundleID
    }
}
