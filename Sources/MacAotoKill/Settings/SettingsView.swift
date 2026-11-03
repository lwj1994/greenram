import AppleViewModel
import AppKit
import MacAotoKillCore
import SwiftUI

enum SettingsPage {
    case autoQuit
    case idleTimes
    case memoryLimits
    case whitelist
    case general
}

/// 主窗口里的规则页和设置页。
@MainActor
struct SettingsView: View {
    @WatchViewModel private var viewModel: SettingsViewModel
    private let page: SettingsPage

    init(viewModelSpec: ViewModelSpec<SettingsViewModel>, page: SettingsPage) {
        self._viewModel = WatchViewModel(viewModelSpec)
        self.page = page
    }

    private var state: SettingsState {
        viewModel.state
    }

    private var localizer: Localizer {
        viewModel.localizer
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                pageHeader

                switch page {
                case .autoQuit:
                    autoQuitSection
                case .idleTimes:
                    appIdleTimeSection
                case .memoryLimits:
                    appMemoryLimitSection
                case .whitelist:
                    whitelistSection
                case .general:
                    thresholdSection
                    languageSection
                    updateSection
                    aboutSection
                    logSection
                    resetSection
                }
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 24)
        }
        .onAppear {
            viewModel.load()
            viewModel.refreshMemory()
        }
        .alert(localizer.t("settings.resetConfirmTitle"), isPresented: resetConfirmationBinding) {
            Button(localizer.t("settings.cancel"), role: .cancel) {}
            Button(localizer.t("settings.resetConfirmButton"), role: .destructive) {
                viewModel.resetDefaults()
            }
        } message: {
            Text(localizer.t("settings.resetConfirmMessage"))
        }
        .alert(localizer.t("settings.ruleBlockedByWhitelistTitle"), isPresented: blockedWhitelistedRuleBinding) {
            Button(localizer.t("update.ok"), role: .cancel) {}
        } message: {
            Text(localizer.t("settings.ruleBlockedByWhitelistMessage", state.blockedWhitelistedRuleBundleID ?? ""))
        }
    }

    @ViewBuilder
    private var pageHeader: some View {
        switch page {
        case .autoQuit:
            PageHeader(title: localizer.t("settings.autoQuitApps"), subtitle: localizer.t("settings.autoQuitAppsHint"))
        case .idleTimes:
            PageHeader(title: localizer.t("settings.appIdleTimes"), subtitle: localizer.t("settings.appIdleTimesHint"))
        case .memoryLimits:
            PageHeader(title: localizer.t("settings.appMemoryLimits"), subtitle: localizer.t("settings.appMemoryLimitsHint"))
        case .whitelist:
            PageHeader(title: localizer.t("menu.whitelist"), subtitle: localizer.t("settings.whitelistHint"))
        case .general:
            PageHeader(title: localizer.t("sidebar.settings"), subtitle: nil)
        }
    }

    private var thresholdSection: some View {
        settingsSection(localizer.t("settings.releaseThresholds"), systemImage: "gauge") {
            toggleRow(
                title: localizer.t("settings.swapLimitEnabled"),
                isOn: swapLimitEnabledBinding
            )

            if state.swapLimitEnabled {
                rowDivider
                valueRow(
                    title: localizer.t("settings.swapLimit"),
                    value: swapLimitGBBinding,
                    range: swapLimitGBRange,
                    suffix: "GB",
                    isExceeded: isSwapExceeded
                )
                hintRow(localizer.t("settings.swapMinimumHint"))
            }

            rowDivider
            valueRow(
                title: localizer.t("settings.defaultBackgroundTime"),
                value: minimumBackgroundMinutesBinding,
                range: (MemoryPolicyDefaults.minimumConfigurableBackgroundDuration / 60)...240,
                suffix: "min",
                isExceeded: false
            )
        }
    }

    private var autoQuitSection: some View {
        settingsSection(nil, systemImage: nil) {
            addBundleIDRow(
                text: newAutoQuitBundleIDBinding,
                canAdd: viewModel.canAddAutoQuitBundleID,
                chooseAction: viewModel.chooseAutoQuitApplications,
                addAction: viewModel.addAutoQuitBundleID
            )

            if state.autoQuitItems.isEmpty {
                rowDivider
                emptyRow(localizer.t("settings.noAutoQuitItems"))
            } else {
                ForEach(state.autoQuitItems) { item in
                    rowDivider
                    autoQuitRow(item)
                }
            }
        }
    }

    private var appIdleTimeSection: some View {
        settingsSection(nil, systemImage: nil) {
            addBundleIDRow(
                text: newIdleTimeBundleIDBinding,
                canAdd: viewModel.canAddIdleTimeBundleID,
                chooseAction: viewModel.chooseIdleTimeApplications,
                addAction: viewModel.addIdleTimeBundleID
            )

            if state.appIdleTimeItems.isEmpty {
                rowDivider
                emptyRow(localizer.t("settings.noAppIdleTimeItems"))
            } else {
                ForEach(state.appIdleTimeItems) { item in
                    rowDivider
                    appIdleTimeRow(item)
                }
            }
        }
    }

    private var appMemoryLimitSection: some View {
        settingsSection(nil, systemImage: nil) {
            addBundleIDRow(
                text: newMemoryLimitBundleIDBinding,
                canAdd: viewModel.canAddMemoryLimitBundleID,
                chooseAction: viewModel.chooseMemoryLimitApplications,
                addAction: viewModel.addMemoryLimitBundleID
            )

            if state.appMemoryLimitItems.isEmpty {
                rowDivider
                emptyRow(localizer.t("settings.noAppMemoryLimitItems"))
            } else {
                ForEach(state.appMemoryLimitItems) { item in
                    rowDivider
                    appMemoryLimitRow(item)
                }
            }
        }
    }

    private var whitelistSection: some View {
        settingsSection(nil, systemImage: nil) {
            addBundleIDRow(
                text: newWhitelistBundleIDBinding,
                canAdd: viewModel.canAddWhitelistBundleID,
                chooseAction: viewModel.chooseWhitelistApplications,
                addAction: viewModel.addWhitelistBundleID
            )

            if state.whitelistItems.isEmpty {
                rowDivider
                emptyRow(localizer.t("menu.noWhitelistItems"))
            } else {
                ForEach(state.whitelistItems) { item in
                    rowDivider
                    whitelistRow(item)
                }
            }
        }
    }

    private var languageSection: some View {
        settingsSection(localizer.t("settings.language"), systemImage: "globe") {
            HStack {
                Text(localizer.t("settings.language"))
                Spacer()
                Picker("", selection: languageCodeBinding) {
                    ForEach(AppLanguage.allCases, id: \.storageCode) { language in
                        Text(language.nativeDisplayName).tag(language.storageCode)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .fixedSize()
            }
            .settingsRowPadding()
        }
    }

    private var updateSection: some View {
        settingsSection(localizer.t("settings.updates"), systemImage: "arrow.down.circle") {
            toggleRow(
                title: localizer.t("settings.automaticUpdateReminder"),
                isOn: automaticUpdateReminderEnabledBinding
            )
            hintRow(localizer.t("settings.automaticUpdateReminderHint"))

            rowDivider
            actionRow(
                title: localizer.t("settings.version"),
                detail: state.appVersion,
                buttonTitle: localizer.t("menu.checkForUpdates"),
                action: viewModel.checkForUpdates
            )
        }
    }

    private var aboutSection: some View {
        settingsSection(localizer.t("settings.about"), systemImage: "info.circle") {
            actionRow(
                title: localizer.t("settings.onboarding"),
                detail: localizer.t("settings.onboardingHint"),
                buttonTitle: localizer.t("settings.showOnboarding"),
                action: viewModel.showOnboarding
            )
        }
    }

    private var logSection: some View {
        settingsSection(localizer.t("settings.logs"), systemImage: "doc.text") {
            HStack(spacing: 16) {
                Text(localizer.t("settings.logRetentionHint"))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer()

                Button {
                    viewModel.exportLogs()
                } label: {
                    Label(localizer.t("settings.exportLogs"), systemImage: "square.and.arrow.up")
                }
            }
            .settingsRowPadding()
        }
    }

    private var resetSection: some View {
        HStack {
            Spacer()

            Button(role: .destructive) {
                viewModel.setResetConfirmationPresented(true)
            } label: {
                Label(localizer.t("settings.resetDefaults"), systemImage: "arrow.counterclockwise")
            }
        }
    }

    private var isSwapExceeded: Bool {
        state.swapLimitEnabled && state.memorySnapshot.swapUsedBytes >= swapLimitBytes
    }

    private var swapLimitBytes: UInt64 {
        UInt64(clampedSwapLimitGB * Double(1024 * 1024 * 1024))
    }

    private var swapLimitGBRange: ClosedRange<Double> {
        swapLimitMinimumGB...swapLimitMaximumGB
    }

    private var clampedSwapLimitGB: Double {
        min(swapLimitMaximumGB, max(swapLimitMinimumGB, state.swapLimitGB))
    }

    private var swapLimitMinimumGB: Double {
        Double(MemoryPolicyDefaults.minimumSwapLimitBytes) / Double(1024 * 1024 * 1024)
    }

    private var swapLimitMaximumGB: Double {
        Double(MemoryPolicyDefaults.maximumSwapLimitBytes) / Double(1024 * 1024 * 1024)
    }

    private var languageCodeBinding: Binding<String> {
        stateBinding(
            get: { $0.languageCode },
            set: { viewModel.setLanguageCode($0) },
            save: true
        )
    }

    private var swapLimitEnabledBinding: Binding<Bool> {
        stateBinding(
            get: { $0.swapLimitEnabled },
            set: { viewModel.setSwapLimitEnabled($0) },
            save: true
        )
    }

    private var swapLimitGBBinding: Binding<Double> {
        stateBinding(
            get: { $0.swapLimitGB },
            set: { viewModel.setSwapLimitGB($0) },
            save: true
        )
    }

    private var minimumBackgroundMinutesBinding: Binding<Double> {
        stateBinding(
            get: { $0.minimumBackgroundMinutes },
            set: { viewModel.setMinimumBackgroundMinutes($0) },
            save: true
        )
    }

    private var automaticUpdateReminderEnabledBinding: Binding<Bool> {
        stateBinding(
            get: { $0.automaticUpdateReminderEnabled },
            set: { viewModel.setAutomaticUpdateReminderEnabled($0) },
            save: true
        )
    }

    private var newAutoQuitBundleIDBinding: Binding<String> {
        stateBinding(
            get: { $0.newAutoQuitBundleID },
            set: { viewModel.setNewAutoQuitBundleID($0) }
        )
    }

    private var newIdleTimeBundleIDBinding: Binding<String> {
        stateBinding(
            get: { $0.newIdleTimeBundleID },
            set: { viewModel.setNewIdleTimeBundleID($0) }
        )
    }

    private var newMemoryLimitBundleIDBinding: Binding<String> {
        stateBinding(
            get: { $0.newMemoryLimitBundleID },
            set: { viewModel.setNewMemoryLimitBundleID($0) }
        )
    }

    private var newWhitelistBundleIDBinding: Binding<String> {
        stateBinding(
            get: { $0.newWhitelistBundleID },
            set: { viewModel.setNewWhitelistBundleID($0) }
        )
    }

    private var resetConfirmationBinding: Binding<Bool> {
        stateBinding(
            get: { $0.isResetConfirmationPresented },
            set: { viewModel.setResetConfirmationPresented($0) }
        )
    }

    private var blockedWhitelistedRuleBinding: Binding<Bool> {
        Binding(
            get: {
                viewModel.state.blockedWhitelistedRuleBundleID != nil
            },
            set: { isPresented in
                if !isPresented {
                    viewModel.clearBlockedWhitelistedRuleAlert()
                }
            }
        )
    }

    private func stateBinding<Value>(
        get: @escaping (SettingsState) -> Value,
        set: @escaping (Value) -> Void,
        save: Bool = false
    ) -> Binding<Value> {
        Binding(
            get: {
                get(viewModel.state)
            },
            set: { newValue in
                set(newValue)
                if save {
                    viewModel.save()
                }
            }
        )
    }

    private func settingsSection<Content: View>(
        _ title: String?,
        systemImage: String?,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if let title, let systemImage {
                Label(title, systemImage: systemImage)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.leading, 4)
            }
            VStack(alignment: .leading, spacing: 0) {
                content()
            }
            .card(padding: 0)
        }
    }

    private var rowDivider: some View {
        Divider()
            .padding(.leading, 16)
    }

    private func toggleRow(title: String, isOn: Binding<Bool>) -> some View {
        HStack {
            Text(title)
            Spacer()
            Toggle("", isOn: isOn)
                .labelsHidden()
                .toggleStyle(.switch)
        }
        .settingsRowPadding()
    }

    private func actionRow(
        title: String,
        detail: String,
        buttonTitle: String,
        action: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button(buttonTitle, action: action)
        }
        .settingsRowPadding()
    }

    private func valueRow(
        title: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        suffix: String,
        isExceeded: Bool
    ) -> some View {
        HStack(spacing: 10) {
            Text(title)

            Spacer(minLength: 16)

            Slider(value: value, in: range)
                .tint(statusColor(isExceeded))
                .frame(minWidth: 200, maxWidth: 320)

            TextField("", value: value, format: .number.precision(.fractionLength(0...1)))
                .labelsHidden()
                .multilineTextAlignment(.trailing)
                .font(.system(.body, design: .rounded).weight(.semibold))
                .textFieldStyle(.roundedBorder)
                .frame(width: 76)

            Text(suffix)
                .foregroundStyle(.secondary)
                .frame(width: 30, alignment: .leading)
        }
        .settingsRowPadding()
    }

    private func hintRow(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 16)
            .padding(.top, -4)
            .padding(.bottom, 12)
    }

    private func emptyRow(_ text: String) -> some View {
        Text(text)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .settingsRowPadding()
    }

    private func addBundleIDRow(
        text: Binding<String>,
        canAdd: Bool,
        chooseAction: @escaping () -> Void,
        addAction: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 10) {
            Button(action: chooseAction) {
                Label(localizer.t("settings.chooseApp"), systemImage: "folder")
            }

            TextField("", text: text, prompt: Text(localizer.t("settings.bundleIDPlaceholder")))
                .labelsHidden()
                .textFieldStyle(.roundedBorder)
                .font(.system(.body, design: .monospaced))
                .onSubmit(addAction)

            Button(action: addAction) {
                Label(localizer.t("settings.addBundleID"), systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
            .tint(Palette.brand)
            .disabled(!canAdd)
        }
        .settingsRowPadding()
    }

    private func autoQuitRow(_ item: AutoQuitAppInfo) -> some View {
        HStack(spacing: 12) {
            appIcon(item.icon)

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

            removeButton {
                viewModel.removeAutoQuitBundleID(item.bundleID)
            }
            .help(localizer.t("settings.removeAutoQuitApp", item.bundleID))
        }
        .settingsRowPadding(vertical: 8)
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
        HStack(spacing: 12) {
            appIcon(item.icon)

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
                .textFieldStyle(.roundedBorder)
                .frame(width: 76)

            Text("min")
                .foregroundStyle(.secondary)
                .frame(width: 30, alignment: .leading)

            removeButton {
                viewModel.removeIdleTimeBundleID(item.bundleID)
            }
            .help(localizer.t("settings.removeAppIdleTime", item.bundleID))
        }
        .settingsRowPadding(vertical: 8)
    }

    private func appMemoryLimitBinding(for bundleID: String) -> Binding<Double> {
        Binding(
            get: {
                viewModel.memoryLimitGB(for: bundleID)
            },
            set: { newValue in
                viewModel.setMemoryLimitGB(newValue, for: bundleID)
            }
        )
    }

    private func appMemoryLimitRow(_ item: MemoryLimitAppInfo) -> some View {
        HStack(spacing: 12) {
            appIcon(item.icon)

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

            TextField("", value: appMemoryLimitBinding(for: item.bundleID), format: .number.precision(.fractionLength(0...1)))
                .multilineTextAlignment(.trailing)
                .font(.system(.body, design: .rounded).weight(.semibold))
                .textFieldStyle(.roundedBorder)
                .frame(width: 76)

            Text("GB")
                .foregroundStyle(.secondary)
                .frame(width: 30, alignment: .leading)

            removeButton {
                viewModel.removeMemoryLimitBundleID(item.bundleID)
            }
            .help(localizer.t("settings.removeAppMemoryLimit", item.bundleID))
        }
        .settingsRowPadding(vertical: 8)
    }

    private func whitelistRow(_ item: WhitelistAppInfo) -> some View {
        HStack(spacing: 12) {
            appIcon(item.icon)

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

            removeButton {
                viewModel.removeWhitelistBundleID(item.bundleID)
            }
            .help(localizer.t("menu.removeBundleID", item.bundleID))
        }
        .settingsRowPadding(vertical: 8)
    }

    private func appIcon(_ icon: NSImage) -> some View {
        Image(nsImage: icon)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 32, height: 32)
    }

    private func removeButton(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: "trash")
                .foregroundStyle(Palette.critical)
        }
        .buttonStyle(.borderless)
    }

    private func statusColor(_ isExceeded: Bool) -> Color {
        isExceeded ? Palette.critical : Palette.brand
    }
}

private extension View {
    func settingsRowPadding(vertical: CGFloat = 11) -> some View {
        padding(.horizontal, 16)
            .padding(.vertical, vertical)
    }
}
