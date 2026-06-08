import AppKit
import MacAotoKillCore
import UniformTypeIdentifiers

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
        addBackgroundAppsSubmenu()
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
        let item = NSMenuItem()
        item.view = MemoryDashboardMenuView(
            memorySnapshot: memorySnapshot,
            thresholdConfiguration: makeThresholdConfiguration(),
            isExceeded: thresholdEvaluation.isExceeded,
            localizer: localizer
        )
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
                let item = NSMenuItem(
                    title: "\(app.displayName) - \(memorySummary(for: app))",
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

    private func addBackgroundAppsSubmenu() {
        let apps = snapshot
            .filter { !$0.isFrontmost }
            .sorted { $0.memoryBytes > $1.memoryBytes }
            .prefix(12)

        let submenu = NSMenu()
        submenu.autoenablesItems = false
        for app in apps {
            let marker = cleanupMarker(for: app)
            let item = NSMenuItem(
                title: "\(app.displayName) - \(memorySummary(for: app)) - \(marker)",
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

    private func cleanupMarker(for app: AppRuntimeState) -> String {
        memoryPolicyEngine.shouldTerminate(app)
            ? localizer.t("menu.cleanable")
            : localizer.t("menu.notCleanable")
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
                item.image = menuIcon(forBundleID: bundleID)
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

    @objc private func openSettings(_ sender: NSMenuItem) {
        if settingsWindowController == nil {
            settingsWindowController = SettingsWindowController(
                settingsStore: settingsStore,
                memoryProvider: { SystemMemoryMonitor.capture() },
                onChange: { [weak self] in
                    self?.refreshSnapshot(performAutomaticRelease: true)
                    guard let self else { return }
                    self.eventLog.append(self.localizer.t("event.settingsUpdated"))
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

private final class MemoryDashboardMenuView: NSView {
    private let localizer: Localizer

    private enum Layout {
        static let width: CGFloat = 392
        static let contentWidth: CGFloat = 360
        static let sideInset: CGFloat = 16
    }

    init(
        memorySnapshot: SystemMemorySnapshot,
        thresholdConfiguration: MemoryThresholdConfiguration,
        isExceeded: Bool,
        localizer: Localizer
    ) {
        self.localizer = localizer
        super.init(frame: NSRect(x: 0, y: 0, width: Layout.width, height: 236))
        setup(
            memorySnapshot: memorySnapshot,
            thresholdConfiguration: thresholdConfiguration,
            isExceeded: isExceeded
        )
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setup(
        memorySnapshot: SystemMemorySnapshot,
        thresholdConfiguration: MemoryThresholdConfiguration,
        isExceeded: Bool
    ) {
        let effectView = NSVisualEffectView()
        effectView.material = .menu
        effectView.blendingMode = .withinWindow
        effectView.state = .active
        effectView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(effectView)

        let root = NSStackView()
        root.orientation = .vertical
        root.alignment = .leading
        root.spacing = 12
        root.translatesAutoresizingMaskIntoConstraints = false
        addSubview(root)

        NSLayoutConstraint.activate([
            effectView.leadingAnchor.constraint(equalTo: leadingAnchor),
            effectView.trailingAnchor.constraint(equalTo: trailingAnchor),
            effectView.topAnchor.constraint(equalTo: topAnchor),
            effectView.bottomAnchor.constraint(equalTo: bottomAnchor),
            root.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Layout.sideInset),
            root.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Layout.sideInset),
            root.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            root.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -16)
        ])

        root.addArrangedSubview(
            makeHeader(isExceeded: isExceeded)
        )
        root.addArrangedSubview(
            makePrimaryRAMBlock(
                memorySnapshot: memorySnapshot,
                thresholdConfiguration: thresholdConfiguration,
                isExceeded: isExceeded
            )
        )

        let swapDenominator = thresholdConfiguration.swapLimitEnabled
            ? thresholdConfiguration.swapLimitBytes
            : memorySnapshot.swapTotalBytes
        let swapProgress = progress(Double(memorySnapshot.swapUsedBytes), total: Double(max(swapDenominator, 1)))
        let compressedProgress = progress(Double(memorySnapshot.compressedBytes), total: Double(memorySnapshot.totalPhysicalBytes))

        let secondaryRow = NSStackView()
        secondaryRow.orientation = .horizontal
        secondaryRow.alignment = .top
        secondaryRow.spacing = 12
        secondaryRow.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            secondaryRow.widthAnchor.constraint(equalToConstant: Layout.contentWidth),
            secondaryRow.heightAnchor.constraint(equalToConstant: 66)
        ])

        secondaryRow.addArrangedSubview(
            makeSecondaryMetricBlock(
                title: localizer.t("menu.swap"),
                value: PercentFormatter.compact(swapProgress * 100),
                detail: ByteFormatter.memory(memorySnapshot.swapUsedBytes),
                progress: swapProgress,
                threshold: thresholdConfiguration.swapLimitEnabled ? 1 : nil,
                isExceeded: thresholdConfiguration.swapLimitEnabled && memorySnapshot.swapUsedBytes >= thresholdConfiguration.swapLimitBytes,
                systemImageName: "arrow.triangle.2.circlepath"
            )
        )
        secondaryRow.addArrangedSubview(
            makeSecondaryMetricBlock(
                title: localizer.t("menu.compressed"),
                value: PercentFormatter.compact(compressedProgress * 100),
                detail: ByteFormatter.memory(memorySnapshot.compressedBytes),
                progress: compressedProgress,
                threshold: nil,
                isExceeded: false,
                systemImageName: "rectangle.compress.vertical"
            )
        )

        root.addArrangedSubview(secondaryRow)
    }

    private func makeHeader(isExceeded: Bool) -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 8
        row.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            row.widthAnchor.constraint(equalToConstant: Layout.contentWidth),
            row.heightAnchor.constraint(equalToConstant: 24)
        ])

        let iconView = NSImageView(image: StatusIconFactory.makeImage(isExceeded: isExceeded))
        iconView.imageScaling = .scaleProportionallyDown
        iconView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            iconView.widthAnchor.constraint(equalToConstant: 18),
            iconView.heightAnchor.constraint(equalToConstant: 18)
        ])

        let titleLabel = label(
            "GreenRAM",
            font: .systemFont(ofSize: 13, weight: .semibold),
            color: .labelColor
        )
        let spacer = NSView()
        let statusLabel = label(
            isExceeded ? localizer.t("status.exceeded") : localizer.t("status.withinLimits"),
            font: .systemFont(ofSize: 13, weight: .semibold),
            color: statusColor(isExceeded)
        )

        row.addArrangedSubview(iconView)
        row.addArrangedSubview(titleLabel)
        row.addArrangedSubview(spacer)
        row.addArrangedSubview(statusLabel)
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        spacer.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        statusLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        return row
    }

    private func makePrimaryRAMBlock(
        memorySnapshot: SystemMemorySnapshot,
        thresholdConfiguration: MemoryThresholdConfiguration,
        isExceeded: Bool
    ) -> NSView {
        let color = statusColor(isExceeded)
        let block = DashboardBlockView()
        block.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            block.widthAnchor.constraint(equalToConstant: Layout.contentWidth),
            block.heightAnchor.constraint(equalToConstant: 86)
        ])

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        block.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: block.leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(equalTo: block.trailingAnchor, constant: -14),
            stack.topAnchor.constraint(equalTo: block.topAnchor, constant: 12),
            stack.bottomAnchor.constraint(equalTo: block.bottomAnchor, constant: -12)
        ])

        let topRow = NSStackView()
        topRow.orientation = .horizontal
        topRow.alignment = .centerY
        topRow.spacing = 10
        topRow.translatesAutoresizingMaskIntoConstraints = false
        topRow.widthAnchor.constraint(equalToConstant: Layout.contentWidth - 28).isActive = true

        let titleStack = NSStackView()
        titleStack.orientation = .vertical
        titleStack.alignment = .leading
        titleStack.spacing = 2

        let titleLabel = label(
            localizer.t("menu.ram"),
            font: .systemFont(ofSize: 13, weight: .semibold),
            color: .labelColor
        )
        let detailLabel = label(
            "\(ByteFormatter.memory(memorySnapshot.usedPhysicalBytes)) / \(ByteFormatter.memory(memorySnapshot.totalPhysicalBytes))",
            font: .monospacedDigitSystemFont(ofSize: 12, weight: .medium),
            color: .secondaryLabelColor
        )
        titleStack.addArrangedSubview(titleLabel)
        titleStack.addArrangedSubview(detailLabel)

        let spacer = NSView()
        let percentLabel = label(
            PercentFormatter.compact(memorySnapshot.usedPhysicalPercent),
            font: .monospacedDigitSystemFont(ofSize: 34, weight: .bold),
            color: color
        )

        topRow.addArrangedSubview(titleStack)
        topRow.addArrangedSubview(spacer)
        topRow.addArrangedSubview(percentLabel)
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        spacer.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        percentLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        let bar = MemoryMenuBarView(
            progress: memorySnapshot.usedPhysicalPercent / 100,
            threshold: thresholdConfiguration.ramLimitPercent / 100,
            color: color
        )
        bar.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            bar.widthAnchor.constraint(equalToConstant: Layout.contentWidth - 28),
            bar.heightAnchor.constraint(equalToConstant: 12)
        ])

        stack.addArrangedSubview(topRow)
        stack.addArrangedSubview(bar)
        return block
    }

    private func makeSecondaryMetricBlock(
        title: String,
        value: String,
        detail: String,
        progress: Double,
        threshold: Double?,
        isExceeded: Bool,
        systemImageName: String
    ) -> NSView {
        let color = statusColor(isExceeded)
        let block = DashboardBlockView()
        block.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            block.widthAnchor.constraint(equalToConstant: 174),
            block.heightAnchor.constraint(equalToConstant: 66)
        ])

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 5
        stack.translatesAutoresizingMaskIntoConstraints = false
        block.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: block.leadingAnchor, constant: 10),
            stack.trailingAnchor.constraint(equalTo: block.trailingAnchor, constant: -10),
            stack.topAnchor.constraint(equalTo: block.topAnchor, constant: 9),
            stack.bottomAnchor.constraint(equalTo: block.bottomAnchor, constant: -9)
        ])

        let titleRow = NSStackView()
        titleRow.orientation = .horizontal
        titleRow.alignment = .centerY
        titleRow.spacing = 6
        titleRow.translatesAutoresizingMaskIntoConstraints = false
        titleRow.widthAnchor.constraint(equalToConstant: 154).isActive = true

        let iconView = NSImageView()
        iconView.image = NSImage(systemSymbolName: systemImageName, accessibilityDescription: nil)
        iconView.contentTintColor = color
        iconView.imageScaling = .scaleProportionallyDown
        iconView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            iconView.widthAnchor.constraint(equalToConstant: 15),
            iconView.heightAnchor.constraint(equalToConstant: 15)
        ])

        let titleLabel = label(title, font: .systemFont(ofSize: 12, weight: .semibold), color: .labelColor)
        let spacer = NSView()
        let valueLabel = label(value, font: .monospacedDigitSystemFont(ofSize: 16, weight: .bold), color: color)
        valueLabel.alignment = .right

        titleRow.addArrangedSubview(iconView)
        titleRow.addArrangedSubview(titleLabel)
        titleRow.addArrangedSubview(spacer)
        titleRow.addArrangedSubview(valueLabel)
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        spacer.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        valueLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        let bar = MemoryMenuBarView(progress: progress, threshold: threshold, color: color)
        bar.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            bar.widthAnchor.constraint(equalToConstant: 154),
            bar.heightAnchor.constraint(equalToConstant: 8)
        ])

        let detailLabel = label(
            detail,
            font: .monospacedDigitSystemFont(ofSize: 11, weight: .medium),
            color: .secondaryLabelColor
        )

        stack.addArrangedSubview(titleRow)
        stack.addArrangedSubview(bar)
        stack.addArrangedSubview(detailLabel)
        return block
    }

    private func label(_ text: String, font: NSFont, color: NSColor) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = font
        label.textColor = color
        label.lineBreakMode = .byTruncatingTail
        label.maximumNumberOfLines = 1
        return label
    }

    private func statusColor(_ isExceeded: Bool) -> NSColor {
        isExceeded ? .systemRed : .systemGreen
    }

    private func progress(_ value: Double, total: Double) -> Double {
        guard total > 0 else { return 0 }
        return min(max(value / total, 0), 1)
    }
}

private final class DashboardBlockView: NSView {
    override var isOpaque: Bool {
        false
    }

    override func draw(_ dirtyRect: NSRect) {
        let rect = bounds.insetBy(dx: 0.5, dy: 0.5)
        let path = NSBezierPath(roundedRect: rect, xRadius: 8, yRadius: 8)
        NSColor.labelColor.withAlphaComponent(0.045).setFill()
        path.fill()

        NSColor.separatorColor.withAlphaComponent(0.16).setStroke()
        path.lineWidth = 1
        path.stroke()
    }
}

private final class MemoryMenuBarView: NSView {
    private let progress: Double
    private let threshold: Double?
    private let color: NSColor

    init(progress: Double, threshold: Double?, color: NSColor) {
        self.progress = min(max(progress, 0), 1)
        self.threshold = threshold.map { min(max($0, 0), 1) }
        self.color = color
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ dirtyRect: NSRect) {
        let rect = bounds.insetBy(dx: 0, dy: 2)
        let track = NSBezierPath(roundedRect: rect, xRadius: rect.height / 2, yRadius: rect.height / 2)
        NSColor.separatorColor.withAlphaComponent(0.35).setFill()
        track.fill()

        if progress > 0 {
            let fillWidth = max(rect.height, rect.width * progress)
            let fillRect = NSRect(x: rect.minX, y: rect.minY, width: min(fillWidth, rect.width), height: rect.height)
            let fill = NSBezierPath(roundedRect: fillRect, xRadius: rect.height / 2, yRadius: rect.height / 2)
            color.setFill()
            fill.fill()
        }

        if let threshold {
            let markerX = rect.minX + rect.width * threshold
            let markerRect = NSRect(x: markerX - 1, y: rect.minY - 2, width: 2, height: rect.height + 4)
            NSColor.labelColor.withAlphaComponent(0.35).setFill()
            NSBezierPath(roundedRect: markerRect, xRadius: 1, yRadius: 1).fill()
        }
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
