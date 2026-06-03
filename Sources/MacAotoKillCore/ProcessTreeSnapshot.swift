import Darwin
import Foundation

public struct ProcessTreeEntry: Equatable {
    public let pid: pid_t
    public let parentPID: pid_t
    public let memoryBytes: UInt64

    public init(pid: pid_t, parentPID: pid_t, memoryBytes: UInt64) {
        self.pid = pid
        self.parentPID = parentPID
        self.memoryBytes = memoryBytes
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
        self.childrenByParentPID = children
    }

    public static func capture() -> ProcessTreeSnapshot {
        ProcessTreeSnapshot(entries: allProcesses())
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

        let actualCount = length / MemoryLayout<kinfo_proc>.stride
        return processes.prefix(actualCount).compactMap { process in
            let pid = process.kp_proc.p_pid
            guard pid > 0 else { return nil }
            return ProcessTreeEntry(
                pid: pid,
                parentPID: process.kp_eproc.e_ppid,
                memoryBytes: memoryBytes(for: pid)
            )
        }
    }

    private static func memoryBytes(for pid: pid_t) -> UInt64 {
        let footprintBytes = physicalFootprintBytes(for: pid)
        if footprintBytes > 0 {
            return footprintBytes
        }
        return residentMemoryBytes(for: pid)
    }

    private static func physicalFootprintBytes(for pid: pid_t) -> UInt64 {
        var info = rusage_info_v4()
        let result = withUnsafeMutablePointer(to: &info) { pointer -> Int32 in
            pointer.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) { reboundPointer in
                proc_pid_rusage(pid, RUSAGE_INFO_V4, reboundPointer)
            }
        }

        guard result == 0 else {
            return 0
        }

        return info.ri_phys_footprint
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
