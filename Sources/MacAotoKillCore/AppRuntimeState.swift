import Darwin
import Foundation

public enum RiskLevel: String, CaseIterable, Equatable {
    case low
    case medium
    case high

    public var displayName: String {
        switch self {
        case .low:
            return "Low Risk"
        case .medium:
            return "Medium Risk"
        case .high:
            return "High Risk"
        }
    }

    public func localizedName(_ localizer: Localizer) -> String {
        switch self {
        case .low:
            return localizer.t("risk.low")
        case .medium:
            return localizer.t("risk.medium")
        case .high:
            return localizer.t("risk.high")
        }
    }
}

public enum MemoryPressureLevel: String, Equatable {
    case normal
    case warning
    case critical

    public var rank: Int {
        switch self {
        case .normal:
            return 0
        case .warning:
            return 1
        case .critical:
            return 2
        }
    }

    public var displayName: String {
        switch self {
        case .normal:
            return "Normal"
        case .warning:
            return "Warning"
        case .critical:
            return "Critical"
        }
    }

    public func localizedName(_ localizer: Localizer) -> String {
        switch self {
        case .normal:
            return localizer.t("pressure.normal")
        case .warning:
            return localizer.t("pressure.warning")
        case .critical:
            return localizer.t("pressure.critical")
        }
    }

    public static func max(_ lhs: MemoryPressureLevel, _ rhs: MemoryPressureLevel) -> MemoryPressureLevel {
        lhs.rank >= rhs.rank ? lhs : rhs
    }
}

public struct AppRuntimeState: Equatable, Identifiable {
    public let pid: pid_t
    public let bundleID: String
    public let displayName: String
    public let launchDate: Date?
    public let lastForegroundAt: Date?
    public let lastBackgroundAt: Date?
    public let memoryBytes: UInt64
    public let ownMemoryBytes: UInt64
    public let descendantMemoryBytes: UInt64
    public let descendantProcessCount: Int
    public let isFrontmost: Bool
    public let isWhitelisted: Bool
    public let riskLevel: RiskLevel

    public var id: pid_t { pid }

    public init(
        pid: pid_t,
        bundleID: String,
        displayName: String,
        launchDate: Date?,
        lastForegroundAt: Date?,
        lastBackgroundAt: Date?,
        memoryBytes: UInt64,
        isFrontmost: Bool,
        isWhitelisted: Bool,
        riskLevel: RiskLevel,
        ownMemoryBytes: UInt64? = nil,
        descendantMemoryBytes: UInt64 = 0,
        descendantProcessCount: Int = 0
    ) {
        self.pid = pid
        self.bundleID = bundleID
        self.displayName = displayName
        self.launchDate = launchDate
        self.lastForegroundAt = lastForegroundAt
        self.lastBackgroundAt = lastBackgroundAt
        self.memoryBytes = memoryBytes
        self.ownMemoryBytes = ownMemoryBytes ?? memoryBytes
        self.descendantMemoryBytes = descendantMemoryBytes
        self.descendantProcessCount = descendantProcessCount
        self.isFrontmost = isFrontmost
        self.isWhitelisted = isWhitelisted
        self.riskLevel = riskLevel
    }

    public func backgroundDuration(now: Date = Date()) -> TimeInterval {
        guard !isFrontmost else { return 0 }
        if let lastBackgroundAt {
            return max(0, now.timeIntervalSince(lastBackgroundAt))
        }
        if let lastForegroundAt {
            return max(0, now.timeIntervalSince(lastForegroundAt))
        }
        if let launchDate {
            return max(0, now.timeIntervalSince(launchDate))
        }
        return 0
    }
}
