import AppleViewModel
import AppKit
import MacAotoKillCore
import SwiftUI

@MainActor
struct SettingsView: View {
    @WatchViewModel private var viewModel: SettingsViewModel

    init(viewModelSpec: ViewModelSpec<SettingsViewModel>) {
        self._viewModel = WatchViewModel(viewModelSpec)
    }

    private var state: SettingsState {
        viewModel.state
    }

    private var localizer: Localizer {
        viewModel.localizer
    }

    var body: some View {
        NavigationStack {
            Form {
                memorySection
                thresholdSection
                rulesSummarySection
                languageSection
                updateSection
                logSection
                resetSection
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            .background(Color(nsColor: .windowBackgroundColor))
            .navigationTitle(localizer.t("settings.title"))
        }
        .frame(minWidth: 700, minHeight: 580)
        .onAppear {
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
    }

    private var rulesPage: some View {
        Form {
            Section {
                Text(localizer.t("settings.rulesPageHint"))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.vertical, 4)
            }

            appIdleTimeSection
            whitelistSection
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .background(Color(nsColor: .windowBackgroundColor))
        .frame(minWidth: 700, minHeight: 580)
        .navigationTitle(localizer.t("settings.rules"))
    }

    private var memorySection: some View {
        Section {
            HStack(spacing: 18) {
                MemoryMetricSummaryView(
                    metric: MemoryMetricDisplays.ram(
                        snapshot: state.memorySnapshot,
                        ramLimitPercent: state.ramLimitPercent,
                        localizer: localizer
                    )
                )

                Divider()

                MemoryMetricSummaryView(
                    metric: MemoryMetricDisplays.swap(
                        snapshot: state.memorySnapshot,
                        swapLimitEnabled: state.swapLimitEnabled,
                        swapLimitBytes: swapLimitBytes,
                        localizer: localizer
                    )
                )
            }
            .padding(.vertical, 6)
        } header: {
            sectionHeader(localizer.t("settings.currentMemory"), systemImage: "memorychip")
        }
    }

    private var thresholdSection: some View {
        Section {
            toggleRow(
                title: localizer.t("settings.swapLimitEnabled"),
                isOn: swapLimitEnabledBinding
            )

            if state.swapLimitEnabled {
                valueRow(
                    title: localizer.t("settings.swapLimit"),
                    value: swapLimitGBBinding,
                    range: swapLimitGBRange,
                    suffix: "GB",
                    isExceeded: isSwapExceeded
                )

                hintRow(localizer.t("settings.swapMinimumHint"))
            }
        } header: {
            sectionHeader(localizer.t("settings.releaseThresholds"), systemImage: "gauge")
        }
    }

    private var rulesSummarySection: some View {
        Section {
            NavigationLink {
                rulesPage
            } label: {
                HStack(spacing: 12) {
                    glassIcon("slider.horizontal.3", color: Color(nsColor: .systemPurple))

                    VStack(alignment: .leading, spacing: 3) {
                        Text(localizer.t("settings.manageRules"))
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.primary)

                        Text(localizer.t("settings.rulesSummary", state.appIdleTimeItems.count, state.whitelistItems.count))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()
                }
                .padding(.vertical, 5)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        } header: {
            sectionHeader(localizer.t("settings.rules"), systemImage: "slider.horizontal.3")
        }
    }

    private var appIdleTimeSection: some View {
        Section {
            hintRow(localizer.t("settings.appIdleTimesHint"))

            valueRow(
                title: localizer.t("settings.defaultBackgroundTime"),
                value: minimumBackgroundMinutesBinding,
                range: (MemoryPolicyDefaults.minimumConfigurableBackgroundDuration / 60)...240,
                suffix: "min",
                isExceeded: false
            )

            addBundleIDRow(
                text: newIdleTimeBundleIDBinding,
                canAdd: viewModel.canAddIdleTimeBundleID,
                chooseAction: viewModel.chooseIdleTimeApplications,
                addAction: viewModel.addIdleTimeBundleID
            )

            if state.appIdleTimeItems.isEmpty {
                emptyRow(localizer.t("settings.noAppIdleTimeItems"))
            } else {
                ForEach(state.appIdleTimeItems) { item in
                    appIdleTimeRow(item)
                }
            }
        } header: {
            sectionHeader(localizer.t("settings.appIdleTimes"), systemImage: "timer")
        }
    }

    private var languageSection: some View {
        Section {
            LabeledContent {
                Picker("", selection: languageCodeBinding) {
                    ForEach(AppLanguage.allCases, id: \.storageCode) { language in
                        Text(language.nativeDisplayName).tag(language.storageCode)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .frame(maxWidth: 260, alignment: .trailing)
            } label: {
                Text(localizer.t("settings.language"))
            }
        } header: {
            sectionHeader(localizer.t("settings.language"), systemImage: "globe")
        }
    }

    private var updateSection: some View {
        Section {
            toggleRow(
                title: localizer.t("settings.automaticUpdateReminder"),
                isOn: automaticUpdateReminderEnabledBinding
            )

            hintRow(localizer.t("settings.automaticUpdateReminderHint"))
        } header: {
            sectionHeader(localizer.t("settings.updates"), systemImage: "arrow.down.circle")
        }
    }

    private var whitelistSection: some View {
        Section {
            addBundleIDRow(
                text: newWhitelistBundleIDBinding,
                canAdd: viewModel.canAddWhitelistBundleID,
                chooseAction: viewModel.chooseWhitelistApplications,
                addAction: viewModel.addWhitelistBundleID
            )

            if state.whitelistItems.isEmpty {
                emptyRow(localizer.t("menu.noWhitelistItems"))
            } else {
                ForEach(state.whitelistItems) { item in
                    whitelistRow(item)
                }
            }
        } header: {
            sectionHeader(localizer.t("menu.whitelist"), systemImage: "checkmark.shield")
        }
    }

    private var logSection: some View {
        Section {
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
                .buttonStyle(SettingsGlassButtonStyle(tint: Color(nsColor: .systemGray), isProminent: false))
            }
            .padding(.vertical, 4)
        } header: {
            sectionHeader(localizer.t("settings.logs"), systemImage: "doc.text")
        }
    }

    private var resetSection: some View {
        Section {
            HStack {
                Spacer()

                Button {
                    viewModel.setResetConfirmationPresented(true)
                } label: {
                    Label(localizer.t("settings.resetDefaults"), systemImage: "arrow.counterclockwise")
                }
                .buttonStyle(SettingsGlassButtonStyle(tint: Color(nsColor: .systemRed), isProminent: false))
            }
            .padding(.vertical, 4)
        }
    }

    private var isRamExceeded: Bool {
        state.memorySnapshot.usedPhysicalPercent >= state.ramLimitPercent
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

    private var newIdleTimeBundleIDBinding: Binding<String> {
        stateBinding(
            get: { $0.newIdleTimeBundleID },
            set: { viewModel.setNewIdleTimeBundleID($0) }
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

    private func sectionHeader(_ title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(.headline)
            .foregroundStyle(.secondary)
    }

    private func toggleRow(title: String, isOn: Binding<Bool>) -> some View {
        LabeledContent {
            Toggle("", isOn: isOn)
                .labelsHidden()
                .toggleStyle(.switch)
        } label: {
            Text(title)
        }
        .padding(.vertical, 2)
    }

    private func valueRow(
        title: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        suffix: String,
        isExceeded: Bool
    ) -> some View {
        LabeledContent {
            HStack(spacing: 10) {
                Slider(value: value, in: range)
                    .tint(statusColor(isExceeded))
                    .frame(minWidth: 220, maxWidth: 340)

                TextField("", value: value, format: .number.precision(.fractionLength(0...1)))
                    .multilineTextAlignment(.trailing)
                    .font(.system(.body, design: .rounded).weight(.semibold))
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 76)

                Text(suffix)
                    .foregroundStyle(.secondary)
                    .frame(width: 30, alignment: .leading)
            }
        } label: {
            Text(title)
        }
        .padding(.vertical, 2)
    }

    private func hintRow(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.vertical, 3)
    }

    private func emptyRow(_ text: String) -> some View {
        Text(text)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 4)
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
            .buttonStyle(SettingsGlassButtonStyle(tint: Color(nsColor: .systemBlue), isProminent: false))

            TextField(localizer.t("settings.bundleIDPlaceholder"), text: text)
                .textFieldStyle(.roundedBorder)
                .font(.system(.body, design: .monospaced))
                .onSubmit(addAction)

            Button(action: addAction) {
                Label(localizer.t("settings.addBundleID"), systemImage: "plus")
            }
            .buttonStyle(SettingsGlassButtonStyle(tint: Color(nsColor: .systemGreen), isProminent: true))
            .disabled(!canAdd)
        }
        .padding(.vertical, 3)
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
        .padding(.vertical, 4)
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
        .padding(.vertical, 4)
    }

    private func appIcon(_ icon: NSImage) -> some View {
        Image(nsImage: icon)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 34, height: 34)
            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
    }

    private func glassIcon(_ systemImage: String, color: Color) -> some View {
        Image(systemName: systemImage)
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(color)
            .frame(width: 34, height: 34)
            .background {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(.regularMaterial)
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(color.opacity(0.12))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(color.opacity(0.20), lineWidth: 1)
            }
    }

    private func removeButton(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: "trash")
        }
        .buttonStyle(SettingsGlassButtonStyle(tint: Color(nsColor: .systemRed), isProminent: false, isIconOnly: true))
    }

    private func statusColor(_ isExceeded: Bool) -> Color {
        MemoryMetricColor.status(isExceeded)
    }
}

private struct SettingsGlassButtonStyle: ButtonStyle {
    let tint: Color
    let isProminent: Bool
    var isIconOnly = false

    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(isProminent ? .semibold : .medium))
            .foregroundStyle(isProminent ? tint : Color.primary)
            .labelStyle(.titleAndIcon)
            .frame(width: isIconOnly ? 32 : nil)
            .frame(minHeight: 32)
            .padding(.horizontal, isIconOnly ? 0 : 12)
            .background {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(.regularMaterial)
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(tint.opacity(isProminent ? 0.20 : 0.06))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(tint.opacity(isProminent ? 0.34 : 0.18), lineWidth: 1)
            }
            .opacity(isEnabled ? (configuration.isPressed ? 0.72 : 1) : 0.45)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
