import AppKit
import SwiftUI
import MacAotoKillCore
import UniformTypeIdentifiers

final class SettingsWindowController: NSWindowController {
    private let viewModel: SettingsViewModel

    init(
        settingsStore: SettingsStore,
        whitelistStore: WhitelistStore,
        memoryProvider: @escaping () -> SystemMemorySnapshot,
        onChange: @escaping () -> Void,
        onWhitelistAdded: @escaping (String) -> Void,
        onWhitelistRemoved: @escaping (String) -> Void,
        onExportLogs: @escaping () -> Void
    ) {
        self.viewModel = SettingsViewModel(
            settingsStore: settingsStore,
            whitelistStore: whitelistStore,
            memoryProvider: memoryProvider,
            onChange: onChange,
            onWhitelistAdded: onWhitelistAdded,
            onWhitelistRemoved: onWhitelistRemoved,
            onExportLogs: onExportLogs
        )

        let window = NSWindow(
            contentRect: Self.defaultContentRect(),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.contentMinSize = NSSize(width: 700, height: 580)
        window.isReleasedWhenClosed = false
        super.init(window: window)

        window.contentViewController = NSHostingController(
            rootView: SettingsView(viewModel: viewModel)
        )
        updateTitle()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show() {
        viewModel.load()
        viewModel.refreshMemory()
        updateTitle()
        showWindow(nil)
        window?.center()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func updateTitle() {
        window?.title = viewModel.localizer.t("settings.title")
    }

    private static func defaultContentRect() -> NSRect {
        let screenWidth = NSScreen.main?.frame.width ?? 1520
        return NSRect(
            x: 0,
            y: 0,
            width: max(700, screenWidth / 2),
            height: 640
        )
    }
}

private struct WhitelistAppInfo: Identifiable {
    let bundleID: String
    let displayName: String
    let icon: NSImage
    let isDefaultSeed: Bool

    var id: String {
        bundleID
    }
}

private struct IdleTimeAppInfo: Identifiable {
    let bundleID: String
    let displayName: String
    let icon: NSImage

    var id: String {
        bundleID
    }
}

private struct AppDisplayInfo {
    let bundleID: String
    let displayName: String
    let icon: NSImage
}

private final class SettingsViewModel: ObservableObject {
    private let settingsStore: SettingsStore
    private let whitelistStore: WhitelistStore
    private let memoryProvider: () -> SystemMemorySnapshot
    private let onChange: () -> Void
    private let onWhitelistAdded: (String) -> Void
    private let onWhitelistRemoved: (String) -> Void
    private let onExportLogs: () -> Void

    @Published var memorySnapshot: SystemMemorySnapshot
    @Published var languageCode: String
    @Published var ramLimitPercent: Double
    @Published var swapLimitEnabled: Bool
    @Published var swapLimitGB: Double
    @Published var minimumBackgroundMinutes: Double
    @Published var appIdleTimeItems: [IdleTimeAppInfo]
    @Published var whitelistItems: [WhitelistAppInfo]
    @Published var newIdleTimeBundleID = ""
    @Published var newWhitelistBundleID = ""
    @Published var isResetConfirmationPresented = false
    private var idleTimeBundleIDs: [String]
    private var whitelistBundleIDs: [String]

    var localizer: Localizer {
        Localizer(languageCode: languageCode)
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
        self.memorySnapshot = memoryProvider()
        self.languageCode = settingsStore.languageCode
        self.ramLimitPercent = settingsStore.ramLimitPercent
        self.swapLimitEnabled = settingsStore.swapLimitEnabled
        self.swapLimitGB = Double(settingsStore.swapLimitBytes) / Double(1024 * 1024 * 1024)
        self.minimumBackgroundMinutes = settingsStore.minimumBackgroundDuration / 60
        let initialIdleTimeBundleIDs = settingsStore.minimumBackgroundDurationsByBundleID.keys.sorted()
        self.idleTimeBundleIDs = initialIdleTimeBundleIDs
        self.appIdleTimeItems = Self.makeIdleTimeItems(from: initialIdleTimeBundleIDs, store: whitelistStore)
        let initialBundleIDs = whitelistStore.allBundleIDs.sorted()
        self.whitelistBundleIDs = initialBundleIDs
        self.whitelistItems = Self.makeWhitelistItems(from: initialBundleIDs, store: whitelistStore)
    }

    func load() {
        languageCode = settingsStore.languageCode
        ramLimitPercent = settingsStore.ramLimitPercent
        swapLimitEnabled = settingsStore.swapLimitEnabled
        swapLimitGB = Double(settingsStore.swapLimitBytes) / Double(1024 * 1024 * 1024)
        minimumBackgroundMinutes = settingsStore.minimumBackgroundDuration / 60
        reloadIdleTimeItems()
        reloadWhitelist()
    }

    func refreshMemory() {
        memorySnapshot = memoryProvider()
    }

    func save() {
        settingsStore.languageCode = languageCode
        settingsStore.ramLimitPercent = ramLimitPercent
        settingsStore.swapLimitEnabled = swapLimitEnabled
        let swapLimitBytes = UInt64(swapLimitGB * Double(1024 * 1024 * 1024))
        settingsStore.swapLimitBytes = max(MemoryPolicyDefaults.minimumSwapLimitBytes, swapLimitBytes)
        settingsStore.minimumBackgroundDuration = minimumBackgroundMinutes * 60
        onChange()
    }

    func resetDefaults() {
        settingsStore.resetMemoryPolicyDefaults()
        load()
        onChange()
    }

    func addIdleTimeBundleID() {
        let bundleID = normalizedNewIdleTimeBundleID
        guard canAddIdleTimeBundleID else { return }

        settingsStore.setMinimumBackgroundDuration(minimumBackgroundMinutes * 60, for: bundleID)
        newIdleTimeBundleID = ""
        reloadIdleTimeItems()
        onChange()
    }

    func chooseIdleTimeApplications() {
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

        guard panel.runModal() == .OK else { return }
        addIdleTimeApplications(panel.urls)
    }

    func idleTimeMinutes(for bundleID: String) -> Double {
        (settingsStore.minimumBackgroundDurationsByBundleID[bundleID] ?? settingsStore.minimumBackgroundDuration) / 60
    }

    func setIdleTimeMinutes(_ minutes: Double, for bundleID: String) {
        let clampedMinutes = min(max(minutes, 1), 240)
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

        whitelistStore.add(bundleID)
        newWhitelistBundleID = ""
        reloadWhitelist()
        onWhitelistAdded(bundleID)
    }

    func chooseWhitelistApplications() {
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
        newWhitelistBundleID.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var normalizedNewIdleTimeBundleID: String {
        newIdleTimeBundleID.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func reloadIdleTimeItems() {
        let bundleIDs = settingsStore.minimumBackgroundDurationsByBundleID.keys.sorted()
        idleTimeBundleIDs = bundleIDs
        appIdleTimeItems = Self.makeIdleTimeItems(from: bundleIDs, store: whitelistStore)
    }

    private func reloadWhitelist() {
        let bundleIDs = whitelistStore.allBundleIDs.sorted()
        whitelistBundleIDs = bundleIDs
        whitelistItems = Self.makeWhitelistItems(from: bundleIDs, store: whitelistStore)
    }

    private func addIdleTimeApplications(_ urls: [URL]) {
        var didChange = false
        for url in urls {
            guard
                let appURL = Self.existingApplicationURL(from: url),
                let bundle = Bundle(url: appURL),
                let bundleID = Self.nonEmpty(bundle.bundleIdentifier)
            else {
                continue
            }

            let oldDuration = settingsStore.minimumBackgroundDurationsByBundleID[bundleID]
            let newDuration = minimumBackgroundMinutes * 60
            settingsStore.setMinimumBackgroundDuration(newDuration, for: bundleID)
            whitelistStore.setAppPath(appURL.path, for: bundleID)
            didChange = didChange || oldDuration != newDuration
        }

        reloadIdleTimeItems()
        if didChange {
            onChange()
        }
    }

    private func addWhitelistApplications(_ urls: [URL]) {
        for url in urls {
            guard
                let appURL = Self.existingApplicationURL(from: url),
                let bundle = Bundle(url: appURL),
                let bundleID = Self.nonEmpty(bundle.bundleIdentifier)
            else {
                continue
            }

            let wasAlreadyWhitelisted = whitelistStore.contains(bundleID)
            whitelistStore.add(bundleID)
            whitelistStore.setAppPath(appURL.path, for: bundleID)
            if !wasAlreadyWhitelisted {
                onWhitelistAdded(bundleID)
            }
        }
        reloadWhitelist()
    }

    private static func makeIdleTimeItems(from bundleIDs: [String], store: WhitelistStore) -> [IdleTimeAppInfo] {
        bundleIDs
            .map { makeIdleTimeItem(bundleID: $0, store: store) }
            .sorted { lhs, rhs in
                let nameOrder = lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName)
                if nameOrder == .orderedSame {
                    return lhs.bundleID.localizedCaseInsensitiveCompare(rhs.bundleID) == .orderedAscending
                }
                return nameOrder == .orderedAscending
            }
    }

    private static func makeIdleTimeItem(bundleID: String, store: WhitelistStore) -> IdleTimeAppInfo {
        let appInfo = makeAppDisplayInfo(bundleID: bundleID, store: store)
        return IdleTimeAppInfo(
            bundleID: appInfo.bundleID,
            displayName: appInfo.displayName,
            icon: appInfo.icon
        )
    }

    private static func makeWhitelistItems(from bundleIDs: [String], store: WhitelistStore) -> [WhitelistAppInfo] {
        bundleIDs
            .map { makeWhitelistItem(bundleID: $0, store: store) }
            .sorted { lhs, rhs in
                let nameOrder = lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName)
                if nameOrder == .orderedSame {
                    return lhs.bundleID.localizedCaseInsensitiveCompare(rhs.bundleID) == .orderedAscending
                }
                return nameOrder == .orderedAscending
            }
    }

    private static func makeWhitelistItem(bundleID: String, store: WhitelistStore) -> WhitelistAppInfo {
        let appInfo = makeAppDisplayInfo(bundleID: bundleID, store: store)
        return WhitelistAppInfo(
            bundleID: appInfo.bundleID,
            displayName: appInfo.displayName,
            icon: appInfo.icon,
            isDefaultSeed: store.isDefaultProtected(bundleID)
        )
    }

    private static func makeAppDisplayInfo(bundleID: String, store: WhitelistStore) -> AppDisplayInfo {
        let cachedURL = store.appPath(for: bundleID).map { URL(fileURLWithPath: $0) }
        let appURL = cachedURL.flatMap(existingApplicationURL(from:))
            ?? NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)
        let runningApp = NSWorkspace.shared.runningApplications.first { $0.bundleIdentifier == bundleID }
        let bundle = appURL.flatMap(Bundle.init(url:))
        let displayName = nonEmpty(runningApp?.localizedName)
            ?? bundleDisplayName(bundle)
            ?? nonEmpty(appURL?.deletingPathExtension().lastPathComponent)
            ?? systemDisplayNameOverride(for: bundleID)
            ?? fallbackDisplayName(for: bundleID)
        let icon = appIcon(runningApp: runningApp, appURL: appURL, bundleID: bundleID)

        return AppDisplayInfo(
            bundleID: bundleID,
            displayName: displayName,
            icon: icon
        )
    }

    private static func existingApplicationURL(from url: URL) -> URL? {
        let standardizedURL = url.standardizedFileURL
        var isDirectory: ObjCBool = false
        guard
            FileManager.default.fileExists(atPath: standardizedURL.path, isDirectory: &isDirectory),
            isDirectory.boolValue,
            standardizedURL.pathExtension.lowercased() == "app"
        else {
            return nil
        }
        return standardizedURL
    }

    private static func bundleDisplayName(_ bundle: Bundle?) -> String? {
        nonEmpty(bundle?.localizedInfoDictionary?["CFBundleDisplayName"] as? String)
            ?? nonEmpty(bundle?.localizedInfoDictionary?["CFBundleName"] as? String)
            ?? nonEmpty(bundle?.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
            ?? nonEmpty(bundle?.object(forInfoDictionaryKey: "CFBundleName") as? String)
    }

    private static func appIcon(runningApp: NSRunningApplication?, appURL: URL?, bundleID: String) -> NSImage {
        if let runningIcon = runningApp?.icon {
            return scaledIcon(runningIcon)
        }
        if let appURL {
            return scaledIcon(NSWorkspace.shared.icon(forFile: appURL.path))
        }
        if bundleID == "com.apple.WindowServer",
           let displayIcon = NSImage(systemSymbolName: "display", accessibilityDescription: nil) {
            displayIcon.isTemplate = true
            return scaledIcon(displayIcon)
        }
        if let appBundleType = UTType("com.apple.application-bundle") {
            return scaledIcon(NSWorkspace.shared.icon(for: appBundleType))
        }
        return scaledIcon(NSImage(systemSymbolName: "app", accessibilityDescription: nil) ?? NSImage())
    }

    private static func scaledIcon(_ sourceImage: NSImage) -> NSImage {
        let image = (sourceImage.copy() as? NSImage) ?? sourceImage
        image.size = NSSize(width: 34, height: 34)
        return image
    }

    private static func systemDisplayNameOverride(for bundleID: String) -> String? {
        [
            "com.apple.finder": "Finder",
            "com.apple.dock": "Dock",
            "com.apple.WindowServer": "WindowServer",
            "com.apple.systempreferences": "System Preferences",
            "com.apple.SystemSettings": "System Settings"
        ][bundleID]
    }

    private static func fallbackDisplayName(for bundleID: String) -> String {
        nonEmpty(bundleID.split(separator: ".").last.map(String.init)) ?? bundleID
    }

    private static func nonEmpty(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }
}

private struct SettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel

    private var localizer: Localizer {
        viewModel.localizer
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                memorySection
                thresholdSection
                appIdleTimeSection
                whitelistSection
                languageSection
                logSection
                footer
            }
            .padding(28)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .frame(minWidth: 700, minHeight: 580)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            viewModel.refreshMemory()
        }
        .onChange(of: viewModel.languageCode) { _ in
            viewModel.save()
        }
        .onChange(of: viewModel.ramLimitPercent) { _ in
            viewModel.save()
        }
        .onChange(of: viewModel.swapLimitEnabled) { _ in
            viewModel.save()
        }
        .onChange(of: viewModel.swapLimitGB) { _ in
            viewModel.save()
        }
        .onChange(of: viewModel.minimumBackgroundMinutes) { _ in
            viewModel.save()
        }
        .alert(localizer.t("settings.resetConfirmTitle"), isPresented: $viewModel.isResetConfirmationPresented) {
            Button(localizer.t("settings.cancel"), role: .cancel) {}
            Button(localizer.t("settings.resetConfirmButton"), role: .destructive) {
                viewModel.resetDefaults()
            }
        } message: {
            Text(localizer.t("settings.resetConfirmMessage"))
        }
    }

    private var header: some View {
        HStack(spacing: 18) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 68, height: 68)
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 6) {
                Text(localizer.t("settings.title"))
                    .font(.largeTitle.weight(.bold))
                Text(memoryStatusText)
                    .font(.body)
                    .foregroundStyle(memoryStatusColor)
            }

            Spacer()
        }
    }

    private var memorySection: some View {
        settingsPanel(title: localizer.t("settings.currentMemory"), systemImage: "memorychip", color: memoryStatusColor) {
            HStack(spacing: 14) {
                metricChart(
                    title: localizer.t("settings.ramUsed"),
                    systemImage: "memorychip",
                    value: "\(ByteFormatter.memory(viewModel.memorySnapshot.usedPhysicalBytes)) / \(ByteFormatter.memory(viewModel.memorySnapshot.totalPhysicalBytes))",
                    detail: "\(PercentFormatter.compact(viewModel.memorySnapshot.usedPhysicalPercent)) · \(localizer.t("settings.ramLimit")) \(PercentFormatter.compact(viewModel.ramLimitPercent))",
                    progress: viewModel.memorySnapshot.usedPhysicalPercent / 100,
                    isExceeded: isRamExceeded
                )
                metricChart(
                    title: localizer.t("settings.swapUsed"),
                    systemImage: "arrow.triangle.2.circlepath",
                    value: "\(ByteFormatter.memory(viewModel.memorySnapshot.swapUsedBytes)) / \(ByteFormatter.memory(viewModel.memorySnapshot.swapTotalBytes))",
                    detail: viewModel.swapLimitEnabled
                        ? "\(localizer.t("settings.swapLimit")) \(ByteFormatter.memory(swapLimitBytes))"
                        : localizer.t("settings.swapMinimumHint"),
                    progress: swapProgress,
                    isExceeded: isSwapExceeded
                )
                metricChart(
                    title: localizer.t("menu.compressed"),
                    systemImage: "rectangle.compress.vertical",
                    value: ByteFormatter.memory(viewModel.memorySnapshot.compressedBytes),
                    detail: PercentFormatter.compact(compressedPercent),
                    progress: compressedPercent / 100,
                    isExceeded: false
                )
            }
        }
    }

    private var thresholdSection: some View {
        settingsPanel(title: localizer.t("settings.releaseThresholds"), systemImage: "gauge", color: memoryStatusColor) {
            VStack(spacing: 0) {
                valueRow(
                    title: localizer.t("settings.ramLimit"),
                    value: $viewModel.ramLimitPercent,
                    range: 1...100,
                    suffix: "%",
                    isExceeded: isRamExceeded
                )
                rowDivider
                toggleRow(
                    title: localizer.t("settings.swapLimitEnabled"),
                    isOn: $viewModel.swapLimitEnabled
                )
                if viewModel.swapLimitEnabled {
                    rowDivider
                    valueRow(
                        title: localizer.t("settings.swapLimit"),
                        value: $viewModel.swapLimitGB,
                        range: 2...128,
                        suffix: "GB",
                        isExceeded: isSwapExceeded
                    )
                    Text(localizer.t("settings.swapMinimumHint"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, 176)
                        .padding(.bottom, 12)
                }
                rowDivider
                valueRow(
                    title: localizer.t("settings.defaultBackgroundTime"),
                    value: $viewModel.minimumBackgroundMinutes,
                    range: 1...240,
                    suffix: "min",
                    isExceeded: false
                )
            }
        }
    }

    private var appIdleTimeSection: some View {
        settingsPanel(title: localizer.t("settings.appIdleTimes"), systemImage: "timer", color: Color(nsColor: .systemOrange)) {
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    Button {
                        viewModel.chooseIdleTimeApplications()
                    } label: {
                        Label(localizer.t("settings.chooseApp"), systemImage: "folder")
                    }

                    TextField(localizer.t("settings.bundleIDPlaceholder"), text: $viewModel.newIdleTimeBundleID)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                        .onSubmit {
                            viewModel.addIdleTimeBundleID()
                        }

                    Button {
                        viewModel.addIdleTimeBundleID()
                    } label: {
                        Label(localizer.t("settings.addBundleID"), systemImage: "plus")
                    }
                    .disabled(!viewModel.canAddIdleTimeBundleID)
                }
                .buttonStyle(.bordered)
                .padding(.vertical, 14)

                Divider()

                if viewModel.appIdleTimeItems.isEmpty {
                    Text(localizer.t("settings.noAppIdleTimeItems"))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 14)
                } else {
                    VStack(spacing: 0) {
                        ForEach(viewModel.appIdleTimeItems.indices, id: \.self) { index in
                            let item = viewModel.appIdleTimeItems[index]
                            appIdleTimeRow(item)
                            if index < viewModel.appIdleTimeItems.count - 1 {
                                Divider()
                                    .padding(.leading, 52)
                            }
                        }
                    }
                }
            }
        }
    }

    private var languageSection: some View {
        settingsPanel(title: localizer.t("settings.language"), systemImage: "globe", color: Color(nsColor: .systemBlue)) {
            HStack(spacing: 18) {
                Text(localizer.t("settings.language"))
                    .font(.body)
                    .frame(width: 160, alignment: .leading)

                Picker("", selection: $viewModel.languageCode) {
                    ForEach(AppLanguage.allCases, id: \.storageCode) { language in
                        Text(language.nativeDisplayName).tag(language.storageCode)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .frame(maxWidth: 260, alignment: .leading)

                Spacer()
            }
            .padding(.vertical, 16)
        }
    }

    private var whitelistSection: some View {
        settingsPanel(title: localizer.t("menu.whitelist"), systemImage: "checkmark.shield", color: Color(nsColor: .systemTeal)) {
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    Button {
                        viewModel.chooseWhitelistApplications()
                    } label: {
                        Label(localizer.t("settings.chooseApp"), systemImage: "folder")
                    }

                    TextField(localizer.t("settings.bundleIDPlaceholder"), text: $viewModel.newWhitelistBundleID)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                        .onSubmit {
                            viewModel.addWhitelistBundleID()
                        }

                    Button {
                        viewModel.addWhitelistBundleID()
                    } label: {
                        Label(localizer.t("settings.addBundleID"), systemImage: "plus")
                    }
                    .disabled(!viewModel.canAddWhitelistBundleID)
                }
                .buttonStyle(.bordered)
                .padding(.vertical, 14)

                Divider()

                if viewModel.whitelistItems.isEmpty {
                    Text(localizer.t("menu.noWhitelistItems"))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 14)
                } else {
                    VStack(spacing: 0) {
                        ForEach(viewModel.whitelistItems.indices, id: \.self) { index in
                            let item = viewModel.whitelistItems[index]
                            whitelistRow(item)
                            if index < viewModel.whitelistItems.count - 1 {
                                Divider()
                                    .padding(.leading, 52)
                            }
                        }
                    }
                }
            }
        }
    }

    private var logSection: some View {
        settingsPanel(title: localizer.t("settings.logs"), systemImage: "doc.text", color: Color(nsColor: .systemGray)) {
            HStack(spacing: 18) {
                Text(localizer.t("settings.logRetentionHint"))
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer()

                Button(localizer.t("settings.exportLogs")) {
                    viewModel.exportLogs()
                }
                .controlSize(.large)
            }
            .padding(.vertical, 16)
        }
    }

    private var footer: some View {
        HStack {
            Spacer()
            Button(localizer.t("settings.resetDefaults")) {
                viewModel.isResetConfirmationPresented = true
            }
            .controlSize(.large)
        }
    }

    private var isRamExceeded: Bool {
        viewModel.memorySnapshot.usedPhysicalPercent >= viewModel.ramLimitPercent
    }

    private var isSwapExceeded: Bool {
        viewModel.swapLimitEnabled && viewModel.memorySnapshot.swapUsedBytes >= swapLimitBytes
    }

    private var isAnyLimitExceeded: Bool {
        isRamExceeded || isSwapExceeded
    }

    private var swapLimitBytes: UInt64 {
        UInt64(max(2, viewModel.swapLimitGB) * Double(1024 * 1024 * 1024))
    }

    private var swapProgress: Double {
        if viewModel.swapLimitEnabled {
            return progress(Double(viewModel.memorySnapshot.swapUsedBytes), total: Double(swapLimitBytes))
        }
        return progress(Double(viewModel.memorySnapshot.swapUsedBytes), total: Double(viewModel.memorySnapshot.swapTotalBytes))
    }

    private var compressedPercent: Double {
        progress(Double(viewModel.memorySnapshot.compressedBytes), total: Double(viewModel.memorySnapshot.totalPhysicalBytes)) * 100
    }

    private var memoryStatusText: String {
        isAnyLimitExceeded
            ? localizer.t("status.exceeded")
            : localizer.t("status.withinLimits")
    }

    private var memoryStatusColor: Color {
        statusColor(isAnyLimitExceeded)
    }

    private var rowDivider: some View {
        Divider()
            .padding(.leading, 176)
    }

    private func settingsPanel<Content: View>(
        title: String,
        systemImage: String,
        color: Color,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 34, height: 34)
                    .background(color)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                Text(title)
                    .font(.title3.weight(.semibold))
            }

            content()
                .padding(.horizontal, 18)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    private func metricChart(
        title: String,
        systemImage: String,
        value: String,
        detail: String,
        progress: Double,
        isExceeded: Bool
    ) -> some View {
        let color = statusColor(isExceeded)

        return VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                GaugeRing(progress: progress, color: color)
                    .frame(width: 74, height: 74)
                    .overlay {
                        Image(systemName: systemImage)
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(color)
                    }

                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.headline)
                    Text(value)
                        .font(.system(.title3, design: .rounded).weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(minHeight: 112)
        .padding(16)
        .background(color.opacity(0.10))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(color.opacity(isExceeded ? 0.45 : 0.18), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func toggleRow(title: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 18) {
            Text(title)
                .font(.body)
                .frame(width: 160, alignment: .leading)

            Spacer()

            Toggle("", isOn: isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.large)
        }
        .padding(.vertical, 16)
    }

    private func valueRow(
        title: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        suffix: String,
        isExceeded: Bool
    ) -> some View {
        HStack(spacing: 18) {
            Text(title)
                .font(.body)
                .frame(width: 160, alignment: .leading)

            Slider(value: value, in: range)
                .tint(statusColor(isExceeded))
                .frame(minWidth: 260)

            TextField("", value: value, format: .number.precision(.fractionLength(0...1)))
                .multilineTextAlignment(.trailing)
                .font(.system(.body, design: .rounded).weight(.semibold))
                .frame(width: 82)

            Text(suffix)
                .frame(width: 30, alignment: .leading)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 16)
    }

    private func appIdleTimeBinding(for bundleID: String) -> Binding<Double> {
        Binding(
            get: {
                viewModel.idleTimeMinutes(for: bundleID)
            },
            set: { newValue in
                viewModel.setIdleTimeMinutes(newValue, for: bundleID)
            }
        )
    }

    private func appIdleTimeRow(_ item: IdleTimeAppInfo) -> some View {
        HStack(spacing: 14) {
            Image(nsImage: item.icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 34, height: 34)
                .clipShape(RoundedRectangle(cornerRadius: 7))

            VStack(alignment: .leading, spacing: 3) {
                Text(item.displayName)
                    .font(.body.weight(.semibold))
                    .lineLimit(1)

                Text(item.bundleID)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()

            TextField("", value: appIdleTimeBinding(for: item.bundleID), format: .number.precision(.fractionLength(0...1)))
                .multilineTextAlignment(.trailing)
                .font(.system(.body, design: .rounded).weight(.semibold))
                .frame(width: 82)

            Text("min")
                .frame(width: 30, alignment: .leading)
                .foregroundStyle(.secondary)

            Button {
                viewModel.removeIdleTimeBundleID(item.bundleID)
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .help(localizer.t("settings.removeAppIdleTime", item.bundleID))
        }
        .padding(.vertical, 11)
    }

    private func whitelistRow(_ item: WhitelistAppInfo) -> some View {
        HStack(spacing: 14) {
            Image(nsImage: item.icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 34, height: 34)
                .clipShape(RoundedRectangle(cornerRadius: 7))

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(item.displayName)
                        .font(.body.weight(.semibold))
                        .lineLimit(1)

                    if item.isDefaultSeed {
                        Text(localizer.t("settings.defaultWhitelistSeed"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                Text(item.bundleID)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()

            Button {
                viewModel.removeWhitelistBundleID(item.bundleID)
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .help(localizer.t("menu.removeBundleID", item.bundleID))
        }
        .padding(.vertical, 11)
    }

    private func statusColor(_ isExceeded: Bool) -> Color {
        Color(nsColor: isExceeded ? .systemRed : .systemGreen)
    }

    private func progress(_ value: Double, total: Double) -> Double {
        guard total > 0 else { return 0 }
        return min(max(value / total, 0), 1)
    }
}

private struct GaugeRing: View {
    let progress: Double
    let color: Color

    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.18), lineWidth: 9)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    color,
                    style: StrokeStyle(lineWidth: 9, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
        }
    }
}
