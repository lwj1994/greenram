import AppKit
import AppleViewModel
import Foundation
import MacAotoKillCore
import UniformTypeIdentifiers

@MainActor
final class SettingsViewModel: StateViewModel<SettingsState> {
    private let settingsStore: SettingsStore
    private let whitelistStore: WhitelistStore
    private let memoryProvider: () -> SystemMemorySnapshot
    private let onChange: () -> Void
    private let onWhitelistAdded: (String) -> Void
    private let onWhitelistRemoved: (String) -> Void
    private let onExportLogs: () -> Void
    private let onCheckForUpdates: () -> Void
    private let onShowOnboarding: () -> Void

    var localizer: Localizer {
        Localizer(languageCode: state.languageCode)
    }

    var canAddWhitelistBundleID: Bool {
        let bundleID = normalizedNewWhitelistBundleID
        return !bundleID.isEmpty
            && !AppIdentity.isOwnBundleIdentifier(bundleID)
            && !whitelistBundleIDs.contains(bundleID)
    }

    var canAddAutoQuitBundleID: Bool {
        let bundleID = normalizedNewAutoQuitBundleID
        return !bundleID.isEmpty
            && !AppIdentity.isOwnBundleIdentifier(bundleID)
            && !autoQuitBundleIDs.contains(bundleID)
    }

    var canAddIdleTimeBundleID: Bool {
        let bundleID = normalizedNewIdleTimeBundleID
        return !bundleID.isEmpty
            && !AppIdentity.isOwnBundleIdentifier(bundleID)
            && !idleTimeBundleIDs.contains(bundleID)
    }

    var canAddMemoryLimitBundleID: Bool {
        let bundleID = normalizedNewMemoryLimitBundleID
        return !bundleID.isEmpty
            && !AppIdentity.isOwnBundleIdentifier(bundleID)
            && !memoryLimitBundleIDs.contains(bundleID)
    }

    init(
        settingsStore: SettingsStore,
        whitelistStore: WhitelistStore,
        memoryProvider: @escaping () -> SystemMemorySnapshot,
        onChange: @escaping () -> Void,
        onWhitelistAdded: @escaping (String) -> Void,
        onWhitelistRemoved: @escaping (String) -> Void,
        onExportLogs: @escaping () -> Void,
        onCheckForUpdates: @escaping () -> Void,
        onShowOnboarding: @escaping () -> Void
    ) {
        self.settingsStore = settingsStore
        self.whitelistStore = whitelistStore
        self.memoryProvider = memoryProvider
        self.onChange = onChange
        self.onWhitelistAdded = onWhitelistAdded
        self.onWhitelistRemoved = onWhitelistRemoved
        self.onExportLogs = onExportLogs
        self.onCheckForUpdates = onCheckForUpdates
        self.onShowOnboarding = onShowOnboarding

        super.init(
            state: Self.makeState(
                settingsStore: settingsStore,
                whitelistStore: whitelistStore,
                memorySnapshot: memoryProvider()
            ),
            equals: ==
        )
    }

    func load() {
        setState(
            Self.makeState(
                settingsStore: settingsStore,
                whitelistStore: whitelistStore,
                memorySnapshot: state.memorySnapshot,
                newAutoQuitBundleID: state.newAutoQuitBundleID,
                newIdleTimeBundleID: state.newIdleTimeBundleID,
                newMemoryLimitBundleID: state.newMemoryLimitBundleID,
                newWhitelistBundleID: state.newWhitelistBundleID,
                isResetConfirmationPresented: state.isResetConfirmationPresented,
                blockedWhitelistedRuleBundleID: state.blockedWhitelistedRuleBundleID
            )
        )
    }

    func refreshMemory() {
        updateState { next in
            next.memorySnapshot = memoryProvider()
        }
    }

    func save() {
        let current = state
        settingsStore.languageCode = current.languageCode
        settingsStore.ramLimitPercent = current.ramLimitPercent
        settingsStore.swapLimitEnabled = current.swapLimitEnabled
        let swapLimitBytes = UInt64(current.swapLimitGB * Double(1024 * 1024 * 1024))
        settingsStore.swapLimitBytes = swapLimitBytes
        settingsStore.minimumBackgroundDuration = current.minimumBackgroundMinutes * 60
        settingsStore.automaticUpdateReminderEnabled = current.automaticUpdateReminderEnabled
        onChange()
    }

    func resetDefaults() {
        settingsStore.resetMemoryPolicyDefaults()
        load()
        onChange()
    }

    func setLanguageCode(_ languageCode: String) {
        updateState { $0.languageCode = languageCode }
    }

    func setSwapLimitEnabled(_ isEnabled: Bool) {
        updateState { $0.swapLimitEnabled = isEnabled }
    }

    func setSwapLimitGB(_ gigabytes: Double) {
        updateState { $0.swapLimitGB = Self.clampedSwapLimitGB(gigabytes) }
    }

    func setMinimumBackgroundMinutes(_ minutes: Double) {
        updateState { $0.minimumBackgroundMinutes = minutes }
    }

    func setAutomaticUpdateReminderEnabled(_ isEnabled: Bool) {
        updateState { $0.automaticUpdateReminderEnabled = isEnabled }
    }

    func setNewAutoQuitBundleID(_ bundleID: String) {
        updateState { $0.newAutoQuitBundleID = bundleID }
    }

    func setNewIdleTimeBundleID(_ bundleID: String) {
        updateState { $0.newIdleTimeBundleID = bundleID }
    }

    func setNewMemoryLimitBundleID(_ bundleID: String) {
        updateState { $0.newMemoryLimitBundleID = bundleID }
    }

    func setNewWhitelistBundleID(_ bundleID: String) {
        updateState { $0.newWhitelistBundleID = bundleID }
    }

    func setResetConfirmationPresented(_ isPresented: Bool) {
        updateState { $0.isResetConfirmationPresented = isPresented }
    }

    func clearBlockedWhitelistedRuleAlert() {
        updateState { $0.blockedWhitelistedRuleBundleID = nil }
    }

    func addAutoQuitBundleID() {
        let bundleID = normalizedNewAutoQuitBundleID
        guard canAddAutoQuitBundleID else { return }
        guard canAddRuleForNonWhitelistedApp(bundleID) else { return }

        settingsStore.setAutoQuitEnabled(true, for: bundleID)
        updateState { $0.newAutoQuitBundleID = "" }
        reloadAutoQuitItems()
        onChange()
    }

    func chooseAutoQuitApplications() {
        let panel = makeApplicationOpenPanel()

        guard panel.runModal() == .OK else { return }
        addAutoQuitApplications(panel.urls)
    }

    func removeAutoQuitBundleID(_ bundleID: String) {
        settingsStore.setAutoQuitEnabled(false, for: bundleID)
        reloadAutoQuitItems()
        onChange()
    }

    func addIdleTimeBundleID() {
        let bundleID = normalizedNewIdleTimeBundleID
        guard canAddIdleTimeBundleID else { return }
        guard canAddRuleForNonWhitelistedApp(bundleID) else { return }

        settingsStore.setMinimumBackgroundDuration(state.minimumBackgroundMinutes * 60, for: bundleID)
        updateState { $0.newIdleTimeBundleID = "" }
        reloadIdleTimeItems()
        onChange()
    }

    func chooseIdleTimeApplications() {
        let panel = makeApplicationOpenPanel()

        guard panel.runModal() == .OK else { return }
        addIdleTimeApplications(panel.urls)
    }

    func idleTimeMinutes(for bundleID: String) -> Double {
        (settingsStore.minimumBackgroundDurationsByBundleID[bundleID] ?? settingsStore.minimumBackgroundDuration) / 60
    }

    func setIdleTimeMinutes(_ minutes: Double, for bundleID: String) {
        let minimumMinutes = MemoryPolicyDefaults.minimumConfigurableBackgroundDuration / 60
        let clampedMinutes = min(max(minutes, minimumMinutes), 240)
        settingsStore.setMinimumBackgroundDuration(clampedMinutes * 60, for: bundleID)
        reloadIdleTimeItems()
        onChange()
    }

    func removeIdleTimeBundleID(_ bundleID: String) {
        settingsStore.setMinimumBackgroundDuration(nil, for: bundleID)
        reloadIdleTimeItems()
        onChange()
    }

    func addMemoryLimitBundleID() {
        let bundleID = normalizedNewMemoryLimitBundleID
        guard canAddMemoryLimitBundleID else { return }
        guard canAddRuleForNonWhitelistedApp(bundleID) else { return }

        settingsStore.setMemoryLimitBytes(MemoryPolicyDefaults.defaultAppMemoryLimitBytes, for: bundleID)
        updateState { $0.newMemoryLimitBundleID = "" }
        reloadMemoryLimitItems()
        onChange()
    }

    func chooseMemoryLimitApplications() {
        let panel = makeApplicationOpenPanel()

        guard panel.runModal() == .OK else { return }
        addMemoryLimitApplications(panel.urls)
    }

    func memoryLimitGB(for bundleID: String) -> Double {
        let bytes = settingsStore.memoryLimitsByBundleID[bundleID] ?? MemoryPolicyDefaults.defaultAppMemoryLimitBytes
        return Double(bytes) / Double(1024 * 1024 * 1024)
    }

    func setMemoryLimitGB(_ gigabytes: Double, for bundleID: String) {
        let clampedGigabytes = Self.clampedAppMemoryLimitGB(gigabytes)
        let bytes = UInt64(clampedGigabytes * Double(1024 * 1024 * 1024))
        settingsStore.setMemoryLimitBytes(bytes, for: bundleID)
        reloadMemoryLimitItems()
        onChange()
    }

    func removeMemoryLimitBundleID(_ bundleID: String) {
        settingsStore.setMemoryLimitBytes(nil, for: bundleID)
        reloadMemoryLimitItems()
        onChange()
    }

    func addWhitelistBundleID() {
        let bundleID = normalizedNewWhitelistBundleID
        guard canAddWhitelistBundleID else { return }

        let removedAutoQuitRule = settingsStore.isAutoQuitEnabled(for: bundleID)
        settingsStore.setAutoQuitEnabled(false, for: bundleID)
        whitelistStore.add(bundleID)
        updateState { $0.newWhitelistBundleID = "" }
        reloadAutoQuitItems()
        reloadWhitelist()
        onWhitelistAdded(bundleID)
        if removedAutoQuitRule {
            onChange()
        }
    }

    func chooseWhitelistApplications() {
        let panel = makeApplicationOpenPanel()

        guard panel.runModal() == .OK else { return }
        addWhitelistApplications(panel.urls)
    }

    func removeWhitelistBundleID(_ bundleID: String) {
        whitelistStore.remove(bundleID)
        reloadWhitelist()
        onWhitelistRemoved(bundleID)
    }

    func exportLogs() {
        onExportLogs()
    }

    func checkForUpdates() {
        onCheckForUpdates()
    }

    func showOnboarding() {
        onShowOnboarding()
    }

    private var normalizedNewWhitelistBundleID: String {
        state.newWhitelistBundleID.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var normalizedNewAutoQuitBundleID: String {
        state.newAutoQuitBundleID.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var normalizedNewIdleTimeBundleID: String {
        state.newIdleTimeBundleID.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var normalizedNewMemoryLimitBundleID: String {
        state.newMemoryLimitBundleID.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var autoQuitBundleIDs: Set<String> {
        Set(state.autoQuitItems.map(\.bundleID))
    }

    private var idleTimeBundleIDs: Set<String> {
        Set(state.appIdleTimeItems.map(\.bundleID))
    }

    private var memoryLimitBundleIDs: Set<String> {
        Set(state.appMemoryLimitItems.map(\.bundleID))
    }

    private var whitelistBundleIDs: Set<String> {
        Set(state.whitelistItems.map(\.bundleID))
    }

    private func makeApplicationOpenPanel() -> NSOpenPanel {
        let panel = NSOpenPanel()
        panel.title = localizer.t("settings.chooseApp")
        panel.prompt = localizer.t("settings.addBundleID")
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        panel.treatsFilePackagesAsDirectories = false

        let applicationsURL = URL(fileURLWithPath: "/Applications", isDirectory: true)
        if FileManager.default.fileExists(atPath: applicationsURL.path) {
            panel.directoryURL = applicationsURL
        }
        if let appBundleType = UTType("com.apple.application-bundle") {
            panel.allowedContentTypes = [appBundleType]
        }
        return panel
    }

    private func reloadAutoQuitItems() {
        let bundleIDs = settingsStore.autoQuitBundleIDs.sorted()
        updateState { next in
            next.autoQuitItems = SettingsAppInfoResolver.makeAutoQuitItems(from: bundleIDs, store: whitelistStore)
        }
    }

    private func reloadIdleTimeItems() {
        let bundleIDs = settingsStore.minimumBackgroundDurationsByBundleID.keys.sorted()
        updateState { next in
            next.appIdleTimeItems = SettingsAppInfoResolver.makeIdleTimeItems(from: bundleIDs, store: whitelistStore)
        }
    }

    private func reloadMemoryLimitItems() {
        let bundleIDs = settingsStore.memoryLimitsByBundleID.keys.sorted()
        updateState { next in
            next.appMemoryLimitItems = SettingsAppInfoResolver.makeMemoryLimitItems(from: bundleIDs, store: whitelistStore)
        }
    }

    private func reloadWhitelist() {
        let bundleIDs = whitelistStore.allBundleIDs.sorted()
        updateState { next in
            next.whitelistItems = SettingsAppInfoResolver.makeWhitelistItems(from: bundleIDs, store: whitelistStore)
        }
    }

    private func canAddRuleForNonWhitelistedApp(_ bundleID: String) -> Bool {
        guard whitelistStore.contains(bundleID) else { return true }
        updateState { $0.blockedWhitelistedRuleBundleID = bundleID }
        return false
    }

    private func addAutoQuitApplications(_ urls: [URL]) {
        var didChange = false
        for url in urls {
            guard
                let appURL = SettingsAppInfoResolver.existingApplicationURL(from: url),
                let bundle = Bundle(url: appURL),
                let bundleID = Self.nonEmpty(bundle.bundleIdentifier)
            else {
                continue
            }
            guard !AppIdentity.isOwnBundleIdentifier(bundleID) else { continue }
            guard canAddRuleForNonWhitelistedApp(bundleID) else { continue }

            let wasAlreadyAutoQuit = settingsStore.isAutoQuitEnabled(for: bundleID)
            settingsStore.setAutoQuitEnabled(true, for: bundleID)
            whitelistStore.setAppPath(appURL.path, for: bundleID)
            didChange = didChange || !wasAlreadyAutoQuit
        }

        reloadAutoQuitItems()
        if didChange {
            onChange()
        }
    }

    private func addIdleTimeApplications(_ urls: [URL]) {
        var didChange = false
        for url in urls {
            guard
                let appURL = SettingsAppInfoResolver.existingApplicationURL(from: url),
                let bundle = Bundle(url: appURL),
                let bundleID = Self.nonEmpty(bundle.bundleIdentifier)
            else {
                continue
            }
            guard !AppIdentity.isOwnBundleIdentifier(bundleID) else { continue }
            guard canAddRuleForNonWhitelistedApp(bundleID) else { continue }

            let oldDuration = settingsStore.minimumBackgroundDurationsByBundleID[bundleID]
            let newDuration = state.minimumBackgroundMinutes * 60
            settingsStore.setMinimumBackgroundDuration(newDuration, for: bundleID)
            whitelistStore.setAppPath(appURL.path, for: bundleID)
            didChange = didChange || oldDuration != newDuration
        }

        reloadIdleTimeItems()
        if didChange {
            onChange()
        }
    }

    private func addMemoryLimitApplications(_ urls: [URL]) {
        var didChange = false
        for url in urls {
            guard
                let appURL = SettingsAppInfoResolver.existingApplicationURL(from: url),
                let bundle = Bundle(url: appURL),
                let bundleID = Self.nonEmpty(bundle.bundleIdentifier)
            else {
                continue
            }
            guard !AppIdentity.isOwnBundleIdentifier(bundleID) else { continue }
            guard canAddRuleForNonWhitelistedApp(bundleID) else { continue }

            let oldLimit = settingsStore.memoryLimitsByBundleID[bundleID]
            settingsStore.setMemoryLimitBytes(MemoryPolicyDefaults.defaultAppMemoryLimitBytes, for: bundleID)
            whitelistStore.setAppPath(appURL.path, for: bundleID)
            didChange = didChange || oldLimit != MemoryPolicyDefaults.defaultAppMemoryLimitBytes
        }

        reloadMemoryLimitItems()
        if didChange {
            onChange()
        }
    }

    private func addWhitelistApplications(_ urls: [URL]) {
        var didRemoveAutoQuitRule = false
        for url in urls {
            guard
                let appURL = SettingsAppInfoResolver.existingApplicationURL(from: url),
                let bundle = Bundle(url: appURL),
                let bundleID = Self.nonEmpty(bundle.bundleIdentifier)
            else {
                continue
            }
            guard !AppIdentity.isOwnBundleIdentifier(bundleID) else { continue }

            let wasAlreadyWhitelisted = whitelistStore.contains(bundleID)
            if settingsStore.isAutoQuitEnabled(for: bundleID) {
                settingsStore.setAutoQuitEnabled(false, for: bundleID)
                didRemoveAutoQuitRule = true
            }
            whitelistStore.add(bundleID)
            whitelistStore.setAppPath(appURL.path, for: bundleID)
            if !wasAlreadyWhitelisted {
                onWhitelistAdded(bundleID)
            }
        }
        reloadAutoQuitItems()
        reloadWhitelist()
        if didRemoveAutoQuitRule {
            onChange()
        }
    }

    private func updateState(_ transform: (inout SettingsState) -> Void) {
        var next = state
        transform(&next)
        setState(next)
    }

    private static func makeState(
        settingsStore: SettingsStore,
        whitelistStore: WhitelistStore,
        memorySnapshot: SystemMemorySnapshot,
        newAutoQuitBundleID: String = "",
        newIdleTimeBundleID: String = "",
        newMemoryLimitBundleID: String = "",
        newWhitelistBundleID: String = "",
        isResetConfirmationPresented: Bool = false,
        blockedWhitelistedRuleBundleID: String? = nil
    ) -> SettingsState {
        let autoQuitBundleIDs = settingsStore.autoQuitBundleIDs.sorted()
        let idleTimeBundleIDs = settingsStore.minimumBackgroundDurationsByBundleID.keys.sorted()
        let memoryLimitBundleIDs = settingsStore.memoryLimitsByBundleID.keys.sorted()
        let whitelistBundleIDs = whitelistStore.allBundleIDs.sorted()

        return SettingsState(
            memorySnapshot: memorySnapshot,
            languageCode: settingsStore.languageCode,
            ramLimitPercent: settingsStore.ramLimitPercent,
            swapLimitEnabled: settingsStore.swapLimitEnabled,
            swapLimitGB: clampedSwapLimitGB(Double(settingsStore.swapLimitBytes) / Double(1024 * 1024 * 1024)),
            minimumBackgroundMinutes: settingsStore.minimumBackgroundDuration / 60,
            automaticUpdateReminderEnabled: settingsStore.automaticUpdateReminderEnabled,
            appVersion: AppIdentity.currentVersion,
            autoQuitItems: SettingsAppInfoResolver.makeAutoQuitItems(from: autoQuitBundleIDs, store: whitelistStore),
            appIdleTimeItems: SettingsAppInfoResolver.makeIdleTimeItems(from: idleTimeBundleIDs, store: whitelistStore),
            appMemoryLimitItems: SettingsAppInfoResolver.makeMemoryLimitItems(from: memoryLimitBundleIDs, store: whitelistStore),
            whitelistItems: SettingsAppInfoResolver.makeWhitelistItems(from: whitelistBundleIDs, store: whitelistStore),
            newAutoQuitBundleID: newAutoQuitBundleID,
            newIdleTimeBundleID: newIdleTimeBundleID,
            newMemoryLimitBundleID: newMemoryLimitBundleID,
            newWhitelistBundleID: newWhitelistBundleID,
            isResetConfirmationPresented: isResetConfirmationPresented,
            blockedWhitelistedRuleBundleID: blockedWhitelistedRuleBundleID
        )
    }

    private static func nonEmpty(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }

    private static func clampedSwapLimitGB(_ gigabytes: Double) -> Double {
        min(
            Double(MemoryPolicyDefaults.maximumSwapLimitBytes) / Double(1024 * 1024 * 1024),
            max(Double(MemoryPolicyDefaults.minimumSwapLimitBytes) / Double(1024 * 1024 * 1024), gigabytes)
        )
    }

    private static func clampedAppMemoryLimitGB(_ gigabytes: Double) -> Double {
        min(
            Double(MemoryPolicyDefaults.maximumAppMemoryLimitBytes) / Double(1024 * 1024 * 1024),
            max(Double(MemoryPolicyDefaults.minimumAppMemoryLimitBytes) / Double(1024 * 1024 * 1024), gigabytes)
        )
    }
}
