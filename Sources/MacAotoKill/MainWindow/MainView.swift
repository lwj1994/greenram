import AppleViewModel
import MacAotoKillCore
import SwiftUI

@MainActor
struct MainView: View {
    @WatchViewModel private var dashboard: DashboardViewModel
    @WatchViewModel private var settings: SettingsViewModel
    private let dashboardSpec: ViewModelSpec<DashboardViewModel>
    private let settingsSpec: ViewModelSpec<SettingsViewModel>

    init(
        dashboardSpec: ViewModelSpec<DashboardViewModel>,
        settingsSpec: ViewModelSpec<SettingsViewModel>
    ) {
        self.dashboardSpec = dashboardSpec
        self.settingsSpec = settingsSpec
        self._dashboard = WatchViewModel(dashboardSpec)
        self._settings = WatchViewModel(settingsSpec)
    }

    private var state: DashboardState {
        dashboard.state
    }

    private var localizer: Localizer {
        state.localizer
    }

    var body: some View {
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(min: 210, ideal: 230, max: 280)
        } detail: {
            detail
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(nsColor: .windowBackgroundColor))
        }
        .frame(minWidth: 920, minHeight: 620)
    }

    private var selection: Binding<MainPage?> {
        Binding(
            get: { dashboard.state.page },
            set: { page in
                if let page {
                    dashboard.select(page)
                }
            }
        )
    }

    private var sidebar: some View {
        List(selection: selection) {
            Section(localizer.t("sidebar.monitor")) {
                sidebarRow(.overview, badge: nil)
                sidebarRow(.apps, badge: state.cleanableApps.count)
                sidebarRow(.events, badge: nil)
            }

            Section(localizer.t("settings.rules")) {
                sidebarRow(.autoQuit, badge: settings.state.autoQuitItems.count)
                sidebarRow(.idleTimes, badge: settings.state.appIdleTimeItems.count)
                sidebarRow(.memoryLimits, badge: settings.state.appMemoryLimitItems.count)
                sidebarRow(.whitelist, badge: settings.state.whitelistItems.count)
            }

            Section {
                sidebarRow(.settings, badge: nil)
            }
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            SidebarMemoryFooter(state: state)
        }
    }

    private func sidebarRow(_ page: MainPage, badge: Int?) -> some View {
        Label {
            Text(page.title(localizer))
        } icon: {
            Image(systemName: page.systemImage)
                .foregroundStyle(page.tint)
        }
        .badge(badge ?? 0)
        .tag(page)
    }

    @ViewBuilder
    private var detail: some View {
        switch state.page {
        case .overview:
            OverviewPage(viewModelSpec: dashboardSpec)
        case .apps:
            AppsPage(viewModelSpec: dashboardSpec)
        case .events:
            EventsPage(viewModelSpec: dashboardSpec)
        case .autoQuit:
            SettingsView(viewModelSpec: settingsSpec, page: .autoQuit)
        case .idleTimes:
            SettingsView(viewModelSpec: settingsSpec, page: .idleTimes)
        case .memoryLimits:
            SettingsView(viewModelSpec: settingsSpec, page: .memoryLimits)
        case .whitelist:
            SettingsView(viewModelSpec: settingsSpec, page: .whitelist)
        case .settings:
            SettingsView(viewModelSpec: settingsSpec, page: .general)
        }
    }
}

extension MainPage {
    func title(_ localizer: Localizer) -> String {
        switch self {
        case .overview: return localizer.t("sidebar.overview")
        case .apps: return localizer.t("menu.backgroundApps")
        case .events: return localizer.t("menu.recentEvents")
        case .autoQuit: return localizer.t("settings.autoQuitApps")
        case .idleTimes: return localizer.t("settings.appIdleTimes")
        case .memoryLimits: return localizer.t("settings.appMemoryLimits")
        case .whitelist: return localizer.t("menu.whitelist")
        case .settings: return localizer.t("sidebar.settings")
        }
    }

    var systemImage: String {
        switch self {
        case .overview: return "gauge.medium"
        case .apps: return "square.grid.2x2"
        case .events: return "clock.arrow.circlepath"
        case .autoQuit: return "power.circle"
        case .idleTimes: return "timer"
        case .memoryLimits: return "memorychip"
        case .whitelist: return "checkmark.shield"
        case .settings: return "gearshape"
        }
    }

    var tint: Color {
        switch self {
        case .autoQuit: return Palette.autoQuit
        case .idleTimes: return Palette.idleTime
        case .memoryLimits: return Palette.memoryLimit
        case .whitelist: return Palette.whitelist
        default: return Palette.brand
        }
    }
}

/// 侧栏底部的常驻内存状态。
private struct SidebarMemoryFooter: View {
    let state: DashboardState

    var body: some View {
        let localizer = state.localizer
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                LeafMark(color: state.isExceeded ? Palette.critical : Palette.brand, size: 16)
                Text(AppIdentity.name)
                    .font(.system(size: 12, weight: .semibold))
                Spacer(minLength: 4)
                MemoryStatusPill(isExceeded: state.isExceeded, localizer: localizer)
            }

            footerMeter(
                title: localizer.t("menu.ram"),
                value: PercentFormatter.compact(state.memory.usedPhysicalPercent),
                metric: MemoryMetrics.ram(state)
            )
            footerMeter(
                title: localizer.t("menu.swap"),
                value: ByteFormatter.memory(state.memory.swapUsedBytes),
                metric: MemoryMetrics.swap(state)
            )
        }
        .padding(14)
        .background(.bar)
        .overlay(alignment: .top) {
            Divider()
        }
    }

    private func footerMeter(title: String, value: String, metric: MemoryMetric) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(value)
                    .font(.caption.weight(.medium))
                    .monospacedDigit()
            }
            MeterBar(progress: metric.progress, color: metric.color, height: 4)
        }
    }
}
