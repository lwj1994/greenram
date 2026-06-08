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
    private let whitelistKey = "whitelistBundleIDs"
    private let legacyUserWhitelistKey = "userWhitelistBundleIDs"

    public convenience init() {
        self.init(defaults: AppDefaults.make())
    }

    public init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    public var bundleIDs: Set<String> {
        get {
            if let ids = defaults.stringArray(forKey: whitelistKey) {
                return Set(ids)
            }

            let migrated = Self.defaultProtectedBundleIDs.union(
                defaults.stringArray(forKey: legacyUserWhitelistKey) ?? []
            )
            defaults.set(Array(migrated).sorted(), forKey: whitelistKey)
            return migrated
        }
        set {
            defaults.set(Array(newValue).sorted(), forKey: whitelistKey)
        }
    }

    public var userBundleIDs: Set<String> {
        get {
            bundleIDs.subtracting(Self.defaultProtectedBundleIDs)
        }
        set {
            let currentDefaultBundleIDs = bundleIDs.intersection(Self.defaultProtectedBundleIDs)
            bundleIDs = currentDefaultBundleIDs.union(newValue)
        }
    }

    public var allBundleIDs: Set<String> {
        get {
            bundleIDs
        }
        set {
            bundleIDs = newValue
        }
    }

    public func contains(_ bundleID: String?) -> Bool {
        guard let bundleID else { return true }
        return bundleIDs.contains(bundleID)
    }

    public func isDefaultProtected(_ bundleID: String) -> Bool {
        Self.defaultProtectedBundleIDs.contains(bundleID)
    }

    public func add(_ bundleID: String) {
        var ids = bundleIDs
        ids.insert(bundleID)
        bundleIDs = ids
    }

    public func remove(_ bundleID: String) {
        var ids = bundleIDs
        ids.remove(bundleID)
        bundleIDs = ids
    }
}
