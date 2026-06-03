import Foundation

public final class WhitelistStore {
    public static let defaultProtectedBundleIDs: Set<String> = [
        "com.apple.finder",
        "com.apple.dock",
        "com.apple.WindowServer",
        "com.apple.systempreferences",
        "com.apple.SystemSettings"
    ]

    private let defaults: UserDefaults
    private let userWhitelistKey = "userWhitelistBundleIDs"

    public convenience init() {
        self.init(defaults: AppDefaults.make())
    }

    public init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    public var userBundleIDs: Set<String> {
        get {
            Set(defaults.stringArray(forKey: userWhitelistKey) ?? [])
        }
        set {
            defaults.set(Array(newValue).sorted(), forKey: userWhitelistKey)
        }
    }

    public var allBundleIDs: Set<String> {
        Self.defaultProtectedBundleIDs.union(userBundleIDs)
    }

    public func contains(_ bundleID: String?) -> Bool {
        guard let bundleID else { return true }
        return allBundleIDs.contains(bundleID)
    }

    public func isDefaultProtected(_ bundleID: String) -> Bool {
        Self.defaultProtectedBundleIDs.contains(bundleID)
    }

    public func add(_ bundleID: String) {
        var ids = userBundleIDs
        ids.insert(bundleID)
        userBundleIDs = ids
    }

    public func remove(_ bundleID: String) {
        var ids = userBundleIDs
        ids.remove(bundleID)
        userBundleIDs = ids
    }
}
