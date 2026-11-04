import Darwin
import Foundation

public struct ProcessTreeEntry: Equatable {
    public let pid: pid_t
    public let parentPID: pid_t
    public let memoryBytes: UInt64
    public let name: String
    public let executablePath: String?
    /// 累计 CPU 时间（用户态 + 内核态，秒）。读不到 rusage（如其他用户的进程）时为 nil。
    public let cpuTime: TimeInterval?
    /// 进程启动时间（Unix 时间戳），与 pid 一起标识进程，避免 pid 复用误判。
    public let startTime: TimeInterval
    public let hasControllingTerminal: Bool
    /// 有效用户 ID。0 是 root。
    public let userID: uid_t

    public init(
        pid: pid_t,
        parentPID: pid_t,
        memoryBytes: UInt64,
        name: String = "",
        executablePath: String? = nil,
        cpuTime: TimeInterval? = nil,
        startTime: TimeInterval = 0,
        hasControllingTerminal: Bool = false,
        userID: uid_t = getuid()
    ) {
        self.pid = pid
        self.parentPID = parentPID
        self.memoryBytes = memoryBytes
        self.name = name
        self.executablePath = executablePath
        self.cpuTime = cpuTime
        self.startTime = startTime
        self.hasControllingTerminal = hasControllingTerminal
        self.userID = userID
    }

    public init(pid: pid_t, parentPID: pid_t, residentMemoryBytes: UInt64) {
        self.init(pid: pid, parentPID: parentPID, memoryBytes: residentMemoryBytes)
    }
}

public struct ProcessTreeSnapshot: Equatable {
    private let entriesByPID: [pid_t: ProcessTreeEntry]
    private let childrenByParentPID: [pid_t: [pid_t]]

    public init(entries: [ProcessTreeEntry]) {
        self.entriesByPID = Dictionary(uniqueKeysWithValues: entries.map { ($0.pid, $0) })

        var children: [pid_t: [pid_t]] = [:]
        for entry in entries where entry.parentPID > 0 {
            children[entry.parentPID, default: []].append(entry.pid)
        }
        self.childrenByParentPID = children.mapValues { $0.sorted() }
    }

    public static func capture() -> ProcessTreeSnapshot {
        ProcessTreeSnapshot(entries: allProcesses())
    }

    public var entries: [ProcessTreeEntry] {
        Array(entriesByPID.values)
    }

    public func entry(for pid: pid_t) -> ProcessTreeEntry? {
        entriesByPID[pid]
    }

    public func childPIDs(of pid: pid_t) -> [pid_t] {
        childrenByParentPID[pid] ?? []
    }

    /// 子孙进程（不含 root），按先序遍历：父进程总在其子进程之前。
    public func descendants(of rootPID: pid_t) -> [ProcessTreeEntry] {
        var result: [ProcessTreeEntry] = []
        var visited: Set<pid_t> = [rootPID]
        var stack = Array(childPIDs(of: rootPID).reversed())

        while let pid = stack.popLast() {
            guard visited.insert(pid).inserted, let entry = entriesByPID[pid] else { continue }
            result.append(entry)
            stack.append(contentsOf: childPIDs(of: pid).reversed())
        }

        return result
    }

    public func ownResidentMemoryBytes(rootPID: pid_t) -> UInt64 {
        entriesByPID[rootPID]?.memoryBytes ?? Self.memoryBytes(for: rootPID)
    }

    public func aggregate(rootPID: pid_t) -> (totalMemoryBytes: UInt64, descendantMemoryBytes: UInt64, descendantCount: Int) {
        var totalMemoryBytes: UInt64 = 0
        var descendantMemoryBytes: UInt64 = 0
        var descendantCount = 0
        var visited: Set<pid_t> = []
        var stack: [(pid: pid_t, isRoot: Bool)] = [(rootPID, true)]

        while let current = stack.popLast() {
            guard !visited.contains(current.pid) else { continue }
            visited.insert(current.pid)

            let memoryBytes = entriesByPID[current.pid]?.memoryBytes ?? 0
            totalMemoryBytes += memoryBytes

            if !current.isRoot {
                descendantMemoryBytes += memoryBytes
                descendantCount += 1
            }

            for childPID in childrenByParentPID[current.pid] ?? [] {
                stack.append((childPID, false))
            }
        }

        if totalMemoryBytes == 0 {
            totalMemoryBytes = Self.memoryBytes(for: rootPID)
        }

        return (totalMemoryBytes, descendantMemoryBytes, descendantCount)
    }

    /// 该 pid 仍是快照里的那个进程（启动时间一致），用于发信号前排除 pid 复用。
    public static func isRunning(_ entry: ProcessTreeEntry) -> Bool {
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, entry.pid]
        var process = kinfo_proc()
        var length = MemoryLayout<kinfo_proc>.stride

        guard sysctl(&mib, u_int(mib.count), &process, &length, nil, 0) == 0, length > 0 else {
            return false
        }

        return startTime(of: process) == entry.startTime
    }

    private static func allProcesses() -> [ProcessTreeEntry] {
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_ALL, 0]
        var length = 0

        guard sysctl(&mib, u_int(mib.count), nil, &length, nil, 0) == 0, length > 0 else {
            return []
        }

        let count = length / MemoryLayout<kinfo_proc>.stride
        var processes = Array(repeating: kinfo_proc(), count: count)
        let result = processes.withUnsafeMutableBufferPointer { buffer in
            sysctl(&mib, u_int(mib.count), buffer.baseAddress, &length, nil, 0)
        }

        guard result == 0 else {
            return []
        }

        var pathBuffer = [CChar](repeating: 0, count: Int(MAXPATHLEN) * 4)
        let actualCount = length / MemoryLayout<kinfo_proc>.stride
        return processes.prefix(actualCount).compactMap { process in
            let pid = process.kp_proc.p_pid
            guard pid > 0 else { return nil }

            let usage = resourceUsage(for: pid)
            let footprintBytes = usage?.footprintBytes ?? 0
            let pathLength = proc_pidpath(pid, &pathBuffer, UInt32(pathBuffer.count))
            return ProcessTreeEntry(
                pid: pid,
                parentPID: process.kp_eproc.e_ppid,
                memoryBytes: footprintBytes > 0 ? footprintBytes : residentMemoryBytes(for: pid),
                name: commandName(of: process),
                executablePath: pathLength > 0 ? String(cString: pathBuffer) : nil,
                cpuTime: usage?.cpuTime,
                startTime: startTime(of: process),
                hasControllingTerminal: process.kp_eproc.e_tdev != -1,
                userID: process.kp_eproc.e_ucred.cr_uid
            )
        }
    }

    private static func commandName(of process: kinfo_proc) -> String {
        withUnsafeBytes(of: process.kp_proc.p_comm) { bytes in
            String(decoding: bytes.prefix { $0 != 0 }, as: UTF8.self)
        }
    }

    private static func startTime(of process: kinfo_proc) -> TimeInterval {
        let time = process.kp_proc.p_un.__p_starttime
        return TimeInterval(time.tv_sec) + TimeInterval(time.tv_usec) / 1_000_000
    }

    private static func memoryBytes(for pid: pid_t) -> UInt64 {
        let footprintBytes = resourceUsage(for: pid)?.footprintBytes ?? 0
        if footprintBytes > 0 {
            return footprintBytes
        }
        return residentMemoryBytes(for: pid)
    }

    private static let machTimebase: mach_timebase_info_data_t = {
        var info = mach_timebase_info_data_t()
        mach_timebase_info(&info)
        return info
    }()

    private static func resourceUsage(for pid: pid_t) -> (footprintBytes: UInt64, cpuTime: TimeInterval)? {
        var info = rusage_info_v4()
        let result = withUnsafeMutablePointer(to: &info) { pointer -> Int32 in
            pointer.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) { reboundPointer in
                proc_pid_rusage(pid, RUSAGE_INFO_V4, reboundPointer)
            }
        }

        guard result == 0 else {
            return nil
        }

        // ri_user_time / ri_system_time 是 mach 时间单位，Apple Silicon 上不等于纳秒。
        let ticks = Double(info.ri_user_time + info.ri_system_time)
        let nanoseconds = ticks * Double(machTimebase.numer) / Double(machTimebase.denom)
        return (info.ri_phys_footprint, nanoseconds / 1_000_000_000)
    }

    private static func residentMemoryBytes(for pid: pid_t) -> UInt64 {
        var taskInfo = proc_taskinfo()
        let result = proc_pidinfo(
            pid,
            PROC_PIDTASKINFO,
            0,
            &taskInfo,
            Int32(MemoryLayout<proc_taskinfo>.size)
        )

        guard result == Int32(MemoryLayout<proc_taskinfo>.size) else {
            return 0
        }

        return taskInfo.pti_resident_size
    }
}

/// 把进程显示成简短的命令名，例如 `dart language-server`、`bash dart mcp-server`。
public final class ProcessCommandLabeler {
    private var buffer: [UInt8]

    public init() {
        var argumentMax: Int32 = 0
        var length = MemoryLayout<Int32>.size
        var mib: [Int32] = [CTL_KERN, KERN_ARGMAX]
        if sysctl(&mib, u_int(mib.count), &argumentMax, &length, nil, 0) != 0 || argumentMax <= 0 {
            argumentMax = 256 * 1024
        }
        buffer = [UInt8](repeating: 0, count: Int(argumentMax))
    }

    public func label(for entry: ProcessTreeEntry) -> String {
        if let arguments = arguments(for: entry.pid), !arguments.isEmpty {
            return Self.label(arguments: arguments)
        }
        if let executablePath = entry.executablePath {
            return (executablePath as NSString).lastPathComponent
        }
        return entry.name.isEmpty ? "PID \(entry.pid)" : entry.name
    }

    /// argv[0] 取文件名，再接最多两个参数，遇到第一个选项（`-` 开头）为止。
    static func label(arguments: [String]) -> String {
        var parts = [(arguments[0] as NSString).lastPathComponent]
        for argument in arguments.dropFirst() {
            guard parts.count < 3, !argument.isEmpty, !argument.hasPrefix("-") else { break }
            parts.append(argument.hasPrefix("/") ? (argument as NSString).lastPathComponent : argument)
        }

        let label = parts.joined(separator: " ")
        return label.count > 60 ? String(label.prefix(59)) + "…" : label
    }

    private func arguments(for pid: pid_t) -> [String]? {
        var mib: [Int32] = [CTL_KERN, KERN_PROCARGS2, pid]
        var length = buffer.count
        let result = buffer.withUnsafeMutableBytes { bytes in
            sysctl(&mib, u_int(mib.count), bytes.baseAddress, &length, nil, 0)
        }
        guard result == 0, length > MemoryLayout<Int32>.size else { return nil }

        // 布局：argc(Int32) | 可执行文件路径 \0 | 填充 \0... | argv[0] \0 | argv[1] \0 | ... | 环境变量
        let argumentCount = buffer.withUnsafeBytes { $0.load(as: Int32.self) }
        var index = MemoryLayout<Int32>.size
        while index < length, buffer[index] != 0 { index += 1 }
        while index < length, buffer[index] == 0 { index += 1 }

        var arguments: [String] = []
        var start = index
        while index < length, arguments.count < Int(argumentCount) {
            if buffer[index] == 0 {
                arguments.append(String(decoding: buffer[start..<index], as: UTF8.self))
                start = index + 1
            }
            index += 1
        }
        return arguments
    }
}
