import AppKit
import SwiftUI
import MacAotoKillCore

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
    @Published var whitelistBundleIDs: [String]
    @Published var newWhitelistBundleID = ""
    @Published var isResetConfirmationPresented = false

    var localizer: Localizer {
        Localizer(languageCode: languageCode)
    }

    var canAddWhitelistBundleID: Bool {
        let bundleID = normalizedNewWhitelistBundleID
        return !bundleID.isEmpty && !whitelistBundleIDs.contains(bundleID)
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
        self.whitelistBundleIDs = whitelistStore.allBundleIDs.sorted()
    }

    func load() {
        languageCode = settingsStore.languageCode
        ramLimitPercent = settingsStore.ramLimitPercent
        swapLimitEnabled = settingsStore.swapLimitEnabled
        swapLimitGB = Double(settingsStore.swapLimitBytes) / Double(1024 * 1024 * 1024)
        minimumBackgroundMinutes = settingsStore.minimumBackgroundDuration / 60
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

    func isDefaultWhitelistSeed(_ bundleID: String) -> Bool {
        whitelistStore.isDefaultProtected(bundleID)
    }

    func addWhitelistBundleID() {
        let bundleID = normalizedNewWhitelistBundleID
        guard canAddWhitelistBundleID else { return }

        whitelistStore.add(bundleID)
        newWhitelistBundleID = ""
        reloadWhitelist()
        onWhitelistAdded(bundleID)
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

    private func reloadWhitelist() {
        whitelistBundleIDs = whitelistStore.allBundleIDs.sorted()
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
                    title: localizer.t("settings.minimumBackgroundTime"),
                    value: $viewModel.minimumBackgroundMinutes,
                    range: 1...240,
                    suffix: "min",
                    isExceeded: false
                )
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
                .padding(.vertical, 14)

                Divider()

                if viewModel.whitelistBundleIDs.isEmpty {
                    Text(localizer.t("menu.noWhitelistItems"))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 14)
                } else {
                    VStack(spacing: 0) {
                        ForEach(viewModel.whitelistBundleIDs, id: \.self) { bundleID in
                            whitelistRow(bundleID)
                            if bundleID != viewModel.whitelistBundleIDs.last {
                                Divider()
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

    private func whitelistRow(_ bundleID: String) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(bundleID)
                    .font(.system(.body, design: .monospaced))
                    .lineLimit(1)
                    .truncationMode(.middle)

                if viewModel.isDefaultWhitelistSeed(bundleID) {
                    Text(localizer.t("settings.defaultWhitelistSeed"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Button {
                viewModel.removeWhitelistBundleID(bundleID)
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .help(localizer.t("menu.removeBundleID", bundleID))
        }
        .padding(.vertical, 10)
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
