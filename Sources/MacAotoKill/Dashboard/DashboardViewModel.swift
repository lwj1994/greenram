import AppleViewModel
import Darwin
import Foundation
import MacAotoKillCore

enum MainPage: String, CaseIterable, Hashable {
    case overview
    case apps
    case events
    case autoQuit
    case idleTimes
    case memoryLimits
    case whitelist
    case settings
}

struct DashboardApp: Identifiable, Equatable {
    let pid: pid_t
    let bundleID: String
    let displayName: String
    /// 整个进程树的内存，与清理判断口径一致。
    let memoryBytes: UInt64
    let childMemoryBytes: UInt64
    let childProcessCount: Int
    let backgroundDuration: TimeInterval
    let backgroundThreshold: TimeInterval
    let status: AppCleanupStatus
    let isAutoQuit: Bool
    let isWhitelisted: Bool
    let memoryLimitBytes: UInt64?
    let children: [ChildProcessSummary]

    var id: pid_t { pid }

    var isOwnApp: Bool {
        AppIdentity.isOwnBundleIdentifier(bundleID)
    }
}

struct FrontmostAppInfo: Equatable {
    let bundleID: String
    let displayName: String
    let isWhitelisted: Bool
}

struct DashboardState: Equatable {
    var memory: SystemMemorySnapshot
    var isExceeded: Bool
    var ramLimitPercent: Double
    var swapLimitEnabled: Bool
    var swapLimitBytes: UInt64
    var languageCode: String
    var apps: [DashboardApp] = []
    var idleChildGroupCount = 0
    var idleChildMemoryBytes: UInt64 = 0
    var events: [EventLogEntry] = []
    var frontmostApp: FrontmostAppInfo?
    var isCheckingForUpdates = false
    var isInstallingUpdate = false
    var page: MainPage = .overview
    /// 从概览或菜单栏跳到应用页时要定位的 App。
    var focusedAppPID: pid_t?

    var localizer: Localizer {
        Localizer(languageCode: languageCode)
    }

    var cleanableApps: [DashboardApp] {
        apps.filter { $0.status == .cleanable }
    }

    var totalAppMemoryBytes: UInt64 {
        apps.reduce(0) { $0 + $1.memoryBytes }
    }
}

@MainActor
protocol DashboardActions: AnyObject {
    func cleanAppsNow()
    func setWhitelisted(_ isWhitelisted: Bool, bundleID: String)
    func setAutoQuit(_ isAutoQuit: Bool, bundleID: String)
    func forceQuit(pid: pid_t)
    func openMainWindow(page: MainPage?)
    func checkForUpdates()
    func exportLogs()
    func showOnboarding()
    func quit()
}

/// 菜单栏面板和主窗口共用的运行时状态。由 AppCoordinator 写入，界面只读并通过 actions 回调。
@MainActor
final class DashboardViewModel: StateViewModel<DashboardState> {
    weak var actions: DashboardActions?

    init(state: DashboardState) {
        super.init(state: state, equals: ==)
    }

    func update(_ transform: (inout DashboardState) -> Void) {
        var next = state
        transform(&next)
        setState(next)
    }

    func select(_ page: MainPage) {
        update { $0.page = page }
    }

    func focusApp(_ pid: pid_t) {
        update {
            $0.page = .apps
            $0.focusedAppPID = pid
        }
    }

    func clearFocusedApp() {
        update { $0.focusedAppPID = nil }
    }

    func cleanAppsNow() { actions?.cleanAppsNow() }
    func setWhitelisted(_ isWhitelisted: Bool, bundleID: String) { actions?.setWhitelisted(isWhitelisted, bundleID: bundleID) }
    func setAutoQuit(_ isAutoQuit: Bool, bundleID: String) { actions?.setAutoQuit(isAutoQuit, bundleID: bundleID) }
    func forceQuit(_ app: DashboardApp) { actions?.forceQuit(pid: app.pid) }
    func openMainWindow(page: MainPage? = nil) { actions?.openMainWindow(page: page) }
    func checkForUpdates() { actions?.checkForUpdates() }
    func exportLogs() { actions?.exportLogs() }
    func showOnboarding() { actions?.showOnboarding() }
    func quit() { actions?.quit() }
}
