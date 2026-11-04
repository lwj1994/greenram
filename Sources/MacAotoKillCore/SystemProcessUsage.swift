import Darwin
import Foundation

/// 不属于任何 App 进程树的进程（launchd 拉起的系统服务、用户 agent 等）。
public struct SystemProcessUsage: Equatable, Identifiable {
    public let entry: ProcessTreeEntry
    /// `top` 读到的内存，与活动监视器「内存」列同口径。
    public let memoryBytes: UInt64

    public var id: pid_t { entry.pid }
    public var pid: pid_t { entry.pid }

    public var name: String {
        entry.executablePath.map { ($0 as NSString).lastPathComponent } ?? entry.name
    }

    public var isRoot: Bool { entry.userID == 0 }

    /// 结束后会登出或死机的关键进程，不允许结束。
    public var isProtected: Bool {
        SystemProcessTerminator.isProtected(entry)
    }
}

public struct SystemProcessSummary: Equatable {
    /// 按内存降序。
    public let processes: [SystemProcessUsage]
    public let capturedAt: Date

    public var totalMemoryBytes: UInt64 {
        processes.reduce(0) { $0 + $1.memoryBytes }
    }
}

public enum SystemProcessSampler {
    /// 从进程树里去掉 App 及其子孙，剩下的按 `top` 读到的内存排序。读不到内存的进程（已退出）丢弃。
    public static func summarize(
        tree: ProcessTreeSnapshot,
        appPIDs: [pid_t],
        memoryByPID: [pid_t: UInt64],
        now: Date = Date()
    ) -> SystemProcessSummary {
        var appTreePIDs = Set(appPIDs)
        for pid in appPIDs {
            appTreePIDs.formUnion(tree.descendants(of: pid).map(\.pid))
        }

        let processes = tree.entries
            .filter { !appTreePIDs.contains($0.pid) }
            .compactMap { entry -> SystemProcessUsage? in
                memoryByPID[entry.pid].map { SystemProcessUsage(entry: entry, memoryBytes: $0) }
            }
            .sorted { ($0.memoryBytes, $1.pid) > ($1.memoryBytes, $0.pid) }

        return SystemProcessSummary(processes: processes, capturedAt: now)
    }
}

public enum SystemProcessTermination: Equatable {
    case terminated
    case cancelled
    case failed(String)
}

public enum SystemProcessTerminator {
    /// 结束后会导致登出、死机或系统功能整体失效的进程（可执行文件名）。
    public static let protectedNames: Set<String> = [
        "kernel_task", "launchd", "WindowServer", "loginwindow", "logind",
        "opendirectoryd", "securityd", "authd", "SecurityAgent", "configd",
        "coreservicesd", "diskarbitrationd", "notifyd", "powerd", "fseventsd",
        "cfprefsd", "distnoted", "usermanagerd", "watchdogd", "UserEventAgent"
    ]

    public static func isProtected(_ entry: ProcessTreeEntry) -> Bool {
        let name = entry.executablePath.map { ($0 as NSString).lastPathComponent } ?? entry.name
        return entry.pid <= 1
            || entry.pid == ProcessInfo.processInfo.processIdentifier
            || protectedNames.contains(name)
    }

    /// SIGKILL 结束进程。同一用户的进程直接发信号；其他用户（root 等）的进程请求管理员密码。
    ///
    /// 提权由 Apple 签名的 `/usr/bin/osascript` 发起：进程内的 NSAppleScript 会让 authd 校验 GreenRAM 自己的签名，
    /// ad-hoc 签名的开发版会直接 "Authorization failed"。输入密码期间 pid 可能被复用，所以 root shell 里先核对
    /// 可执行文件名再 kill（`ps` 对部分进程只给相对名，不比完整路径）。`adminPrompt` 显示在密码框里，说明为什么要密码。会阻塞到用户处理完密码框，不要在主线程调用。
    public static func terminate(_ entry: ProcessTreeEntry, adminPrompt: String? = nil) -> SystemProcessTermination {
        guard !isProtected(entry) else {
            return .failed("protected system process")
        }
        guard ProcessTreeSnapshot.isRunning(entry) else {
            return .failed("process is no longer running")
        }

        if entry.userID == getuid() {
            return kill(entry.pid, SIGKILL) == 0 ? .terminated : .failed(String(cString: strerror(errno)))
        }

        guard let executablePath = entry.executablePath else {
            return .failed("executable path unavailable")
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = [
            "-e", "on run argv",
            "-e", #"set thePID to item 1 of argv"#,
            "-e", #"set theCommand to "test \"$(/usr/bin/basename \"$(/bin/ps -p " & thePID & " -o comm=)\")\" = " & quoted form of (item 2 of argv) & " && /bin/kill -9 " & thePID"#,
            "-e", #"if (count of argv) > 2 then"#,
            "-e", #"do shell script theCommand with prompt (item 3 of argv) with administrator privileges"#,
            "-e", "else",
            "-e", #"do shell script theCommand with administrator privileges"#,
            "-e", "end if",
            "-e", "end run",
            String(entry.pid),
            (executablePath as NSString).lastPathComponent
        ] + (adminPrompt.map { [$0] } ?? [])
        let errorPipe = Pipe()
        process.standardOutput = FileHandle.nullDevice
        process.standardError = errorPipe

        do {
            try process.run()
        } catch {
            return .failed(error.localizedDescription)
        }
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        guard process.terminationStatus != 0 else { return .terminated }
        let message = String(decoding: errorData, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        // -128：用户在密码框点了取消。
        return message.contains("(-128)") ? .cancelled : .failed(message)
    }
}
