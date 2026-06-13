import AppKit
import Foundation
import MacAotoKillCore

struct WhitelistAppInfo: Identifiable, Equatable {
    let bundleID: String
    let displayName: String
    let icon: NSImage
    let isDefaultSeed: Bool

    var id: String {
        bundleID
    }

    static func == (lhs: WhitelistAppInfo, rhs: WhitelistAppInfo) -> Bool {
        lhs.bundleID == rhs.bundleID
            && lhs.displayName == rhs.displayName
            && lhs.isDefaultSeed == rhs.isDefaultSeed
    }
}

struct IdleTimeAppInfo: Identifiable, Equatable {
    let bundleID: String
    let displayName: String
    let icon: NSImage

    var id: String {
        bundleID
    }

    static func == (lhs: IdleTimeAppInfo, rhs: IdleTimeAppInfo) -> Bool {
        lhs.bundleID == rhs.bundleID
            && lhs.displayName == rhs.displayName
    }
}

struct AppDisplayInfo {
    let bundleID: String
    let displayName: String
    let icon: NSImage
}

struct SettingsState: Equatable {
    var memorySnapshot: SystemMemorySnapshot
    var languageCode: String
    var ramLimitPercent: Double
    var swapLimitEnabled: Bool
    var swapLimitGB: Double
    var minimumBackgroundMinutes: Double
    var automaticUpdateReminderEnabled: Bool
    var appIdleTimeItems: [IdleTimeAppInfo]
    var whitelistItems: [WhitelistAppInfo]
    var newIdleTimeBundleID = ""
    var newWhitelistBundleID = ""
    var isResetConfirmationPresented = false
}
