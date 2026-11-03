import Darwin
import Foundation

/// 闲置子进程清理：只杀 App 进程树里闲置的外部子进程（CLI 工具、语言服务器、MCP server 等），不退出 App。
///
/// 外部进程：可执行文件不在任何 `.app` bundle 内，且不挂在终端上。App 自己的 helper（Electron、WebKit 等）
/// 和终端里的交互任务都不碰。
///
/// 清理单位是"子进程组"：父进程不是外部进程的那个外部进程，连同它的全部子孙。整组都是外部进程、都闲置、
/// 合计内存达到下限才清理，且只整组杀。只杀组内某个深层进程不安全：例如只杀 dart analyzer，
/// `dart mcp-server` 不会重启它，之后 analyze_files 会静默返回 "No errors"；整组杀掉后由上层（如 Claude Code）按需重启。
public struct IdleChildProcessPolicy: Equatable {
    public var idleDuration: TimeInterval
    /// 在 idleDuration 内 CPU 时间增长达到这个值就算活动。闲置的语言服务器每小时约增长 1 秒。
    public var activeCPUTime: TimeInterval
    public var minimumMemoryBytes: UInt64

    public init(
        idleDuration: TimeInterval = 30 * 60,
        activeCPUTime: TimeInterval = 3,
        minimumMemoryBytes: UInt64 = 100 * 1024 * 1024
    ) {
        self.idleDuration = idleDuration
        self.activeCPUTime = activeCPUTime
        self.minimumMemoryBytes = minimumMemoryBytes
    }
}

public struct IdleChildProcessGroup: Equatable {
    public let appDisplayName: String
    /// 组根在前，其余按先序遍历。
    public let entries: [ProcessTreeEntry]
    public let idleDuration: TimeInterval

    public var memoryBytes: UInt64 {
        entries.reduce(0) { $0 + $1.memoryBytes }
    }
}

public protocol ProcessGroupTerminating: AnyObject {
    /// 返回是否至少向一个进程成功发出了信号。
    func terminate(_ entries: [ProcessTreeEntry]) -> Bool
}

public final class ProcessGroupTerminator: ProcessGroupTerminating {
    private let forceGracePeriod: TimeInterval

    public init(forceGracePeriod: TimeInterval = 5) {
        self.forceGracePeriod = forceGracePeriod
    }

    public func terminate(_ entries: [ProcessTreeEntry]) -> Bool {
        var didSignal = false
        for entry in entries where ProcessTreeSnapshot.isRunning(entry) {
            if kill(entry.pid, SIGTERM) == 0 {
                didSignal = true
            }
        }
        guard didSignal else { return false }

        DispatchQueue.main.asyncAfter(deadline: .now() + forceGracePeriod) {
            for entry in entries where ProcessTreeSnapshot.isRunning(entry) {
                kill(entry.pid, SIGKILL)
            }
        }
        return true
    }
}

public final class IdleChildProcessReaper {
    private struct ProcessKey: Hashable {
        let pid: pid_t
        let startTime: TimeInterval

        init(_ entry: ProcessTreeEntry) {
            pid = entry.pid
            startTime = entry.startTime
        }
    }

    private struct Activity {
        let cpuTime: TimeInterval
        let activeAt: Date
    }

    public var policy: IdleChildProcessPolicy
    private let terminator: ProcessGroupTerminating
    private weak var logger: EventLogging?
    private let localizerProvider: () -> Localizer
    private let labelProvider: (ProcessTreeEntry) -> String
    private var activities: [ProcessKey: Activity] = [:]
    private var attemptedGroupRoots: Set<ProcessKey> = []

    public init(
        policy: IdleChildProcessPolicy = IdleChildProcessPolicy(),
        terminator: ProcessGroupTerminating,
        logger: EventLogging?,
        localizerProvider: @escaping () -> Localizer = { Localizer() },
        labelProvider: @escaping (ProcessTreeEntry) -> String
    ) {
        self.policy = policy
        self.terminator = terminator
        self.logger = logger
        self.localizerProvider = localizerProvider
        self.labelProvider = labelProvider
    }

    /// 记录每个进程最近一次 CPU 活动的时间。需要每轮采样调用。
    public func observe(_ tree: ProcessTreeSnapshot, now: Date = Date()) {
        var nextActivities: [ProcessKey: Activity] = [:]
        for entry in tree.entries {
            guard let cpuTime = entry.cpuTime else { continue }
            let key = ProcessKey(entry)
            if let previous = activities[key], cpuTime - previous.cpuTime < policy.activeCPUTime {
                nextActivities[key] = previous
            } else {
                nextActivities[key] = Activity(cpuTime: cpuTime, activeAt: now)
            }
        }
        activities = nextActivities
        attemptedGroupRoots = attemptedGroupRoots.filter { nextActivities[$0] != nil }
    }

    /// 当前满足清理条件的子进程组。前台 App 和 GreenRAM 自己的进程树不参与；白名单不影响子进程清理。
    public func idleGroups(
        in tree: ProcessTreeSnapshot,
        apps: [AppRuntimeState],
        now: Date = Date()
    ) -> [IdleChildProcessGroup] {
        apps
            .filter { app in
                !app.isFrontmost
                    && app.pid != ProcessInfo.processInfo.processIdentifier
                    && !AppIdentity.isOwnBundleIdentifier(app.bundleID)
            }
            .flatMap { app in
                groupRoots(below: app.pid, in: tree).compactMap { rootPID in
                    idleGroup(rootPID: rootPID, appDisplayName: app.displayName, tree: tree, now: now)
                }
            }
            .sorted { $0.memoryBytes > $1.memoryBytes }
    }

    @discardableResult
    public func reap(
        _ tree: ProcessTreeSnapshot,
        apps: [AppRuntimeState],
        now: Date = Date()
    ) -> [IdleChildProcessGroup] {
        observe(tree, now: now)

        let groups = idleGroups(in: tree, apps: apps, now: now)
            .filter { !attemptedGroupRoots.contains(ProcessKey($0.entries[0])) }

        for group in groups {
            attemptedGroupRoots.insert(ProcessKey(group.entries[0]))
            let didTerminate = terminator.terminate(group.entries)
            logger?.append(message(for: group, didTerminate: didTerminate))
        }
        return groups
    }

    static func isExternal(_ entry: ProcessTreeEntry) -> Bool {
        guard let executablePath = entry.executablePath, entry.cpuTime != nil else { return false }
        return !entry.hasControllingTerminal && !executablePath.contains(".app/")
    }

    private func groupRoots(below appPID: pid_t, in tree: ProcessTreeSnapshot) -> [pid_t] {
        var roots: [pid_t] = []
        var visited: Set<pid_t> = [appPID]
        var stack = tree.childPIDs(of: appPID)

        while let pid = stack.popLast() {
            guard visited.insert(pid).inserted, let entry = tree.entry(for: pid) else { continue }
            if Self.isExternal(entry) {
                roots.append(pid)
            } else {
                stack.append(contentsOf: tree.childPIDs(of: pid))
            }
        }
        return roots
    }

    private func idleGroup(
        rootPID: pid_t,
        appDisplayName: String,
        tree: ProcessTreeSnapshot,
        now: Date
    ) -> IdleChildProcessGroup? {
        guard let root = tree.entry(for: rootPID) else { return nil }
        let entries = [root] + tree.descendants(of: rootPID)

        // GreenRAM 从终端或其他 App 启动时，自己也可能落在某个子进程组里。
        let ownPID = ProcessInfo.processInfo.processIdentifier
        var idleDuration = TimeInterval.infinity
        for entry in entries {
            guard entry.pid != ownPID, Self.isExternal(entry), let activity = activities[ProcessKey(entry)] else {
                return nil
            }
            idleDuration = min(idleDuration, now.timeIntervalSince(activity.activeAt))
        }

        let group = IdleChildProcessGroup(appDisplayName: appDisplayName, entries: entries, idleDuration: idleDuration)
        guard idleDuration >= policy.idleDuration, group.memoryBytes >= policy.minimumMemoryBytes else { return nil }
        return group
    }

    private func message(for group: IdleChildProcessGroup, didTerminate: Bool) -> String {
        let localizer = localizerProvider()
        let processes = group.entries
            .map { "\(labelProvider($0))[\($0.pid)]" }
            .joined(separator: ", ")

        guard didTerminate else {
            return localizer.t("event.idleChildProcessesTerminateFailed", group.appDisplayName, processes)
        }
        return localizer.t(
            "event.idleChildProcessesTerminated",
            group.appDisplayName,
            group.entries.count,
            ByteFormatter.memory(group.memoryBytes),
            DurationFormatter.idle(group.idleDuration, localizer: localizer),
            processes
        )
    }
}

/// App 名下的子进程按命令名归并，用于菜单里的归属展示。
public struct ChildProcessSummary: Equatable {
    public let label: String
    public let processCount: Int
    public let memoryBytes: UInt64
    public let cleanableCount: Int

    public init(label: String, processCount: Int, memoryBytes: UInt64, cleanableCount: Int) {
        self.label = label
        self.processCount = processCount
        self.memoryBytes = memoryBytes
        self.cleanableCount = cleanableCount
    }

    public static func summaries(
        appPID: pid_t,
        in tree: ProcessTreeSnapshot,
        cleanablePIDs: Set<pid_t>,
        label: (ProcessTreeEntry) -> String
    ) -> [ChildProcessSummary] {
        var summariesByLabel: [String: ChildProcessSummary] = [:]
        for entry in tree.descendants(of: appPID) {
            let key = label(entry)
            let current = summariesByLabel[key]
            summariesByLabel[key] = ChildProcessSummary(
                label: key,
                processCount: (current?.processCount ?? 0) + 1,
                memoryBytes: (current?.memoryBytes ?? 0) + entry.memoryBytes,
                cleanableCount: (current?.cleanableCount ?? 0) + (cleanablePIDs.contains(entry.pid) ? 1 : 0)
            )
        }

        return summariesByLabel.values.sorted { lhs, rhs in
            lhs.memoryBytes == rhs.memoryBytes ? lhs.label < rhs.label : lhs.memoryBytes > rhs.memoryBytes
        }
    }
}
