import Darwin
import Foundation

public struct SystemMemorySnapshot: Equatable {
    public let capturedAt: Date
    public let totalPhysicalBytes: UInt64
    public let usedPhysicalBytes: UInt64
    public let freePhysicalBytes: UInt64
    public let compressedBytes: UInt64
    public let swapTotalBytes: UInt64
    public let swapUsedBytes: UInt64
    public let swapAvailableBytes: UInt64

    public var usedPhysicalPercent: Double {
        guard totalPhysicalBytes > 0 else { return 0 }
        return Double(usedPhysicalBytes) / Double(totalPhysicalBytes) * 100
    }

    public var swapUsedPercent: Double {
        guard swapTotalBytes > 0 else { return 0 }
        return Double(swapUsedBytes) / Double(swapTotalBytes) * 100
    }

    public init(
        capturedAt: Date = Date(),
        totalPhysicalBytes: UInt64,
        usedPhysicalBytes: UInt64,
        freePhysicalBytes: UInt64,
        compressedBytes: UInt64,
        swapTotalBytes: UInt64,
        swapUsedBytes: UInt64,
        swapAvailableBytes: UInt64
    ) {
        self.capturedAt = capturedAt
        self.totalPhysicalBytes = totalPhysicalBytes
        self.usedPhysicalBytes = usedPhysicalBytes
        self.freePhysicalBytes = freePhysicalBytes
        self.compressedBytes = compressedBytes
        self.swapTotalBytes = swapTotalBytes
        self.swapUsedBytes = swapUsedBytes
        self.swapAvailableBytes = swapAvailableBytes
    }
}

public struct MemoryThresholdConfiguration: Equatable {
    public var ramLimitPercent: Double
    public var swapLimitEnabled: Bool
    public var swapLimitBytes: UInt64

    public init(
        ramLimitPercent: Double = MemoryPolicyDefaults.ramLimitPercent,
        swapLimitEnabled: Bool = MemoryPolicyDefaults.swapLimitEnabled,
        swapLimitBytes: UInt64 = MemoryPolicyDefaults.swapLimitBytes
    ) {
        self.ramLimitPercent = ramLimitPercent
        self.swapLimitEnabled = swapLimitEnabled
        self.swapLimitBytes = swapLimitBytes
    }
}

public struct MemoryThresholdEvaluation: Equatable {
    public let isExceeded: Bool
    public let reasons: [String]

    public var summary: String {
        if reasons.isEmpty {
            return "Below thresholds"
        }
        return reasons.joined(separator: ", ")
    }
}

public enum SystemMemoryMonitor {
    public static func capture() -> SystemMemorySnapshot {
        let totalPhysicalBytes = ProcessInfo.processInfo.physicalMemory
        let vmStats = captureVMStatistics()
        let swap = captureSwapUsage()
        let pageSize = UInt64(vmStats.pageSize)
        let freeBytes = UInt64(vmStats.statistics.free_count) * pageSize
        let compressedBytes = UInt64(vmStats.statistics.compressor_page_count) * pageSize
        let usedBytes = totalPhysicalBytes > freeBytes ? totalPhysicalBytes - freeBytes : 0

        return SystemMemorySnapshot(
            totalPhysicalBytes: totalPhysicalBytes,
            usedPhysicalBytes: usedBytes,
            freePhysicalBytes: freeBytes,
            compressedBytes: compressedBytes,
            swapTotalBytes: swap.total,
            swapUsedBytes: swap.used,
            swapAvailableBytes: swap.available
        )
    }

    private static func captureVMStatistics() -> (statistics: vm_statistics64_data_t, pageSize: vm_size_t) {
        var statistics = vm_statistics64_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)

        withUnsafeMutablePointer(to: &statistics) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { reboundPointer in
                _ = host_statistics64(mach_host_self(), HOST_VM_INFO64, reboundPointer, &count)
            }
        }

        var pageSize = vm_size_t(0)
        _ = host_page_size(mach_host_self(), &pageSize)
        return (statistics, pageSize)
    }

    private static func captureSwapUsage() -> (total: UInt64, used: UInt64, available: UInt64) {
        var usage = xsw_usage()
        var size = MemoryLayout<xsw_usage>.stride
        let result = sysctlbyname("vm.swapusage", &usage, &size, nil, 0)

        guard result == 0 else {
            return (0, 0, 0)
        }

        return (usage.xsu_total, usage.xsu_used, usage.xsu_avail)
    }
}

public enum MemoryThresholdEvaluator {
    public static func evaluate(
        snapshot: SystemMemorySnapshot,
        configuration: MemoryThresholdConfiguration
    ) -> MemoryThresholdEvaluation {
        var reasons: [String] = []

        if snapshot.usedPhysicalPercent >= configuration.ramLimitPercent {
            reasons.append("RAM \(PercentFormatter.compact(snapshot.usedPhysicalPercent)) >= \(PercentFormatter.compact(configuration.ramLimitPercent))")
        }

        if configuration.swapLimitEnabled && snapshot.swapUsedBytes >= configuration.swapLimitBytes {
            reasons.append("Swap \(ByteFormatter.memory(snapshot.swapUsedBytes)) >= \(ByteFormatter.memory(configuration.swapLimitBytes))")
        }

        return MemoryThresholdEvaluation(isExceeded: !reasons.isEmpty, reasons: reasons)
    }
}
