import Foundation

public final class RiskClassifier {
    private let highRiskBundleIDs: Set<String>
    private let mediumRiskBundleIDs: Set<String>
    private let highRiskKeywords: [String]
    private let mediumRiskKeywords: [String]

    public init(
        highRiskBundleIDs: Set<String> = RiskClassifier.defaultHighRiskBundleIDs,
        mediumRiskBundleIDs: Set<String> = RiskClassifier.defaultMediumRiskBundleIDs
    ) {
        self.highRiskBundleIDs = highRiskBundleIDs
        self.mediumRiskBundleIDs = mediumRiskBundleIDs
        self.highRiskKeywords = [
            "terminal",
            "iterm",
            "xcode",
            "android studio",
            "studio",
            "cursor",
            "visual studio code",
            "docker",
            "database",
            "postgres",
            "mysql",
            "redis",
            "vpn",
            "1password",
            "keychain",
            "zoom",
            "teams",
            "meeting",
            "dropbox",
            "google drive",
            "icloud",
            "music",
            "spotify",
            "screen",
            "record"
        ]
        self.mediumRiskKeywords = [
            "safari",
            "chrome",
            "firefox",
            "edge",
            "arc",
            "browser",
            "slack",
            "discord",
            "wechat",
            "telegram",
            "feishu",
            "lark",
            "notion",
            "figma",
            "mail"
        ]
    }

    public func classify(bundleID: String, displayName: String) -> RiskLevel {
        if highRiskBundleIDs.contains(bundleID) {
            return .high
        }
        if mediumRiskBundleIDs.contains(bundleID) {
            return .medium
        }

        let normalized = "\(bundleID) \(displayName)".lowercased()
        if highRiskKeywords.contains(where: { normalized.contains($0) }) {
            return .high
        }
        if mediumRiskKeywords.contains(where: { normalized.contains($0) }) {
            return .medium
        }

        return .low
    }

    public static let defaultHighRiskBundleIDs: Set<String> = [
        "com.apple.Terminal",
        "com.googlecode.iterm2",
        "com.apple.dt.Xcode",
        "com.microsoft.VSCode",
        "com.todesktop.230313mzl4w4u92",
        "com.docker.docker",
        "com.1password.1password",
        "com.apple.ActivityMonitor",
        "com.apple.Music",
        "com.spotify.client",
        "us.zoom.xos",
        "com.microsoft.teams2",
        "com.apple.mail",
        "com.getdropbox.dropbox",
        "com.google.drivefs",
        "com.apple.finder",
        "com.apple.systempreferences",
        "com.apple.SystemSettings"
    ]

    public static let defaultMediumRiskBundleIDs: Set<String> = [
        "com.apple.Safari",
        "com.google.Chrome",
        "company.thebrowser.Browser",
        "org.mozilla.firefox",
        "com.microsoft.edgemac",
        "com.tinyspeck.slackmacgap",
        "com.hnc.Discord",
        "com.tencent.xinWeChat",
        "ru.keepcoder.Telegram",
        "notion.id",
        "com.figma.Desktop"
    ]
}
