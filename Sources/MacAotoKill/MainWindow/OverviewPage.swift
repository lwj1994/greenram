import AppleViewModel
import MacAotoKillCore
import SwiftUI

@MainActor
struct OverviewPage: View {
    @WatchViewModel private var viewModel: DashboardViewModel

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
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                PageHeader(
                    title: localizer.t("sidebar.overview"),
                    subtitle: localizer.t("overview.subtitle", state.apps.count, Self.timeString(state.memory.capturedAt))
                ) {
                    HStack(spacing: 10) {
                        MemoryStatusPill(isExceeded: state.isExceeded, localizer: localizer)
                        CleanNowButton(viewModel: viewModel, localizer: localizer)
                    }
                }

                statTiles
                compositionCard
                treemapCard
                SystemProcessesCard(viewModel: viewModel, localizer: localizer)
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 24)
        }
    }

    private var statTiles: some View {
        let cleanableApps = state.cleanableApps
        return HStack(spacing: 12) {
            MetricTile(metric: MemoryMetrics.ram(state))
            MetricTile(metric: MemoryMetrics.swap(state))
            CountTile(
                title: localizer.t("dashboard.candidates"),
                systemImage: "sparkles",
                tint: Palette.serious,
                value: "\(cleanableApps.count)",
                detail: cleanableApps.isEmpty
                    ? localizer.t("overview.noCleanableApps")
                    : localizer.t("overview.totalMemory", ByteFormatter.memory(cleanableApps.reduce(0) { $0 + $1.memoryBytes }))
            )
            CountTile(
                title: localizer.t("overview.idleChildProcesses"),
                systemImage: "terminal",
                tint: Palette.autoQuit,
                value: "\(state.idleChildGroupCount)",
                detail: state.idleChildGroupCount == 0
                    ? localizer.t("overview.noIdleChildProcesses")
                    : localizer.t("overview.totalMemory", ByteFormatter.memory(state.idleChildMemoryBytes))
            )
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private var compositionCard: some View {
        let segments = MemoryComposition.segments(state.memory, localizer: localizer)
        return VStack(alignment: .leading, spacing: 14) {
            CardTitle(
                title: localizer.t("overview.composition"),
                subtitle: localizer.t("overview.compositionHint", ByteFormatter.memory(state.memory.totalPhysicalBytes))
            )
            MemoryCompositionBar(segments: segments)
            MemoryCompositionLegend(segments: segments, totalBytes: state.memory.totalPhysicalBytes)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(padding: 18)
    }

    private var treemapCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                CardTitle(
                    title: localizer.t("overview.treemap"),
                    subtitle: localizer.t("overview.treemapHint", state.apps.count, ByteFormatter.memory(state.totalAppMemoryBytes))
                )
                Spacer()
                TreemapLegend(localizer: localizer)
            }

            MemoryTreemapView(
                apps: state.apps,
                localizer: localizer,
                onSelect: { app in
                    if let app {
                        viewModel.focusApp(app.pid)
                    } else {
                        viewModel.select(.apps)
                    }
                },
                contextMenu: { app in
                    AnyView(AppRuleMenuItems(app: app, viewModel: viewModel, localizer: localizer))
                }
            )
            .frame(height: 420)
        }
        .card(padding: 18)
    }

    static func timeString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }
}

struct CleanNowButton: View {
    let viewModel: DashboardViewModel
    let localizer: Localizer

    var body: some View {
        Button {
            viewModel.cleanAppsNow()
        } label: {
            Label(localizer.t("menu.releaseNow"), systemImage: "sparkles")
        }
        .buttonStyle(.borderedProminent)
        .tint(Palette.brand)
        .help(localizer.t("overview.cleanNowHint"))
    }
}

/// 白名单 / Auto-Quit / 强制退出快捷操作，用于应用行的菜单和树图的右键菜单。
struct AppRuleMenuItems: View {
    let app: DashboardApp
    let viewModel: DashboardViewModel
    let localizer: Localizer

    var body: some View {
        if app.isOwnApp {
            Text(localizer.t("apps.ownApp"))
        } else {
            if app.isWhitelisted {
                Button(localizer.t("menu.removeAppFromWhitelist", app.displayName)) {
                    viewModel.setWhitelisted(false, bundleID: app.bundleID)
                }
            } else {
                Button(localizer.t("menu.whitelistApp", app.displayName)) {
                    viewModel.setWhitelisted(true, bundleID: app.bundleID)
                }
            }

            if app.isAutoQuit {
                Button(localizer.t("apps.removeAutoQuit")) {
                    viewModel.setAutoQuit(false, bundleID: app.bundleID)
                }
            } else {
                Button(localizer.t("apps.addAutoQuit")) {
                    viewModel.setAutoQuit(true, bundleID: app.bundleID)
                }
                .disabled(app.isWhitelisted)
            }

            Divider()

            Button(localizer.t("apps.forceQuit", app.displayName), role: .destructive) {
                viewModel.forceQuit(app)
            }
        }
    }
}

private struct MetricTile: View {
    let metric: MemoryMetric

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            TileHeader(title: metric.title, systemImage: metric.systemImage, tint: metric.color)

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(metric.value)
                    .font(.system(size: 24, weight: .semibold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text("/ \(metric.total)")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            MeterBar(progress: metric.progress, color: metric.color)

            Text(metric.detail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .card()
    }
}

private struct CountTile: View {
    let title: String
    let systemImage: String
    let tint: Color
    let value: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            TileHeader(title: title, systemImage: systemImage, tint: tint)

            Text(value)
                .font(.system(size: 24, weight: .semibold, design: .rounded))

            Spacer(minLength: 0)

            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .card()
    }
}

private struct TileHeader: View {
    let title: String
    let systemImage: String
    let tint: Color

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(tint)
            Text(title)
                .font(.callout.weight(.medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }
}
