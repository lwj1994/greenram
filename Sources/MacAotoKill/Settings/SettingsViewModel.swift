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

    var localizer: Localizer {
        Localizer(languageCode: state.languageCode)
    }

    var canAddWhitelistBundleID: Bool {
        let bundleID = normalizedNewWhitelistBundleID
        return !bundleID.isEmpty && !whitelistBundleIDs.contains(bundleID)
    }

    var canAddIdleTimeBundleID: Bool {
        let bundleID = normalizedNewIdleTimeBundleID
        return !bundleID.isEmpty && !idleTimeBundleIDs.contains(bundleID)
    }

    init(
        settingsStore: SettingsStore,
        whitelistStore: WhitelistStore,
        memoryProvider: @escaping () -> SystemMemorySnapshot,
        onChange: @escaping () -> Void,
        onWhitelistAdded: @escaping (String) -> Void,
        onWhitelistRemoved: @escaping (String) -> Void,
        onExportLogs: @escaping () -> Void
    ) {
        self.settingsStore = settingsStore
        self.whitelistStore = whitelistStore
        self.memoryProvider = memoryProvider
        self.onChange = onChange
        self.onWhitelistAdded = onWhitelistAdded
        self.onWhitelistRemoved = onWhitelistRemoved
        self.onExportLogs = onExportLogs

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
                newIdleTimeBundleID: state.newIdleTimeBundleID,
                newWhitelistBundleID: state.newWhitelistBundleID,
                isResetConfirmationPresented: state.isResetConfirmationPresented
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

    func setNewIdleTimeBundleID(_ bundleID: String) {
        updateState { $0.newIdleTimeBundleID = bundleID }
    }

    func setNewWhitelistBundleID(_ bundleID: String) {
        updateState { $0.newWhitelistBundleID = bundleID }
    }

    func setResetConfirmationPresented(_ isPresented: Bool) {
        updateState { $0.isResetConfirmationPresented = isPresented }
    }

    func addIdleTimeBundleID() {
        let bundleID = normalizedNewIdleTimeBundleID
        guard canAddIdleTimeBundleID else { return }

        let wasWhitelisted = whitelistStore.contains(bundleID)
        whitelistStore.remove(bundleID)
        settingsStore.setMinimumBackgroundDuration(state.minimumBackgroundMinutes * 60, for: bundleID)
        updateState { $0.newIdleTimeBundleID = "" }
        reloadWhitelist()
        reloadIdleTimeItems()
        if wasWhitelisted {
            onWhitelistRemoved(bundleID)
        }
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

    func addWhitelistBundleID() {
        let bundleID = normalizedNewWhitelistBundleID
        guard canAddWhitelistBundleID else { return }

        settingsStore.setMinimumBackgroundDuration(nil, for: bundleID)
        whitelistStore.add(bundleID)
        updateState { $0.newWhitelistBundleID = "" }
        reloadIdleTimeItems()
        reloadWhitelist()
        onWhitelistAdded(bundleID)
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

    private var normalizedNewWhitelistBundleID: String {
        state.newWhitelistBundleID.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var normalizedNewIdleTimeBundleID: String {
        state.newIdleTimeBundleID.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var idleTimeBundleIDs: Set<String> {
        Set(state.appIdleTimeItems.map(\.bundleID))
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

    private func reloadIdleTimeItems() {
        let bundleIDs = settingsStore.minimumBackgroundDurationsByBundleID.keys.sorted()
        updateState { next in
            next.appIdleTimeItems = SettingsAppInfoResolver.makeIdleTimeItems(from: bundleIDs, store: whitelistStore)
        }
    }

    private func reloadWhitelist() {
        let bundleIDs = whitelistStore.allBundleIDs.sorted()
        updateState { next in
            next.whitelistItems = SettingsAppInfoResolver.makeWhitelistItems(from: bundleIDs, store: whitelistStore)
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

            let oldDuration = settingsStore.minimumBackgroundDurationsByBundleID[bundleID]
            let newDuration = state.minimumBackgroundMinutes * 60
            let wasWhitelisted = whitelistStore.contains(bundleID)
            whitelistStore.remove(bundleID)
            settingsStore.setMinimumBackgroundDuration(newDuration, for: bundleID)
            whitelistStore.setAppPath(appURL.path, for: bundleID)
            didChange = didChange || oldDuration != newDuration
            if wasWhitelisted {
                onWhitelistRemoved(bundleID)
            }
        }

        reloadWhitelist()
        reloadIdleTimeItems()
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

            let wasAlreadyWhitelisted = whitelistStore.contains(bundleID)
            if settingsStore.minimumBackgroundDurationsByBundleID[bundleID] != nil {
                settingsStore.setMinimumBackgroundDuration(nil, for: bundleID)
                didRemoveAutoQuitRule = true
            }
            whitelistStore.add(bundleID)
            whitelistStore.setAppPath(appURL.path, for: bundleID)
            if !wasAlreadyWhitelisted {
                onWhitelistAdded(bundleID)
            }
        }
        reloadIdleTimeItems()
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
        newIdleTimeBundleID: String = "",
        newWhitelistBundleID: String = "",
        isResetConfirmationPresented: Bool = false
    ) -> SettingsState {
        let idleTimeBundleIDs = settingsStore.minimumBackgroundDurationsByBundleID.keys.sorted()
        let whitelistBundleIDs = whitelistStore.allBundleIDs.sorted()

        return SettingsState(
            memorySnapshot: memorySnapshot,
            languageCode: settingsStore.languageCode,
            ramLimitPercent: settingsStore.ramLimitPercent,
            swapLimitEnabled: settingsStore.swapLimitEnabled,
            swapLimitGB: clampedSwapLimitGB(Double(settingsStore.swapLimitBytes) / Double(1024 * 1024 * 1024)),
            minimumBackgroundMinutes: settingsStore.minimumBackgroundDuration / 60,
            automaticUpdateReminderEnabled: settingsStore.automaticUpdateReminderEnabled,
            appIdleTimeItems: SettingsAppInfoResolver.makeIdleTimeItems(from: idleTimeBundleIDs, store: whitelistStore),
            whitelistItems: SettingsAppInfoResolver.makeWhitelistItems(from: whitelistBundleIDs, store: whitelistStore),
            newIdleTimeBundleID: newIdleTimeBundleID,
            newWhitelistBundleID: newWhitelistBundleID,
            isResetConfirmationPresented: isResetConfirmationPresented
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
}
