import Darwin
import Foundation

/// 用 setuid 的 `/usr/bin/top` 读进程内存（与活动监视器的「内存」列同口径）。
/// GreenRAM 以普通用户运行，`proc_pid_rusage` 读不到 root 等其他用户的进程，`top` 可以。
public enum TopMemoryReader {
    /// `pids` 为 nil 时读全部进程。耗时约 0.6 秒，不要在主线程调用。
    public static func readMemory(pids: [pid_t]? = nil) -> [pid_t: UInt64] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/top")
        process.arguments = ["-l", "1", "-stats", "pid,mem"] + (pids ?? []).flatMap { ["-pid", String($0)] }
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
        } catch {
            return [:]
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return parseTopOutput(String(decoding: data, as: UTF8.self))
    }

    /// 解析 `top -stats pid,mem` 的进程行，例如 `68469  55G`。
    static func parseTopOutput(_ output: String) -> [pid_t: UInt64] {
        var result: [pid_t: UInt64] = [:]
        for line in output.split(separator: "\n") {
            let columns = line.split(separator: " ", omittingEmptySubsequences: true)
            guard columns.count == 2, let pid = pid_t(columns[0]), let bytes = parseMemory(columns[1]) else { continue }
            result[pid] = bytes
        }
        return result
    }

    /// `top` 的内存列：`55G`、`512M`、`900K`、`12B`，可能带变化标记 `+` / `-`。
    static func parseMemory<S: StringProtocol>(_ text: S) -> UInt64? {
        var value = String(text)
        while let last = value.last, last == "+" || last == "-" {
            value.removeLast()
        }
        guard let unit = value.last else { return nil }

        let multiplier: Double
        switch unit {
        case "B": multiplier = 1
        case "K": multiplier = 1024
        case "M": multiplier = 1024 * 1024
        case "G": multiplier = 1024 * 1024 * 1024
        case "T": multiplier = 1024 * 1024 * 1024 * 1024
        default: return nil
        }
        guard let number = Double(value.dropLast()), number >= 0 else { return nil }
        return UInt64(number * multiplier)
    }
}
