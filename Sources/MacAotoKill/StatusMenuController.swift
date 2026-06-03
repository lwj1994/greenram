import AppKit
import MacAotoKillCore

final class StatusMenuController: NSObject, NSMenuDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let menu = NSMenu()
    private let whitelistStore = WhitelistStore()
    private let riskClassifier = RiskClassifier()
    private let foregroundTracker = ForegroundTracker()
    private let settingsStore = SettingsStore()
    private let eventLog = EventLog()
    private var settingsWindowController: SettingsWindowController?

    private lazy var processMonitor = ProcessMonitor(
        whitelistStore: whitelistStore,
        riskClassifier: riskClassifier,
        foregroundTracker: foregroundTracker
    )

    private lazy var actionExecutor = ActionExecutor(
        logger: eventLog,
        localizerProvider: { [weak self] in self?.localizer ?? Localizer() }
    )

    private lazy var memoryPolicyEngine = MemoryPolicyEngine(
        configuration: makePolicyConfiguration(),
        terminator: actionExecutor,
        logger: eventLog,
        localizerProvider: { [weak self] in self?.localizer ?? Localizer() }
    )

    private var refreshTimer: Timer?
    private var snapshot: [AppRuntimeState] = []
    private var memorySnapshot = SystemMemoryMonitor.capture()
    private var thresholdEvaluation = MemoryThresholdEvaluator.evaluate(
        snapshot: SystemMemoryMonitor.capture(),
        configuration: MemoryThresholdConfiguration()
    )
    private var lastAutomaticReleaseAt: Date?
    private let automaticReleaseCooldown: TimeInterval = 60

    private var localizer: Localizer {
        Localizer(languageCode: settingsStore.languageCode)
    }

    override init() {
        super.init()
        configureStatusItem()
        foregroundTracker.start()
        startTimer()
        refreshSnapshot()
        eventLog.append(localizer.t("event.started"))
    }

    func stop() {
        refreshTimer?.invalidate()
        refreshTimer = nil
        foregroundTracker.stop()
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        rebuildMenu()
    }

    private func configureStatusItem() {
        statusItem.button?.imagePosition = .imageOnly
        menu.delegate = self
        statusItem.menu = menu
    }

    private func startTimer() {
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                self?.refreshSnapshot(performAutomaticRelease: true)
            }
        }
    }

    private func refreshSnapshot(performAutomaticRelease: Bool = false) {
        memorySnapshot = SystemMemoryMonitor.capture()
        thresholdEvaluation = MemoryThresholdEvaluator.evaluate(
            snapshot: memorySnapshot,
            configuration: makeThresholdConfiguration()
        )
        memoryPolicyEngine.configuration = makePolicyConfiguration()
        snapshot = processMonitor.sample()
        if performAutomaticRelease {
            releaseAutomaticallyIfNeeded()
        }
        updateStatusTitle()
    }

    private func makePolicyConfiguration() -> MemoryPolicyConfiguration {
        MemoryPolicyConfiguration(
            autoReleaseEnabled: true,
            minimumMemoryBytes: settingsStore.minimumAppMemoryBytes,
            maxAppsPerSweep: settingsStore.maxAppsPerSweep,
            forceTerminateImmediately: true
        )
    }

    private func makeThresholdConfiguration() -> MemoryThresholdConfiguration {
        MemoryThresholdConfiguration(
            ramLimitPercent: settingsStore.ramLimitPercent,
            swapLimitEnabled: settingsStore.swapLimitEnabled,
            swapLimitBytes: settingsStore.swapLimitBytes
        )
    }

    private func releaseAutomaticallyIfNeeded() {
        guard thresholdEvaluation.isExceeded else { return }

        let now = Date()
        if let lastAutomaticReleaseAt, now.timeIntervalSince(lastAutomaticReleaseAt) < automaticReleaseCooldown {
            return
        }

        self.lastAutomaticReleaseAt = now
        eventLog.append(localizer.t("event.autoReleaseTrigger", triggerSummary()))
        memoryPolicyEngine.handleLimitExceeded(states: snapshot, now: now)
    }

    private func triggerSummary() -> String {
        let reasons = localizedThresholdReasons()
        if reasons.isEmpty {
            return localizer.t("event.belowThresholds")
        }
        return reasons.joined(separator: ", ")
    }

    private func localizedThresholdReasons() -> [String] {
        let thresholdConfiguration = makeThresholdConfiguration()
        var reasons: [String] = []

        if memorySnapshot.usedPhysicalPercent >= thresholdConfiguration.ramLimitPercent {
            reasons.append(localizer.t(
                "trigger.ramThreshold",
                PercentFormatter.compact(memorySnapshot.usedPhysicalPercent),
                PercentFormatter.compact(thresholdConfiguration.ramLimitPercent)
            ))
        }

        if thresholdConfiguration.swapLimitEnabled && memorySnapshot.swapUsedBytes >= thresholdConfiguration.swapLimitBytes {
            reasons.append(localizer.t(
                "trigger.swapThreshold",
                ByteFormatter.memory(memorySnapshot.swapUsedBytes),
                ByteFormatter.memory(thresholdConfiguration.swapLimitBytes)
            ))
        }

        return reasons
    }

    private func updateStatusTitle() {
        let candidateCount = thresholdEvaluation.isExceeded
            ? memoryPolicyEngine.candidates(for: snapshot).count
            : 0
        statusItem.button?.image = StatusIconFactory.makeImage(isExceeded: thresholdEvaluation.isExceeded)
        statusItem.button?.toolTip = thresholdEvaluation.isExceeded
            ? "\(localizer.t("status.exceeded")) · \(candidateCount)"
            : localizer.t("status.withinLimits")
    }

    private func rebuildMenu() {
        refreshSnapshot(performAutomaticRelease: false)
        menu.removeAllItems()

        addDisabledItem("\(localizer.t("menu.thresholdStatus")): \(thresholdEvaluation.isExceeded ? localizer.t("status.exceeded") : localizer.t("status.withinLimits"))")
        addDisabledItem("\(localizer.t("menu.ram")): \(ByteFormatter.memory(memorySnapshot.usedPhysicalBytes)) / \(ByteFormatter.memory(memorySnapshot.totalPhysicalBytes)) (\(PercentFormatter.compact(memorySnapshot.usedPhysicalPercent)))")
        addDisabledItem("\(localizer.t("menu.swap")): \(ByteFormatter.memory(memorySnapshot.swapUsedBytes)) / \(ByteFormatter.memory(memorySnapshot.swapTotalBytes))")
        addDisabledItem("\(localizer.t("menu.compressed")): \(ByteFormatter.memory(memorySnapshot.compressedBytes))")
        addDisabledItem("\(localizer.t("menu.frontmost")): \(foregroundTracker.currentFrontmostDisplayName ?? "-")")
        addDisabledItem("\(localizer.t("menu.trackedApps")): \(snapshot.count)")
        menu.addItem(.separator())

        let settingsItem = NSMenuItem(
            title: localizer.t("menu.settings"),
            action: #selector(openSettings(_:)),
            keyEquivalent: ","
        )
        settingsItem.target = self
        menu.addItem(settingsItem)

        let releaseItem = NSMenuItem(
            title: localizer.t("menu.releaseNow"),
            action: #selector(releaseNow(_:)),
            keyEquivalent: ""
        )
        releaseItem.target = self
        menu.addItem(releaseItem)
        menu.addItem(.separator())

        addCurrentAppWhitelistItem()
        addCandidateSubmenu()
        addBackgroundAppsSubmenu()
        addWhitelistSubmenu()
        addLogSubmenu()

        menu.addItem(.separator())
        let quitItem = NSMenuItem(title: localizer.t("menu.quit"), action: #selector(quitApp(_:)), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
    }

    private func addDisabledItem(_ title: String) {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        menu.addItem(item)
    }

    private func memorySummary(for app: AppRuntimeState) -> String {
        var parts = [ByteFormatter.memory(app.memoryBytes)]
        if app.descendantProcessCount > 0 {
            parts.append(localizer.t("menu.childProcessCount", app.descendantProcessCount))
        }
        return parts.joined(separator: " · ")
    }

    private func addCurrentAppWhitelistItem() {
        guard
            let app = NSWorkspace.shared.frontmostApplication,
            let bundleID = app.bundleIdentifier
        else {
            return
        }

        let appName = app.localizedName ?? bundleID
        let item: NSMenuItem
        if whitelistStore.isDefaultProtected(bundleID) {
            item = NSMenuItem(title: localizer.t("menu.protectedByDefault", appName), action: nil, keyEquivalent: "")
            item.isEnabled = false
        } else if whitelistStore.contains(bundleID) {
            item = NSMenuItem(
                title: localizer.t("menu.removeAppFromWhitelist", appName),
                action: #selector(removeWhitelistItem(_:)),
                keyEquivalent: ""
            )
            item.representedObject = bundleID
            item.target = self
        } else {
            item = NSMenuItem(
                title: localizer.t("menu.whitelistApp", appName),
                action: #selector(addWhitelistItem(_:)),
                keyEquivalent: ""
            )
            item.representedObject = bundleID
            item.target = self
        }
        menu.addItem(item)
        menu.addItem(.separator())
    }

    private func addCandidateSubmenu() {
        let candidates = Array(memoryPolicyEngine.candidates(for: snapshot).prefix(8))
        let submenu = NSMenu()
        submenu.autoenablesItems = false

        if candidates.isEmpty {
            let item = NSMenuItem(title: localizer.t("menu.noSafeCandidates"), action: nil, keyEquivalent: "")
            item.isEnabled = true
            submenu.addItem(item)
        } else {
            for app in candidates {
                let item = NSMenuItem(
                    title: "\(app.displayName) - \(memorySummary(for: app))",
                    action: nil,
                    keyEquivalent: ""
                )
                item.isEnabled = true
                submenu.addItem(item)
            }
        }

        let parent = NSMenuItem(title: localizer.t("menu.releaseCandidates"), action: nil, keyEquivalent: "")
        parent.submenu = submenu
        menu.addItem(parent)
    }

    private func addBackgroundAppsSubmenu() {
        let apps = snapshot
            .filter { !$0.isFrontmost }
            .sorted { $0.memoryBytes > $1.memoryBytes }
            .prefix(12)

        let submenu = NSMenu()
        submenu.autoenablesItems = false
        for app in apps {
            let marker = app.isWhitelisted ? localizer.t("menu.protected") : app.riskLevel.localizedName(localizer)
            let item = NSMenuItem(
                title: "\(app.displayName) - \(memorySummary(for: app)) - \(marker)",
                action: nil,
                keyEquivalent: ""
            )
            item.isEnabled = true
            submenu.addItem(item)
        }

        if submenu.items.isEmpty {
            let item = NSMenuItem(title: localizer.t("menu.noBackgroundApps"), action: nil, keyEquivalent: "")
            item.isEnabled = true
            submenu.addItem(item)
        }

        let parent = NSMenuItem(title: localizer.t("menu.backgroundApps"), action: nil, keyEquivalent: "")
        parent.submenu = submenu
        menu.addItem(parent)
    }

    private func addWhitelistSubmenu() {
        let submenu = NSMenu()
        let userIDs = whitelistStore.userBundleIDs.sorted()

        if userIDs.isEmpty {
            let item = NSMenuItem(title: localizer.t("menu.noWhitelistItems"), action: nil, keyEquivalent: "")
            item.isEnabled = false
            submenu.addItem(item)
        } else {
            for bundleID in userIDs {
                let item = NSMenuItem(
                    title: localizer.t("menu.removeBundleID", bundleID),
                    action: #selector(removeWhitelistItem(_:)),
                    keyEquivalent: ""
                )
                item.target = self
                item.representedObject = bundleID
                submenu.addItem(item)
            }
        }

        submenu.addItem(.separator())
        let defaultsItem = NSMenuItem(
            title: localizer.t("menu.defaultProtected", WhitelistStore.defaultProtectedBundleIDs.count),
            action: nil,
            keyEquivalent: ""
        )
        defaultsItem.isEnabled = false
        submenu.addItem(defaultsItem)

        let parent = NSMenuItem(title: localizer.t("menu.whitelist"), action: nil, keyEquivalent: "")
        parent.submenu = submenu
        menu.addItem(parent)
    }

    private func addLogSubmenu() {
        let submenu = NSMenu()
        let entries = eventLog.recentEntries(limit: 10)

        if entries.isEmpty {
            let item = NSMenuItem(title: localizer.t("menu.noEvents"), action: nil, keyEquivalent: "")
            item.isEnabled = false
            submenu.addItem(item)
        } else {
            for entry in entries {
                let item = NSMenuItem(title: entry.menuTitle, action: nil, keyEquivalent: "")
                item.isEnabled = false
                submenu.addItem(item)
            }
        }

        let parent = NSMenuItem(title: localizer.t("menu.recentEvents"), action: nil, keyEquivalent: "")
        parent.submenu = submenu
        menu.addItem(parent)
    }

    @objc private func releaseNow(_ sender: NSMenuItem) {
        refreshSnapshot(performAutomaticRelease: false)
        eventLog.append(localizer.t("event.manualRelease"))
        memoryPolicyEngine.handleManualRelease(states: snapshot)
        refreshSnapshot(performAutomaticRelease: false)
    }

    @objc private func openSettings(_ sender: NSMenuItem) {
        if settingsWindowController == nil {
            settingsWindowController = SettingsWindowController(
                settingsStore: settingsStore,
                memoryProvider: { SystemMemoryMonitor.capture() },
                onChange: { [weak self] in
                    self?.refreshSnapshot(performAutomaticRelease: false)
                    guard let self else { return }
                    self.eventLog.append(self.localizer.t("event.settingsUpdated"))
                }
            )
        }
        settingsWindowController?.show()
    }

    @objc private func addWhitelistItem(_ sender: NSMenuItem) {
        guard let bundleID = sender.representedObject as? String else { return }
        whitelistStore.add(bundleID)
        eventLog.append(localizer.t("event.addedWhitelist", bundleID))
        refreshSnapshot(performAutomaticRelease: false)
    }

    @objc private func removeWhitelistItem(_ sender: NSMenuItem) {
        guard let bundleID = sender.representedObject as? String else { return }
        whitelistStore.remove(bundleID)
        eventLog.append(localizer.t("event.removedWhitelist", bundleID))
        refreshSnapshot(performAutomaticRelease: false)
    }

    @objc private func quitApp(_ sender: NSMenuItem) {
        NSApp.terminate(nil)
    }
}

private enum StatusIconFactory {
    static func makeImage(isExceeded: Bool) -> NSImage {
        let size = NSSize(width: 22, height: 22)
        let image = NSImage(size: size)
        image.isTemplate = false

        image.lockFocus()
        defer { image.unlockFocus() }

        NSGraphicsContext.current?.imageInterpolation = .high
        NSColor.clear.setFill()
        NSRect(origin: .zero, size: size).fill()

        let fillColor = isExceeded
            ? NSColor.systemRed
            : NSColor.systemGreen
        let leaf = leafPath()
        leaf.append(leafVeinPath())
        leaf.windingRule = .evenOdd

        fillColor.setFill()
        leaf.fill()

        return image
    }

    private static func leafPath() -> NSBezierPath {
        let leaf = NSBezierPath()
        leaf.move(to: NSPoint(x: 5.1, y: 3.4))
        leaf.curve(
            to: NSPoint(x: 5.7, y: 7.1),
            controlPoint1: NSPoint(x: 4.3, y: 4.4),
            controlPoint2: NSPoint(x: 4.8, y: 5.7)
        )
        leaf.curve(
            to: NSPoint(x: 10.4, y: 14.6),
            controlPoint1: NSPoint(x: 6.7, y: 10.0),
            controlPoint2: NSPoint(x: 8.1, y: 12.7)
        )
        leaf.curve(
            to: NSPoint(x: 18.1, y: 18.7),
            controlPoint1: NSPoint(x: 13.0, y: 16.7),
            controlPoint2: NSPoint(x: 15.6, y: 17.2)
        )
        leaf.curve(
            to: NSPoint(x: 19.4, y: 18.1),
            controlPoint1: NSPoint(x: 18.9, y: 19.2),
            controlPoint2: NSPoint(x: 19.5, y: 18.9)
        )
        leaf.curve(
            to: NSPoint(x: 18.7, y: 10.0),
            controlPoint1: NSPoint(x: 19.7, y: 15.4),
            controlPoint2: NSPoint(x: 19.5, y: 12.6)
        )
        leaf.curve(
            to: NSPoint(x: 12.5, y: 3.7),
            controlPoint1: NSPoint(x: 17.6, y: 6.6),
            controlPoint2: NSPoint(x: 15.4, y: 4.5)
        )
        leaf.curve(
            to: NSPoint(x: 7.8, y: 3.3),
            controlPoint1: NSPoint(x: 10.7, y: 3.2),
            controlPoint2: NSPoint(x: 9.2, y: 3.4)
        )
        leaf.curve(
            to: NSPoint(x: 6.3, y: 1.8),
            controlPoint1: NSPoint(x: 7.0, y: 3.0),
            controlPoint2: NSPoint(x: 6.8, y: 2.3)
        )
        leaf.curve(
            to: NSPoint(x: 4.2, y: 2.0),
            controlPoint1: NSPoint(x: 5.6, y: 1.2),
            controlPoint2: NSPoint(x: 4.5, y: 1.3)
        )
        leaf.curve(
            to: NSPoint(x: 5.1, y: 3.4),
            controlPoint1: NSPoint(x: 3.9, y: 2.6),
            controlPoint2: NSPoint(x: 4.4, y: 3.1)
        )
        leaf.close()
        return leaf
    }

    private static func leafVeinPath() -> NSBezierPath {
        let vein = NSBezierPath()
        vein.move(to: NSPoint(x: 6.9, y: 4.0))
        vein.curve(
            to: NSPoint(x: 15.9, y: 14.5),
            controlPoint1: NSPoint(x: 8.0, y: 7.9),
            controlPoint2: NSPoint(x: 11.5, y: 12.5)
        )
        vein.curve(
            to: NSPoint(x: 15.1, y: 14.9),
            controlPoint1: NSPoint(x: 16.3, y: 14.8),
            controlPoint2: NSPoint(x: 16.0, y: 15.1)
        )
        vein.curve(
            to: NSPoint(x: 7.6, y: 5.9),
            controlPoint1: NSPoint(x: 11.8, y: 13.1),
            controlPoint2: NSPoint(x: 8.9, y: 9.2)
        )
        vein.curve(
            to: NSPoint(x: 6.9, y: 4.0),
            controlPoint1: NSPoint(x: 7.2, y: 5.1),
            controlPoint2: NSPoint(x: 6.9, y: 4.4)
        )
        vein.close()
        return vein
    }
}
