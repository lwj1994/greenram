import AppKit
import AppleViewModel
import MacAotoKillCore
import SwiftUI
import UniformTypeIdentifiers

/// 运行时中枢：采样、自动清理、更新检查，以及菜单栏面板、主窗口、引导页的生命周期。
@MainActor
final class AppCoordinator: NSObject, DashboardActions {
    private let whitelistStore = WhitelistStore()
    private let foregroundTracker = ForegroundTracker()
    private let settingsStore = SettingsStore()
    private let eventLog = EventLog()
    private var statusItemController: StatusItemController?
    private var mainWindowController: MainWindowController?
    private var onboardingWindowController: OnboardingWindowController?
    private var updateCheckTask: Task<Void, Never>?
    private var isCheckingForUpdates = false
    private var isInstallingUpdate = false
    private var isAutomaticUpdateCheckScheduled = false
    private var lastExternalFrontmostApp: NSRunningApplication?
    private var mainMenuLanguageCode: String?

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

    private let processLabeler = ProcessCommandLabeler()

    private lazy var idleChildProcessReaper = IdleChildProcessReaper(
        terminator: ProcessGroupTerminator(),
        logger: eventLog,
        localizerProvider: { [weak self] in self?.localizer ?? Localizer() },
        labelProvider: { [processLabeler] in processLabeler.label(for: $0) }
    )

    private lazy var dashboardSpec = ViewModelSpec<DashboardViewModel>(key: "dashboard") { [settingsStore] in
        DashboardViewModel(
            state: DashboardState(
                memory: SystemMemoryMonitor.capture(),
                isExceeded: false,
                ramLimitPercent: settingsStore.ramLimitPercent,
                swapLimitEnabled: settingsStore.swapLimitEnabled,
                swapLimitBytes: settingsStore.swapLimitBytes,
                languageCode: settingsStore.languageCode
            )
        )
    }

    private lazy var settingsSpec = ViewModelSpec<SettingsViewModel>(key: "settings") { [weak self, settingsStore, whitelistStore] in
        SettingsViewModel(
            settingsStore: settingsStore,
            whitelistStore: whitelistStore,
            memoryProvider: { SystemMemoryMonitor.capture() },
            onChange: {
                guard let self else { return }
                self.refreshSnapshot(performAutomaticRelease: true)
                self.scheduleAutomaticUpdateCheckIfNeeded()
                self.eventLog.append(self.localizer.t("event.settingsUpdated"))
            },
            onWhitelistAdded: { bundleID in
                guard let self else { return }
                self.eventLog.append(self.localizer.t("event.addedWhitelist", bundleID))
                self.refreshSnapshot()
            },
            onWhitelistRemoved: { bundleID in
                guard let self else { return }
                self.eventLog.append(self.localizer.t("event.removedWhitelist", bundleID))
                self.refreshSnapshot()
            },
            onExportLogs: { self?.exportLogs() },
            onCheckForUpdates: { self?.checkForUpdates() },
            onShowOnboarding: { self?.showOnboarding() }
        )
    }

    private lazy var dashboard = viewModelBinding.watch(dashboardSpec)
    private lazy var settingsViewModel = viewModelBinding.watch(settingsSpec)

    private var engineTimer: Timer?
    private var liveRefreshTimer: Timer?
    private var snapshot: [AppRuntimeState] = []
    private var memorySnapshot = SystemMemoryMonitor.capture()
    private var thresholdEvaluation = MemoryThresholdEvaluator.evaluate(
        snapshot: SystemMemoryMonitor.capture(),
        configuration: MemoryThresholdConfiguration()
    )
    private var lastAutomaticReleaseAt: Date?
    private let automaticReleaseCooldown: TimeInterval = 60
    private let automaticUpdateCheckInterval: TimeInterval = 24 * 60 * 60
    private let liveRefreshInterval: TimeInterval = 3
    private let memoryLeakDetector = SystemMemoryLeakDetector()
    private var systemProcessSummary: SystemProcessSummary?
    private var suspectedLeakPIDs: Set<pid_t> = []
    private var lastSystemProcessSampleAt: Date?
    private var isSamplingSystemProcesses = false
    /// 同一时间只弹一个管理员密码框。
    private var isAwaitingAdminPassword = false
    private let visibleSystemProcessSampleInterval: TimeInterval = 10
    private let backgroundSystemProcessSampleInterval: TimeInterval = 5 * 60

    private var localizer: Localizer {
        Localizer(languageCode: settingsStore.languageCode)
    }

    private var isDashboardVisible: Bool {
        (statusItemController?.isPopoverShown ?? false) || (mainWindowController?.isVisibleOnScreen ?? false)
    }

    func start() {
        dashboard.actions = self
        statusItemController = StatusItemController(
            content: MenuBarPanelView(viewModelSpec: dashboardSpec),
            onWillShow: { [weak self] in self?.refreshSnapshot(forcePublish: true) },
            onVisibilityChange: { [weak self] in self?.updateLiveRefresh() }
        )
        observeFrontmostApplication()
        foregroundTracker.start()
        startEngineTimer()
        refreshSnapshot()
        eventLog.append(localizer.t("event.started"))
        scheduleAutomaticUpdateCheckIfNeeded()

        if !settingsStore.hasCompletedOnboarding {
            showOnboarding()
        }
    }

    func stop() {
        engineTimer?.invalidate()
        engineTimer = nil
        liveRefreshTimer?.invalidate()
        liveRefreshTimer = nil
        updateCheckTask?.cancel()
        updateCheckTask = nil
        foregroundTracker.stop()
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }

    // MARK: - 采样

    private func startEngineTimer() {
        engineTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refreshSnapshot(performAutomaticRelease: true)
                self?.scheduleAutomaticUpdateCheckIfNeeded()
            }
        }
    }

    /// 菜单栏面板或主窗口可见时，额外按更短间隔刷新展示数据；不触发清理。
    private func updateLiveRefresh() {
        guard isDashboardVisible else {
            liveRefreshTimer?.invalidate()
            liveRefreshTimer = nil
            return
        }
        guard liveRefreshTimer == nil else { return }
        refreshSnapshot(forcePublish: true)
        liveRefreshTimer = Timer.scheduledTimer(withTimeInterval: liveRefreshInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refreshSnapshot()
            }
        }
    }

    private func refreshSnapshot(performAutomaticRelease: Bool = false, forcePublish: Bool = false) {
        memorySnapshot = SystemMemoryMonitor.capture()
        thresholdEvaluation = MemoryThresholdEvaluator.evaluate(
            snapshot: memorySnapshot,
            configuration: makeThresholdConfiguration()
        )
        memoryPolicyEngine.configuration = makePolicyConfiguration()
        snapshot = processMonitor.sample()
        if performAutomaticRelease {
            idleChildProcessReaper.reap(processMonitor.lastProcessTree, apps: snapshot)
            releaseAutomaticallyIfNeeded()
        }
        updateStatusItem()
        updateMainMenuIfNeeded()
        if forcePublish || isDashboardVisible {
            publishDashboard()
        }
        sampleSystemProcessesIfNeeded()
    }

    /// 用 `top` 读一次全部进程的内存，在后台线程执行：面板或主窗口可见时每 10 秒，否则每 5 分钟。
    /// 每次采样后做泄漏检查。
    private func sampleSystemProcessesIfNeeded() {
        let now = Date()
        guard !isSamplingSystemProcesses else { return }
        let interval = isDashboardVisible ? visibleSystemProcessSampleInterval : backgroundSystemProcessSampleInterval
        if let lastSystemProcessSampleAt, now.timeIntervalSince(lastSystemProcessSampleAt) < interval {
            return
        }

        lastSystemProcessSampleAt = now
        isSamplingSystemProcesses = true
        let tree = processMonitor.lastProcessTree
        let appPIDs = snapshot.map(\.pid)
        Task.detached(priority: .utility) {
            let summary = SystemProcessSampler.summarize(
                tree: tree,
                appPIDs: appPIDs,
                memoryByPID: TopMemoryReader.readMemory()
            )
            await MainActor.run { [weak self] in
                guard let self else { return }
                isSamplingSystemProcesses = false
                systemProcessSummary = summary
                memoryLeakDetector.observe(summary)
                let suspectedPIDs = Set(memoryLeakDetector.suspects(in: summary).map(\.process.pid))
                suspectedLeakPIDs = suspectedPIDs
                dashboard.update {
                    $0.systemProcesses = summary
                    $0.suspectedLeakPIDs = suspectedPIDs
                }
                handleMemoryLeaks(in: summary)
            }
        }
    }

    private func publishDashboard() {
        let now = Date()
        let tree = processMonitor.lastProcessTree
        let configuration = memoryPolicyEngine.configuration
        let idleGroups = idleChildProcessReaper.idleGroups(in: tree, apps: snapshot, now: now)
        let cleanableChildPIDs = Set(idleGroups.flatMap { $0.entries.map(\.pid) })

        let apps = snapshot.map { app in
            DashboardApp(
                pid: app.pid,
                bundleID: app.bundleID,
                displayName: app.displayName,
                memoryBytes: app.memoryBytes,
                childMemoryBytes: app.descendantMemoryBytes,
                childProcessCount: app.descendantProcessCount,
                backgroundDuration: app.backgroundDuration(now: now),
                backgroundThreshold: configuration.backgroundDurationThreshold(for: app.bundleID),
                status: memoryPolicyEngine.cleanupStatus(app, now: now),
                isAutoQuit: configuration.isAutoQuitApp(app.bundleID),
                isWhitelisted: app.isWhitelisted,
                memoryLimitBytes: configuration.memoryLimit(for: app.bundleID),
                children: app.descendantProcessCount > 0
                    ? ChildProcessSummary.summaries(
                        appPID: app.pid,
                        in: tree,
                        cleanablePIDs: cleanableChildPIDs,
                        label: processLabeler.label(for:)
                    )
                    : []
            )
        }

        let thresholdConfiguration = makeThresholdConfiguration()
        dashboard.update { state in
            state.memory = memorySnapshot
            state.isExceeded = thresholdEvaluation.isExceeded
            state.ramLimitPercent = thresholdConfiguration.ramLimitPercent
            state.swapLimitEnabled = thresholdConfiguration.swapLimitEnabled
            state.swapLimitBytes = thresholdConfiguration.swapLimitBytes
            state.languageCode = settingsStore.languageCode
            state.apps = apps
            state.idleChildGroupCount = idleGroups.count
            state.idleChildMemoryBytes = idleGroups.reduce(0) { $0 + $1.memoryBytes }
            state.systemProcesses = systemProcessSummary
            state.suspectedLeakPIDs = suspectedLeakPIDs
            state.events = eventLog.recentEntries(limit: 500)
            state.frontmostApp = frontmostAppInfo()
            state.isCheckingForUpdates = isCheckingForUpdates
            state.isInstallingUpdate = isInstallingUpdate
        }
    }

    private func makePolicyConfiguration() -> MemoryPolicyConfiguration {
        MemoryPolicyConfiguration(
            autoReleaseEnabled: true,
            minimumBackgroundDuration: settingsStore.minimumBackgroundDuration,
            minimumBackgroundDurationsByBundleID: settingsStore.minimumBackgroundDurationsByBundleID,
            autoQuitBundleIDs: settingsStore.autoQuitBundleIDs,
            memoryLimitsByBundleID: settingsStore.memoryLimitsByBundleID,
            isMemoryLimitExceeded: thresholdEvaluation.isExceeded,
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
        let now = Date()
        guard !memoryPolicyEngine.candidates(for: snapshot, now: now).isEmpty else { return }

        if let lastAutomaticReleaseAt, now.timeIntervalSince(lastAutomaticReleaseAt) < automaticReleaseCooldown {
            return
        }

        self.lastAutomaticReleaseAt = now
        eventLog.append(localizer.t("event.autoReleaseTrigger", localizer.t("event.backgroundIdleTimeout")))
        memoryPolicyEngine.handleAutomaticRelease(states: snapshot, now: now)
    }

    // MARK: - 系统进程

    /// 疑似泄漏的 Apple 系统进程自动结束：当前用户的直接结束，root 的弹管理员密码框（一次一个）。
    /// 其他进程（开发工具的 JVM、虚拟机等）只记事件和标记，由用户右键结束。每个进程只处理一次。
    private func handleMemoryLeaks(in summary: SystemProcessSummary) {
        for suspect in memoryLeakDetector.unhandledSuspects(in: summary) {
            let process = suspect.process
            let memory = ByteFormatter.memory(process.memoryBytes)
            let growth = ByteFormatter.memory(suspect.growthBytes)

            guard suspect.isAutoTerminable else {
                memoryLeakDetector.markHandled(suspect)
                eventLog.append(localizer.t("event.systemMemoryLeakFlagged", process.name, Int(process.pid), memory, growth))
                continue
            }

            let needsPassword = process.entry.userID != getuid()
            if needsPassword && isAwaitingAdminPassword { continue }
            memoryLeakDetector.markHandled(suspect)
            eventLog.append(localizer.t("event.systemMemoryLeakTerminating", process.name, Int(process.pid), memory, growth))
            terminateSystemProcess(
                process.entry,
                name: process.name,
                adminPrompt: localizer.t("systemProcesses.adminPrompt", process.name, memory)
            )
        }
    }

    private func terminateSystemProcess(_ entry: ProcessTreeEntry, name: String, adminPrompt: String? = nil) {
        let needsPassword = entry.userID != getuid()
        if needsPassword {
            isAwaitingAdminPassword = true
        }
        Task.detached(priority: .userInitiated) {
            let result = SystemProcessTerminator.terminate(entry, adminPrompt: adminPrompt)
            await MainActor.run { [weak self] in
                guard let self else { return }
                if needsPassword {
                    isAwaitingAdminPassword = false
                }
                switch result {
                case .terminated:
                    eventLog.append(localizer.t("event.systemProcessTerminated", name))
                case .cancelled:
                    eventLog.append(localizer.t("event.systemProcessTerminateCancelled", name))
                case .failed(let message):
                    eventLog.append(localizer.t("event.systemProcessTerminateFailed", name, message))
                }
                lastSystemProcessSampleAt = nil
                refreshSnapshot(forcePublish: true)
            }
        }
    }

    /// 右键强制退出系统进程。root 等其他用户的进程直接弹管理员密码框（密码框即确认）；当前用户的进程先二次确认。
    func forceQuitSystemProcess(pid: pid_t) {
        guard let process = systemProcessSummary?.processes.first(where: { $0.pid == pid }), !process.isProtected else {
            return
        }

        if process.entry.userID == getuid() {
            let alert = NSAlert()
            alert.alertStyle = .warning
            alert.icon = nil
            alert.messageText = localizer.t("apps.forceQuitConfirmTitle", process.name)
            alert.informativeText = localizer.t("systemProcesses.forceQuitConfirmMessage")
            alert.addButton(withTitle: localizer.t("apps.forceQuitButton"))
            alert.addButton(withTitle: localizer.t("settings.cancel"))
            alert.buttons.first?.hasDestructiveAction = true

            statusItemController?.closePopover()
            NSApp.activate(ignoringOtherApps: true)
            if let window = mainWindowController?.window, window.isVisible {
                alert.beginSheetModal(for: window) { [weak self] response in
                    if response == .alertFirstButtonReturn {
                        self?.requestSystemProcessTermination(process)
                    }
                }
                return
            }
            guard alert.runModal() == .alertFirstButtonReturn else { return }
        }
        requestSystemProcessTermination(process)
    }

    private func requestSystemProcessTermination(_ process: SystemProcessUsage) {
        eventLog.append(localizer.t("event.manualForceQuit", process.name))
        terminateSystemProcess(process.entry, name: process.name)
    }

    private func updateStatusItem() {
        let candidateCount = memoryPolicyEngine.candidates(for: snapshot).count
        let toolTip = candidateCount > 0
            ? "\(localizer.t("dashboard.candidates")) · \(candidateCount)"
            : (thresholdEvaluation.isExceeded ? localizer.t("status.exceeded") : localizer.t("status.withinLimits"))
        statusItemController?.update(isExceeded: thresholdEvaluation.isExceeded, toolTip: toolTip)
    }

    // MARK: - 前台 App

    private func observeFrontmostApplication() {
        if let app = NSWorkspace.shared.frontmostApplication, !Self.isOwnApplication(app) {
            lastExternalFrontmostApp = app
        }
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(applicationDidActivate(_:)),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )
    }

    @objc private func applicationDidActivate(_ notification: Notification) {
        guard
            let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
            !Self.isOwnApplication(app)
        else {
            return
        }
        lastExternalFrontmostApp = app
    }

    /// `swift run` 启动时没有 Bundle ID，所以同时按 pid 排除自己。
    private static func isOwnApplication(_ app: NSRunningApplication) -> Bool {
        app.processIdentifier == ProcessInfo.processInfo.processIdentifier
            || AppIdentity.isOwnBundleIdentifier(app.bundleIdentifier)
    }

    /// 打开菜单栏面板时 GreenRAM 会成为前台，这里取的是在它之前的那个 App。
    private func frontmostAppInfo() -> FrontmostAppInfo? {
        guard
            let app = lastExternalFrontmostApp,
            !app.isTerminated,
            let bundleID = app.bundleIdentifier
        else {
            return nil
        }
        return FrontmostAppInfo(
            bundleID: bundleID,
            displayName: app.localizedName ?? bundleID,
            isWhitelisted: whitelistStore.contains(bundleID)
        )
    }

    // MARK: - DashboardActions

    func cleanAppsNow() {
        refreshSnapshot()
        eventLog.append(localizer.t("event.manualRelease"))
        memoryPolicyEngine.handleManualRelease(states: snapshot)
        refreshSnapshot(forcePublish: true)
    }

    func setWhitelisted(_ isWhitelisted: Bool, bundleID: String) {
        guard !AppIdentity.isOwnBundleIdentifier(bundleID) else { return }
        if isWhitelisted {
            settingsStore.setAutoQuitEnabled(false, for: bundleID)
            whitelistStore.add(bundleID)
            eventLog.append(localizer.t("event.addedWhitelist", bundleID))
        } else {
            whitelistStore.remove(bundleID)
            eventLog.append(localizer.t("event.removedWhitelist", bundleID))
        }
        settingsViewModel.load()
        refreshSnapshot(forcePublish: true)
    }

    func setAutoQuit(_ isAutoQuit: Bool, bundleID: String) {
        guard !AppIdentity.isOwnBundleIdentifier(bundleID) else { return }
        // 白名单 App 必须先移出白名单，才能加入 Auto-Quit。
        guard !isAutoQuit || !whitelistStore.contains(bundleID) else { return }
        settingsStore.setAutoQuitEnabled(isAutoQuit, for: bundleID)
        eventLog.append(localizer.t("event.settingsUpdated"))
        settingsViewModel.load()
        refreshSnapshot(forcePublish: true)
    }

    /// 手动强制退出单个 App。白名单只约束自动清理，不拦截用户的手动操作；先二次确认。
    func forceQuit(pid: pid_t) {
        guard
            let app = snapshot.first(where: { $0.pid == pid }),
            app.pid != ProcessInfo.processInfo.processIdentifier,
            !AppIdentity.isOwnBundleIdentifier(app.bundleID)
        else {
            return
        }

        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.icon = AppIconCache.icon(bundleID: app.bundleID, pid: app.pid)
        alert.messageText = localizer.t("apps.forceQuitConfirmTitle", app.displayName)
        alert.informativeText = localizer.t("apps.forceQuitConfirmMessage")
        alert.addButton(withTitle: localizer.t("apps.forceQuitButton"))
        alert.addButton(withTitle: localizer.t("settings.cancel"))
        alert.buttons.first?.hasDestructiveAction = true

        if let window = mainWindowController?.window, window.isVisible {
            alert.beginSheetModal(for: window) { [weak self] response in
                if response == .alertFirstButtonReturn {
                    self?.performForceQuit(app)
                }
            }
        } else {
            statusItemController?.closePopover()
            NSApp.activate(ignoringOtherApps: true)
            if alert.runModal() == .alertFirstButtonReturn {
                performForceQuit(app)
            }
        }
    }

    private func performForceQuit(_ app: AppRuntimeState) {
        eventLog.append(localizer.t("event.manualForceQuit", app.displayName))
        actionExecutor.forceQuit(app)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            self?.refreshSnapshot(forcePublish: true)
        }
    }

    func openMainWindow(page: MainPage?) {
        statusItemController?.closePopover()
        if let page {
            dashboard.select(page)
        }
        if mainWindowController == nil {
            mainWindowController = MainWindowController(
                dashboardSpec: dashboardSpec,
                settingsSpec: settingsSpec,
                onVisibilityChange: { [weak self] in self?.windowVisibilityDidChange() }
            )
        }
        settingsViewModel.load()
        settingsViewModel.refreshMemory()
        refreshSnapshot(forcePublish: true)
        setActivationPolicy(.regular)
        mainWindowController?.show()
    }

    func checkForUpdates() {
        statusItemController?.closePopover()
        beginUpdateCheck(isUserInitiated: true)
    }

    func showOnboarding() {
        if onboardingWindowController == nil {
            onboardingWindowController = OnboardingWindowController(
                localizerProvider: { [weak self] in self?.localizer ?? Localizer() },
                onFinish: { [weak self] in self?.finishOnboarding() },
                onClose: { [weak self] in
                    self?.settingsStore.hasCompletedOnboarding = true
                    self?.windowVisibilityDidChange()
                }
            )
        }
        setActivationPolicy(.regular)
        onboardingWindowController?.show()
    }

    func quit() {
        NSApp.terminate(nil)
    }

    private func finishOnboarding() {
        settingsStore.hasCompletedOnboarding = true
        onboardingWindowController?.close()
        openMainWindow(page: .overview)
    }

    // MARK: - 窗口与 Dock

    private func windowVisibilityDidChange() {
        let hasOpenWindow = (mainWindowController?.isOpen ?? false) || (onboardingWindowController?.isOpen ?? false)
        setActivationPolicy(hasOpenWindow ? .regular : .accessory)
        updateLiveRefresh()
    }

    /// 有窗口时显示 Dock 图标和菜单栏菜单，窗口全部关闭后回到纯菜单栏 App。
    private func setActivationPolicy(_ policy: NSApplication.ActivationPolicy) {
        guard NSApp.activationPolicy() != policy else { return }
        NSApp.setActivationPolicy(policy)
        if policy == .regular {
            DevelopmentAppIcon.applyIfNeeded()
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    private func updateMainMenuIfNeeded() {
        let languageCode = settingsStore.languageCode
        guard languageCode != mainMenuLanguageCode else { return }
        mainMenuLanguageCode = languageCode
        NSApp.mainMenu = MainMenuBuilder.makeMenu(localizer: localizer, target: self)
    }

    @objc func showAboutPanel(_ sender: Any?) {
        NSApp.orderFrontStandardAboutPanel(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc func openSettingsFromMenu(_ sender: Any?) {
        openMainWindow(page: .settings)
    }

    @objc func openMainWindowFromMenu(_ sender: Any?) {
        openMainWindow(page: nil)
    }

    @objc func checkForUpdatesFromMenu(_ sender: Any?) {
        checkForUpdates()
    }

    // MARK: - 更新

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
        publishUpdateState()
        let checker = GitHubReleaseUpdateChecker(currentVersion: AppIdentity.currentVersion)
        updateCheckTask?.cancel()
        updateCheckTask = Task { @MainActor [weak self] in
            do {
                let result = try await checker.checkForUpdate()
                self?.completeUpdateCheck(result, isUserInitiated: isUserInitiated)
            } catch is CancellationError {
                self?.isCheckingForUpdates = false
                self?.publishUpdateState()
            } catch {
                self?.failUpdateCheck(error, isUserInitiated: isUserInitiated)
            }
        }
    }

    private func publishUpdateState() {
        dashboard.update { state in
            state.isCheckingForUpdates = isCheckingForUpdates
            state.isInstallingUpdate = isInstallingUpdate
        }
    }

    private func completeUpdateCheck(_ result: AppUpdateCheckResult, isUserInitiated: Bool) {
        isCheckingForUpdates = false
        updateCheckTask = nil
        settingsStore.lastUpdateCheckAt = Date()
        publishUpdateState()

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
        publishUpdateState()
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
        publishUpdateState()
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
        publishUpdateState()
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

    // MARK: - 日志

    func exportLogs() {
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
        refreshSnapshot()
    }

    private static func fileTimestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter.string(from: Date())
    }
}
