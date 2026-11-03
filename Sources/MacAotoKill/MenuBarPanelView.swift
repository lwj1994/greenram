import AppleViewModel
import MacAotoKillCore
import SwiftUI

/// 点击菜单栏叶子弹出的面板：内存状态、占用最高的 App、常用操作。
@MainActor
struct MenuBarPanelView: View {
    @WatchViewModel private var viewModel: DashboardViewModel

    private let topAppLimit = 5

    init(viewModelSpec: ViewModelSpec<DashboardViewModel>) {
        self._viewModel = WatchViewModel(viewModelSpec)
    }

    private var state: DashboardState {
        viewModel.state
    }

    private var localizer: Localizer {
        state.localizer
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            HStack(spacing: 10) {
                PanelMetric(metric: MemoryMetrics.ram(state))
                PanelMetric(metric: MemoryMetrics.swap(state))
            }

            topApps

            if let frontmostApp = state.frontmostApp {
                frontmostAppRow(frontmostApp)
            }

            actions

            Divider()

            footer
        }
        .padding(16)
        .frame(width: 360)
    }

    private var header: some View {
        HStack(spacing: 8) {
            LeafMark(color: state.isExceeded ? Palette.critical : Palette.brand, size: 20)
            Text(AppIdentity.name)
                .font(.system(size: 15, weight: .semibold))
            MemoryStatusPill(isExceeded: state.isExceeded, localizer: localizer)
            Spacer()
            PanelIconButton(systemImage: "macwindow", help: localizer.t("panel.openMainWindow")) {
                viewModel.openMainWindow(page: .overview)
            }
            PanelIconButton(systemImage: "gearshape", help: localizer.t("menu.settings")) {
                viewModel.openMainWindow(page: .settings)
            }
        }
    }

    private var topApps: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(localizer.t("panel.topApps"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    viewModel.openMainWindow(page: .apps)
                } label: {
                    HStack(spacing: 2) {
                        Text(localizer.t("panel.allApps", state.apps.count))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 9, weight: .semibold))
                    }
                    .font(.caption)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
            .padding(.bottom, 2)

            ForEach(state.apps.prefix(topAppLimit)) { app in
                PanelAppRow(app: app, localizer: localizer) {
                    viewModel.focusApp(app.pid)
                    viewModel.openMainWindow(page: nil)
                }
            }

            Text(localizer.t("panel.summary", state.cleanableApps.count, state.idleChildGroupCount))
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 4)
        }
    }

    private func frontmostAppRow(_ app: FrontmostAppInfo) -> some View {
        HStack(spacing: 8) {
            AppIconView(bundleID: app.bundleID, size: 20)
            VStack(alignment: .leading, spacing: 1) {
                Text(localizer.t("menu.frontmost"))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(app.displayName)
                    .font(.callout.weight(.medium))
                    .lineLimit(1)
            }
            Spacer()
            Toggle(
                localizer.t("menu.whitelist"),
                isOn: Binding(
                    get: { app.isWhitelisted },
                    set: { viewModel.setWhitelisted($0, bundleID: app.bundleID) }
                )
            )
            .toggleStyle(.switch)
            .controlSize(.small)
            .font(.caption)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var actions: some View {
        Button {
            viewModel.cleanAppsNow()
        } label: {
            Label(localizer.t("menu.releaseNow"), systemImage: "sparkles")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .tint(Palette.brand)
        .controlSize(.large)
        .help(localizer.t("overview.cleanNowHint"))
    }

    private var footer: some View {
        HStack {
            Button(updateTitle) {
                viewModel.checkForUpdates()
            }
            .disabled(state.isCheckingForUpdates || state.isInstallingUpdate)

            Spacer()

            Button(localizer.t("menu.quit")) {
                viewModel.quit()
            }
            .keyboardShortcut("q")
        }
        .buttonStyle(.plain)
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    private var updateTitle: String {
        if state.isInstallingUpdate {
            return localizer.t("menu.installingUpdate")
        }
        if state.isCheckingForUpdates {
            return localizer.t("menu.checkingForUpdates")
        }
        return localizer.t("menu.checkForUpdates")
    }
}

private struct PanelMetric: View {
    let metric: MemoryMetric

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                Image(systemName: metric.systemImage)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(metric.color)
                Text(metric.title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(metric.value)
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text("/ \(metric.total)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            MeterBar(progress: metric.progress, color: metric.color, height: 5)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

private struct PanelAppRow: View {
    let app: DashboardApp
    let localizer: Localizer
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                AppIconView(bundleID: app.bundleID, pid: app.pid, size: 20)
                Text(app.displayName)
                    .font(.callout)
                    .lineLimit(1)
                if app.status == .cleanable || app.status == .protected {
                    Image(systemName: app.status.systemImage)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(app.status.color)
                        .help(app.status.title(localizer))
                }
                Spacer(minLength: 8)
                Text(ByteFormatter.memory(app.memoryBytes))
                    .font(.system(.callout, design: .rounded))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isHovered ? Color.primary.opacity(0.07) : .clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

private struct PanelIconButton: View {
    let systemImage: String
    let help: String
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 26, height: 26)
                .background(
                    Circle().fill(isHovered ? Color.primary.opacity(0.08) : .clear)
                )
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help(help)
        .onHover { isHovered = $0 }
    }
}
