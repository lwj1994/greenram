import Foundation

public enum ByteFormatter {
    public static func memory(_ bytes: UInt64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useGB]
        formatter.countStyle = .memory
        formatter.includesUnit = true
        formatter.includesCount = true
        return formatter.string(fromByteCount: Int64(bytes))
    }
}

public enum DurationFormatter {
    public static func compact(_ interval: TimeInterval) -> String {
        if interval < 60 {
            return "\(Int(interval))s bg"
        }
        if interval < 60 * 60 {
            return "\(Int(interval / 60))m bg"
        }
        return "\(String(format: "%.1f", interval / 3600))h bg"
    }

    public static func compact(_ interval: TimeInterval, localizer: Localizer) -> String {
        if interval < 60 {
            return localizer.t("duration.secondsBg", Int(interval))
        }
        if interval < 60 * 60 {
            return localizer.t("duration.minutesBg", Int(interval / 60))
        }
        return localizer.t("duration.hoursBg", interval / 3600)
    }

    /// 不带「后台」前缀的时长，例如「12 分钟」「1.5 小时」。
    public static func plain(_ interval: TimeInterval, localizer: Localizer) -> String {
        if interval < 60 {
            return localizer.t("duration.seconds", Int(interval))
        }
        if interval < 60 * 60 {
            return localizer.t("duration.minutes", Int(interval / 60))
        }
        return localizer.t("duration.hours", interval / 3600)
    }

    public static func idle(_ interval: TimeInterval, localizer: Localizer) -> String {
        if interval < 60 * 60 {
            return localizer.t("duration.idleMinutes", Int(interval / 60))
        }
        return localizer.t("duration.idleHours", interval / 3600)
    }
}

public enum PercentFormatter {
    public static func compact(_ percent: Double) -> String {
        "\(String(format: "%.0f", percent))%"
    }
}
