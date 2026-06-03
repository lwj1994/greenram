import Foundation

public enum MemoryPolicyDefaults {
    public static let ramLimitPercent: Double = 100
    public static let swapLimitEnabled = true
    public static let minimumSwapLimitBytes: UInt64 = 2 * 1024 * 1024 * 1024
    public static let minimumAppMemoryBytes: UInt64 = 250 * 1024 * 1024
    public static let maxAppsPerSweep = 3

    public static var swapLimitBytes: UInt64 {
        max(minimumSwapLimitBytes, ProcessInfo.processInfo.physicalMemory / 2)
    }
}
