import AppKit
import MacAotoKillCore
import SwiftUI
import UniformTypeIdentifiers

final class StatusMenuController: NSObject, NSMenuDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let menu = NSMenu()
    private let whitelistStore = WhitelistStore()
    private let foregroundTracker = ForegroundTracker()
    private let settingsStore = SettingsStore()
    private let eventLog = EventLog()
    private let memoryPressureWatcher = MemoryPressureWatcher()
    private var memoryPressureLevel: MemoryPressureLevel = .normal
    private var settingsWindowController: SettingsWindowController?
    private var updateCheckTask: Task<Void, Never>?
    private var isCheckingForUpdates = false
    private var isInstallingUpdate = false
    private var isAutomaticUpdateCheckScheduled = false

    private lazy var processMonitor = ProcessMonitor(
        whitelistStore: whitelistStore,
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
    private let automaticUpdateCheckInterval: TimeInterval = 24 * 60 * 60

    private var localizer: Localizer {
        Localizer(languageCode: settingsStore.languageCode)
    }

    private var isSystemMemoryGateExceeded: Bool {
        thresholdEvaluation.isExceeded || memoryPressureLevel != .normal
    }

    override init() {
        super.init()
        configureStatusItem()
        foregroundTracker.start()
        memoryPressureWatcher.onPressure = { [weak self] level in
            DispatchQueue.main.async {
                guard let self else { return }
                self.memoryPressureLevel = level
                self.eventLog.append(self.localizer.t("event.memoryPressureChanged", level.localizedName(self.localizer)))
                self.refreshSnapshot(performAutomaticRelease: level != .normal)
            }
        }
        memoryPressureWatcher.start()
        startTimer()
        refreshSnapshot()
        eventLog.append(localizer.t("event.started"))
        scheduleAutomaticUpdateCheckIfNeeded()
    }

    func stop() {
        refreshTimer?.invalidate()
        refreshTimer = nil
        updateCheckTask?.cancel()
        updateCheckTask = nil
        foregroundTracker.stop()
        memoryPressureWatcher.stop()
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
                self?.scheduleAutomaticUpdateCheckIfNeeded()
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
            minimumBackgroundDuration: settingsStore.minimumBackgroundDuration,
            minimumBackgroundDurationsByBundleID: settingsStore.minimumBackgroundDurationsByBundleID,
            autoQuitBundleIDs: settingsStore.autoQuitBundleIDs,
            memoryLimitsByBundleID: settingsStore.memoryLimitsByBundleID,
            isMemoryLimitExceeded: isSystemMemoryGateExceeded,
            maxAppsPerSweep: settingsStore.maxAppsPerSweep,
            forceTerminateImmediately: false
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
        let now = Date()
        guard !memoryPolicyEngine.candidates(for: snapshot, now: now).isEmpty else { return }

        if let lastAutomaticReleaseAt, now.timeIntervalSince(lastAutomaticReleaseAt) < automaticReleaseCooldown {
            return
        }

        self.lastAutomaticReleaseAt = now
        eventLog.append(localizer.t("event.autoReleaseTrigger", localizer.t("event.backgroundIdleTimeout")))
        memoryPolicyEngine.handleAutomaticRelease(states: snapshot, now: now)
    }

    private func updateStatusTitle() {
        let candidateCount = memoryPolicyEngine.candidates(for: snapshot).count
        statusItem.button?.image = StatusIconFactory.makeImage(isExceeded: isSystemMemoryGateExceeded)
        statusItem.button?.toolTip = candidateCount > 0
            ? "\(localizer.t("dashboard.candidates")) · \(candidateCount)"
            : (isSystemMemoryGateExceeded ? localizer.t("status.exceeded") : localizer.t("status.withinLimits"))
    }

    private func rebuildMenu() {
        refreshSnapshot(performAutomaticRelease: false)
        menu.removeAllItems()

        addDashboardItem()
        menu.addItem(.separator())

        let settingsItem = NSMenuItem(
            title: localizer.t("menu.settings"),
            action: #selector(openSettings(_:)),
            keyEquivalent: ","
        )
        settingsItem.target = self
        settingsItem.image = symbolMenuIcon("gearshape")
        menu.addItem(settingsItem)

        let updateItemTitle = if isInstallingUpdate {
            localizer.t("menu.installingUpdate")
        } else if isCheckingForUpdates {
            localizer.t("menu.checkingForUpdates")
        } else {
            localizer.t("menu.checkForUpdates")
        }
        let updateItem = NSMenuItem(
            title: updateItemTitle,
            action: #selector(checkForUpdates(_:)),
            keyEquivalent: ""
        )
        updateItem.target = self
        updateItem.isEnabled = !isCheckingForUpdates && !isInstallingUpdate
        updateItem.image = symbolMenuIcon("arrow.down.circle")
        menu.addItem(updateItem)

        let releaseItem = NSMenuItem(
            title: localizer.t("menu.releaseNow"),
            action: #selector(releaseNow(_:)),
            keyEquivalent: ""
        )
        releaseItem.target = self
        releaseItem.image = symbolMenuIcon("sparkles")
        menu.addItem(releaseItem)
        menu.addItem(.separator())

        addCurrentAppWhitelistItem()
        addCandidateSubmenu()
        addAllAppsSubmenu()
        addWhitelistSubmenu()
        addLogSubmenu()

        menu.addItem(.separator())
        let quitItem = NSMenuItem(title: localizer.t("menu.quit"), action: #selector(quitApp(_:)), keyEquivalent: "q")
        quitItem.target = self
        quitItem.image = symbolMenuIcon("power")
        menu.addItem(quitItem)
    }

    private func addDisabledItem(_ title: String) {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        menu.addItem(item)
    }

    private func addDashboardItem() {
        let thresholdConfiguration = makeThresholdConfiguration()
        let content = MemoryDashboardMenuContent(
            title: "GreenRAM",
            statusText: isSystemMemoryGateExceeded
                ? localizer.t("status.exceeded")
                : localizer.t("status.withinLimits"),
            isExceeded: isSystemMemoryGateExceeded,
            icon: StatusIconFactory.makeImage(isExceeded: isSystemMemoryGateExceeded),
            ramMetric: MemoryMetricDisplays.ram(
                snapshot: memorySnapshot,
                ramLimitPercent: thresholdConfiguration.ramLimitPercent,
                localizer: localizer
            ),
            swapMetric: MemoryMetricDisplays.swap(
                snapshot: memorySnapshot,
                swapLimitEnabled: thresholdConfiguration.swapLimitEnabled,
                swapLimitBytes: thresholdConfiguration.swapLimitBytes,
                localizer: localizer
            )
        )
        let hostingView = NSHostingView(rootView: content)
        let fittingHeight = max(1, ceil(hostingView.fittingSize.height))
        hostingView.frame = NSRect(
            x: 0,
            y: 0,
            width: MemoryDashboardMenuContent.width,
            height: fittingHeight
        )

        let item = NSMenuItem()
        item.view = hostingView
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
        guard !AppIdentity.isOwnBundleIdentifier(bundleID) else { return }

        let appName = app.localizedName ?? bundleID
        let item: NSMenuItem
        if whitelistStore.contains(bundleID) {
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
        item.image = menuIcon(for: app)
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
                let decision = memoryPolicyEngine.decision(for: app)
                let item = NSMenuItem(
                    title: "\(app.displayName) - \(memorySummary(for: app)) - \(cleanupReason(for: decision))",
                    action: nil,
                    keyEquivalent: ""
                )
                item.isEnabled = true
                item.image = menuIcon(for: app)
                submenu.addItem(item)
            }
        }

        let parent = NSMenuItem(title: localizer.t("menu.releaseCandidates"), action: nil, keyEquivalent: "")
        parent.image = symbolMenuIcon("list.bullet.rectangle")
        parent.submenu = submenu
        menu.addItem(parent)
    }

    private func addAllAppsSubmenu() {
        let apps = snapshot
            .sorted { $0.memoryBytes > $1.memoryBytes }

        let submenu = NSMenu()
        submenu.autoenablesItems = false
        for app in apps {
            var titleParts = [app.displayName, memorySummary(for: app)]
            if let marker = cleanupMarker(for: app) {
                titleParts.append(marker)
            }
            let item = NSMenuItem(
                title: titleParts.joined(separator: " - "),
                action: nil,
                keyEquivalent: ""
            )
            item.isEnabled = true
            item.image = menuIcon(for: app)
            submenu.addItem(item)
        }

        if submenu.items.isEmpty {
            let item = NSMenuItem(title: localizer.t("menu.noBackgroundApps"), action: nil, keyEquivalent: "")
            item.isEnabled = true
            submenu.addItem(item)
        }

        let parent = NSMenuItem(title: localizer.t("menu.backgroundApps"), action: nil, keyEquivalent: "")
        parent.image = symbolMenuIcon("macwindow")
        parent.submenu = submenu
        menu.addItem(parent)
    }

    private func cleanupMarker(for app: AppRuntimeState) -> String? {
        if memoryPolicyEngine.shouldTerminate(app) {
            return localizer.t("menu.cleanable")
        }
        if app.isWhitelisted {
            return localizer.t("menu.protected")
        }
        return nil
    }

    private func cleanupReason(for decision: CleanupDecision) -> String {
        let idle = DurationFormatter.compact(decision.backgroundDuration, localizer: localizer)
        switch decision.trigger {
        case .autoQuitRule:
            return "\(idle) · \(localizer.t("settings.autoQuitApps"))"
        case .systemMemory:
            let systemReason = memoryPressureLevel == .normal
                ? thresholdEvaluation.summary
                : localizer.t("event.systemPressure", memoryPressureLevel.localizedName(localizer))
            return "\(idle) · \(systemReason)"
        case .appMemory(let limitBytes):
            return "\(idle) · \(localizer.t("settings.appMemoryLimits")) \(ByteFormatter.memory(limitBytes))"
        case nil:
            return idle
        }
    }

    private func addWhitelistSubmenu() {
        let submenu = NSMenu()
        let bundleIDs = whitelistStore.allBundleIDs.sorted()

        if bundleIDs.isEmpty {
            let item = NSMenuItem(title: localizer.t("menu.noWhitelistItems"), action: nil, keyEquivalent: "")
            item.isEnabled = false
            submenu.addItem(item)
        } else {
            for bundleID in bundleIDs {
                let item = NSMenuItem(
                    title: localizer.t("menu.removeBundleID", bundleID),
                    action: #selector(removeWhitelistItem(_:)),
                    keyEquivalent: ""
                )
                item.target = self
                item.representedObject = bundleID
                item.image = menuIcon(forBundleID: bundleID)
                submenu.addItem(item)
            }
        }

        let parent = NSMenuItem(title: localizer.t("menu.whitelist"), action: nil, keyEquivalent: "")
        parent.image = symbolMenuIcon("checkmark.shield")
        parent.submenu = submenu
        menu.addItem(parent)
    }

    private func menuIcon(for app: AppRuntimeState) -> NSImage? {
        guard let runningApplication = NSRunningApplication(processIdentifier: app.pid) else {
            return nil
        }
        return menuIcon(for: runningApplication)
    }

    private func menuIcon(for app: NSRunningApplication) -> NSImage? {
        scaledMenuIcon(app.icon)
    }

    private func menuIcon(forBundleID bundleID: String) -> NSImage? {
        guard let app = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == bundleID }) else {
            return nil
        }
        return menuIcon(for: app)
    }

    private func scaledMenuIcon(_ sourceImage: NSImage?) -> NSImage? {
        guard let image = sourceImage?.copy() as? NSImage else {
            return nil
        }
        image.size = NSSize(width: 18, height: 18)
        image.isTemplate = false
        return image
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
        parent.image = symbolMenuIcon("clock.arrow.circlepath")
        parent.submenu = submenu
        menu.addItem(parent)
    }

    private func symbolMenuIcon(_ systemName: String) -> NSImage? {
        guard let image = NSImage(systemSymbolName: systemName, accessibilityDescription: nil) else {
            return nil
        }
        image.size = NSSize(width: 18, height: 18)
        image.isTemplate = true
        return image
    }

    @objc private func releaseNow(_ sender: NSMenuItem) {
        refreshSnapshot(performAutomaticRelease: false)
        eventLog.append(localizer.t("event.manualRelease"))
        memoryPolicyEngine.handleManualRelease(states: snapshot)
        refreshSnapshot(performAutomaticRelease: false)
    }

    @objc private func checkForUpdates(_ sender: NSMenuItem) {
        beginUpdateCheck(isUserInitiated: true)
    }

    private func scheduleAutomaticUpdateCheckIfNeeded() {
        guard settingsStore.automaticUpdateReminderEnabled else { return }
        guard AppIdentity.currentVersion != "0.0.0" else { return }
        guard !isAutomaticUpdateCheckScheduled else { return }
        if let lastUpdateCheckAt = settingsStore.lastUpdateCheckAt,
           Date().timeIntervalSince(lastUpdateCheckAt) < automaticUpdateCheckInterval {
            return
        }

        isAutomaticUpdateCheckScheduled = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            self?.isAutomaticUpdateCheckScheduled = false
            self?.beginUpdateCheck(isUserInitiated: false)
        }
    }

    private func beginUpdateCheck(isUserInitiated: Bool) {
        guard isUserInitiated || settingsStore.automaticUpdateReminderEnabled else { return }
        guard !isCheckingForUpdates && !isInstallingUpdate else { return }

        isCheckingForUpdates = true
        let checker = GitHubReleaseUpdateChecker(currentVersion: AppIdentity.currentVersion)
        updateCheckTask?.cancel()
        updateCheckTask = Task { @MainActor [weak self] in
            do {
                let result = try await checker.checkForUpdate()
                self?.completeUpdateCheck(result, isUserInitiated: isUserInitiated)
            } catch is CancellationError {
                self?.isCheckingForUpdates = false
            } catch {
                self?.failUpdateCheck(error, isUserInitiated: isUserInitiated)
            }
        }
    }

    private func completeUpdateCheck(_ result: AppUpdateCheckResult, isUserInitiated: Bool) {
        isCheckingForUpdates = false
        updateCheckTask = nil
        settingsStore.lastUpdateCheckAt = Date()

        switch result {
        case .upToDate(let currentVersion, _):
            if isUserInitiated {
                eventLog.append(localizer.t("event.updateNotAvailable", currentVersion))
                presentUpToDateAlert(currentVersion: currentVersion)
            }
        case .updateAvailable(let info):
            eventLog.append(localizer.t("event.updateAvailable", info.latestVersion, info.currentVersion))
            settingsStore.lastPromptedUpdateVersion = info.latestVersion
            presentUpdateAvailableAlert(info)
        }
    }

    private func failUpdateCheck(_ error: Error, isUserInitiated: Bool) {
        isCheckingForUpdates = false
        updateCheckTask = nil
        settingsStore.lastUpdateCheckAt = Date()
        eventLog.append(localizer.t("event.updateCheckFailed", error.localizedDescription))

        if isUserInitiated {
            let alert = NSAlert()
            alert.alertStyle = .warning
            alert.icon = nil
            alert.messageText = localizer.t("update.checkFailedTitle")
            alert.informativeText = localizer.t("update.checkFailedMessage", error.localizedDescription)
            alert.addButton(withTitle: localizer.t("update.ok"))
            NSApp.activate(ignoringOtherApps: true)
            alert.runModal()
        }
    }

    private func presentUpdateAvailableAlert(_ info: AppUpdateInfo) {
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.icon = nil
        alert.messageText = localizer.t("update.availableTitle", info.latestVersion)
        alert.informativeText = localizer.t("update.availableMessage", info.currentVersion)
        alert.addButton(withTitle: info.canInstallAutomatically ? localizer.t("update.installAndRestart") : localizer.t("update.download"))
        alert.addButton(withTitle: localizer.t("update.releasePage"))
        alert.addButton(withTitle: localizer.t("update.later"))

        NSApp.activate(ignoringOtherApps: true)
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            if info.canInstallAutomatically {
                installUpdate(info)
            } else {
                NSWorkspace.shared.open(info.downloadURL)
            }
        } else if response == .alertSecondButtonReturn {
            NSWorkspace.shared.open(info.releasePageURL)
        }
    }

    private func installUpdate(_ info: AppUpdateInfo) {
        guard !isInstallingUpdate else { return }

        isInstallingUpdate = true
        eventLog.append(localizer.t("event.updateInstallStarted", info.latestVersion))
        let installer = AppUpdateInstaller()
        updateCheckTask?.cancel()
        updateCheckTask = Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let installation = try await installer.prepareInstallation(for: info)
                try installation.launchInstaller()
                eventLog.append(localizer.t("event.updateInstallRelaunching", info.latestVersion))
                NSApp.terminate(nil)
            } catch {
                failUpdateInstall(error, info: info)
            }
        }
    }

    private func failUpdateInstall(_ error: Error, info: AppUpdateInfo) {
        isInstallingUpdate = false
        updateCheckTask = nil
        eventLog.append(localizer.t("event.updateInstallFailed", error.localizedDescription))

        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.icon = nil
        alert.messageText = localizer.t("update.installFailedTitle")
        alert.informativeText = localizer.t("update.installFailedMessage", error.localizedDescription)
        alert.addButton(withTitle: localizer.t("update.releasePage"))
        alert.addButton(withTitle: localizer.t("update.ok"))
        NSApp.activate(ignoringOtherApps: true)
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            NSWorkspace.shared.open(info.releasePageURL)
        }
    }

    private func presentUpToDateAlert(currentVersion: String) {
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.icon = nil
        alert.messageText = localizer.t("update.upToDateTitle")
        alert.informativeText = localizer.t("update.upToDateMessage", currentVersion)
        alert.addButton(withTitle: localizer.t("update.ok"))
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }

    @MainActor
    @objc private func openSettings(_ sender: NSMenuItem) {
        if settingsWindowController == nil {
            settingsWindowController = SettingsWindowController(
                settingsStore: settingsStore,
                whitelistStore: whitelistStore,
                memoryProvider: { SystemMemoryMonitor.capture() },
                onChange: { [weak self] in
                    self?.refreshSnapshot(performAutomaticRelease: true)
                    guard let self else { return }
                    self.scheduleAutomaticUpdateCheckIfNeeded()
                    self.eventLog.append(self.localizer.t("event.settingsUpdated"))
                },
                onWhitelistAdded: { [weak self] bundleID in
                    guard let self else { return }
                    self.eventLog.append(self.localizer.t("event.addedWhitelist", bundleID))
                    self.refreshSnapshot(performAutomaticRelease: false)
                },
                onWhitelistRemoved: { [weak self] bundleID in
                    guard let self else { return }
                    self.eventLog.append(self.localizer.t("event.removedWhitelist", bundleID))
                    self.refreshSnapshot(performAutomaticRelease: false)
                },
                onExportLogs: { [weak self] in
                    self?.exportLogs()
                }
            )
        }
        settingsWindowController?.show()
    }

    private func exportLogs() {
        let panel = NSSavePanel()
        panel.title = localizer.t("settings.exportLogs")
        panel.nameFieldStringValue = "GreenRAM-Logs-\(Self.fileTimestamp()).log"
        panel.canCreateDirectories = true
        if let logType = UTType(filenameExtension: "log") {
            panel.allowedContentTypes = [logType]
        }

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            try eventLog.export(to: url)
            eventLog.append(localizer.t("event.logsExported", url.path))
        } catch {
            eventLog.append(localizer.t("event.logsExportFailed", error.localizedDescription))
            let alert = NSAlert()
            alert.messageText = localizer.t("settings.exportLogsFailed")
            alert.informativeText = error.localizedDescription
            alert.alertStyle = .warning
            alert.icon = nil
            alert.runModal()
        }
    }

    private static func fileTimestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter.string(from: Date())
    }

    @objc private func addWhitelistItem(_ sender: NSMenuItem) {
        guard let bundleID = sender.representedObject as? String else { return }
        guard !AppIdentity.isOwnBundleIdentifier(bundleID) else { return }
        settingsStore.setAutoQuitEnabled(false, for: bundleID)
        whitelistStore.add(bundleID)
        eventLog.append(localizer.t("event.addedWhitelist", bundleID))
        refreshSnapshot(performAutomaticRelease: false)
    }

    @objc private func removeWhitelistItem(_ sender: NSMenuItem) {
        guard let bundleID = sender.representedObject as? String else { return }
        guard !AppIdentity.isOwnBundleIdentifier(bundleID) else { return }
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
