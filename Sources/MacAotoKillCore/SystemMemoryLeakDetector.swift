import Darwin
import Foundation

/// 疑似内存泄漏：当前内存达到下限，且在观察窗口内比最低点增长了足够多。
/// 这是启发式判断，不分析进程堆；VM 启动、JVM 扩堆、大型编译也可能满足，所以只自动结束 Apple 系统路径下的进程。
public struct SystemMemoryLeakPolicy: Equatable {
    public var minimumMemoryBytes: UInt64
    public var growthBytes: UInt64
    public var window: TimeInterval
    /// 两个记录点之间的最小间隔，限制历史数据量。
    public var sampleInterval: TimeInterval

    public init(
        minimumMemoryBytes: UInt64 = 4 * 1024 * 1024 * 1024,
        growthBytes: UInt64 = 2 * 1024 * 1024 * 1024,
        window: TimeInterval = 60 * 60,
        sampleInterval: TimeInterval = 60
    ) {
        self.minimumMemoryBytes = minimumMemoryBytes
        self.growthBytes = growthBytes
        self.window = window
        self.sampleInterval = sampleInterval
    }
}

public struct SystemMemoryLeakSuspect: Equatable {
    public let process: SystemProcessUsage
    /// 窗口内相对最低点的增长。
    public let growthBytes: UInt64

    /// Apple 系统路径下的进程：涨到几 GB 基本是 bug，结束后由 launchd 按需重启，自动结束。
    /// 其他进程（开发工具的 JVM、虚拟机、Homebrew 工具等）可能是正常占用，只标记不结束。
    public var isAutoTerminable: Bool {
        guard !process.isProtected, let path = process.entry.executablePath else { return false }
        return SystemMemoryLeakDetector.systemPathPrefixes.contains { path.hasPrefix($0) }
    }
}

public final class SystemMemoryLeakDetector {
    /// 已知会泄漏、正常只占几百 MB 的系统服务：达到内存下限即视为泄漏，不需要增长历史。
    public static let knownLeakyServiceNames: Set<String> = [
        "PerfPowerServicesSignpostReader"
    ]

    public static let systemPathPrefixes = ["/System/", "/usr/libexec/", "/usr/sbin/", "/usr/bin/", "/sbin/", "/bin/"]

    private struct ProcessKey: Hashable {
        let pid: pid_t
        let startTime: TimeInterval

        init(_ entry: ProcessTreeEntry) {
            pid = entry.pid
            startTime = entry.startTime
        }
    }

    private struct Sample {
        let date: Date
        let memoryBytes: UInt64
    }

    public var policy: SystemMemoryLeakPolicy
    private var samples: [ProcessKey: [Sample]] = [:]
    private var handled: Set<ProcessKey> = []

    public init(policy: SystemMemoryLeakPolicy = SystemMemoryLeakPolicy()) {
        self.policy = policy
    }

    /// 记录一次采样。已退出的进程连同历史一起丢弃。
    public func observe(_ summary: SystemProcessSummary) {
        let now = summary.capturedAt
        var next: [ProcessKey: [Sample]] = [:]
        for process in summary.processes {
            let key = ProcessKey(process.entry)
            var history = samples[key] ?? []
            if history.last.map({ now.timeIntervalSince($0.date) >= policy.sampleInterval }) ?? true {
                history.append(Sample(date: now, memoryBytes: process.memoryBytes))
            }
            history.removeAll { now.timeIntervalSince($0.date) > policy.window }
            next[key] = history
        }
        samples = next
        handled = handled.filter { next[$0] != nil }
    }

    /// 当前所有疑似泄漏的进程，按内存降序。关键进程不参与。
    public func suspects(in summary: SystemProcessSummary) -> [SystemMemoryLeakSuspect] {
        summary.processes.compactMap { process in
            guard !process.isProtected, process.memoryBytes >= policy.minimumMemoryBytes else { return nil }
            let lowest = samples[ProcessKey(process.entry)]?.map(\.memoryBytes).min() ?? process.memoryBytes
            let growth = process.memoryBytes > lowest ? process.memoryBytes - lowest : 0
            let isKnownLeaky = Self.knownLeakyServiceNames.contains(process.name)
            guard isKnownLeaky || growth >= policy.growthBytes else { return nil }
            return SystemMemoryLeakSuspect(process: process, growthBytes: growth)
        }
    }

    /// 还没处理过的疑似进程。每个进程（pid + 启动时间）只处理一次，处理后调用 markHandled。
    public func unhandledSuspects(in summary: SystemProcessSummary) -> [SystemMemoryLeakSuspect] {
        suspects(in: summary).filter { !handled.contains(ProcessKey($0.process.entry)) }
    }

    public func markHandled(_ suspect: SystemMemoryLeakSuspect) {
        handled.insert(ProcessKey(suspect.process.entry))
    }
}
