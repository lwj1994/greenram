import AppKit
import MacAotoKillCore
import UniformTypeIdentifiers

enum SettingsAppInfoResolver {
    static func makeIdleTimeItems(from bundleIDs: [String], store: WhitelistStore) -> [IdleTimeAppInfo] {
        bundleIDs
            .map { makeIdleTimeItem(bundleID: $0, store: store) }
            .sorted { lhs, rhs in
                let nameOrder = lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName)
                if nameOrder == .orderedSame {
                    return lhs.bundleID.localizedCaseInsensitiveCompare(rhs.bundleID) == .orderedAscending
                }
                return nameOrder == .orderedAscending
            }
    }

    static func makeWhitelistItems(from bundleIDs: [String], store: WhitelistStore) -> [WhitelistAppInfo] {
        bundleIDs
            .map { makeWhitelistItem(bundleID: $0, store: store) }
            .sorted { lhs, rhs in
                let nameOrder = lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName)
                if nameOrder == .orderedSame {
                    return lhs.bundleID.localizedCaseInsensitiveCompare(rhs.bundleID) == .orderedAscending
                }
                return nameOrder == .orderedAscending
            }
    }

    static func existingApplicationURL(from url: URL) -> URL? {
        let standardizedURL = url.standardizedFileURL
        var isDirectory: ObjCBool = false
        guard
            FileManager.default.fileExists(atPath: standardizedURL.path, isDirectory: &isDirectory),
            isDirectory.boolValue,
            standardizedURL.pathExtension.lowercased() == "app"
        else {
            return nil
        }
        return standardizedURL
    }

    private static func makeIdleTimeItem(bundleID: String, store: WhitelistStore) -> IdleTimeAppInfo {
        let appInfo = makeAppDisplayInfo(bundleID: bundleID, store: store)
        return IdleTimeAppInfo(
            bundleID: appInfo.bundleID,
            displayName: appInfo.displayName,
            icon: appInfo.icon
        )
    }

    private static func makeWhitelistItem(bundleID: String, store: WhitelistStore) -> WhitelistAppInfo {
        let appInfo = makeAppDisplayInfo(bundleID: bundleID, store: store)
        return WhitelistAppInfo(
            bundleID: appInfo.bundleID,
            displayName: appInfo.displayName,
            icon: appInfo.icon,
            isDefaultSeed: store.isDefaultProtected(bundleID)
        )
    }

    private static func makeAppDisplayInfo(bundleID: String, store: WhitelistStore) -> AppDisplayInfo {
        let cachedURL = store.appPath(for: bundleID).map { URL(fileURLWithPath: $0) }
        let appURL = cachedURL.flatMap(existingApplicationURL(from:))
            ?? NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)
        let runningApp = NSWorkspace.shared.runningApplications.first { $0.bundleIdentifier == bundleID }
        let bundle = appURL.flatMap(Bundle.init(url:))
        let displayName = nonEmpty(runningApp?.localizedName)
            ?? bundleDisplayName(bundle)
            ?? nonEmpty(appURL?.deletingPathExtension().lastPathComponent)
            ?? systemDisplayNameOverride(for: bundleID)
            ?? fallbackDisplayName(for: bundleID)
        let icon = appIcon(runningApp: runningApp, appURL: appURL, bundleID: bundleID)

        return AppDisplayInfo(
            bundleID: bundleID,
            displayName: displayName,
            icon: icon
        )
    }

    private static func bundleDisplayName(_ bundle: Bundle?) -> String? {
        nonEmpty(bundle?.localizedInfoDictionary?["CFBundleDisplayName"] as? String)
            ?? nonEmpty(bundle?.localizedInfoDictionary?["CFBundleName"] as? String)
            ?? nonEmpty(bundle?.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
            ?? nonEmpty(bundle?.object(forInfoDictionaryKey: "CFBundleName") as? String)
    }

    private static func appIcon(runningApp: NSRunningApplication?, appURL: URL?, bundleID: String) -> NSImage {
        if let runningIcon = runningApp?.icon {
            return scaledIcon(runningIcon)
        }
        if let appURL {
            return scaledIcon(NSWorkspace.shared.icon(forFile: appURL.path))
        }
        if bundleID == "com.apple.WindowServer",
           let displayIcon = NSImage(systemSymbolName: "display", accessibilityDescription: nil) {
            displayIcon.isTemplate = true
            return scaledIcon(displayIcon)
        }
        if let appBundleType = UTType("com.apple.application-bundle") {
            return scaledIcon(NSWorkspace.shared.icon(for: appBundleType))
        }
        return scaledIcon(NSImage(systemSymbolName: "app", accessibilityDescription: nil) ?? NSImage())
    }

    private static func scaledIcon(_ sourceImage: NSImage) -> NSImage {
        let image = (sourceImage.copy() as? NSImage) ?? sourceImage
        image.size = NSSize(width: 34, height: 34)
        return image
    }

    private static func systemDisplayNameOverride(for bundleID: String) -> String? {
        [
            "com.apple.finder": "Finder",
            "com.apple.dock": "Dock",
            "com.apple.WindowServer": "WindowServer",
            "com.apple.systempreferences": "System Preferences",
            "com.apple.SystemSettings": "System Settings"
        ][bundleID]
    }

    private static func fallbackDisplayName(for bundleID: String) -> String {
        nonEmpty(bundleID.split(separator: ".").last.map(String.init)) ?? bundleID
    }

    private static func nonEmpty(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }
}
