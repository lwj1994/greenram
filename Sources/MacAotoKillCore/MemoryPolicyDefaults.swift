import Foundation

public enum MemoryPolicyDefaults {
    public static let ramLimitPercent: Double = 100
    public static let swapLimitEnabled = true
    public static let minimumSwapLimitBytes: UInt64 = 2 * 1024 * 1024 * 1024
    public static let defaultSwapLimitBytes: UInt64 = 8 * 1024 * 1024 * 1024
    public static let maximumSwapLimitBytes: UInt64 = 64 * 1024 * 1024 * 1024
    public static let minimumConfigurableBackgroundDuration: TimeInterval = 3 * 60
    public static let minimumBackgroundDuration: TimeInterval = 30 * 60
    public static let maxAppsPerSweep = 3

    public static var swapLimitBytes: UInt64 {
        defaultSwapLimitBytes
    }
}
