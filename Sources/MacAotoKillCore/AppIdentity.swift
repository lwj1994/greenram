import Foundation

public enum AppIdentity {
    public static let name = "GreenRAM"
    public static let bundleIdentifier = "milu.greenram"
    public static let legacyBundleIdentifiers = [
        "dev.dontbesilent.GreenRAM",
        "dev.dontbesilent.MacAotoKill"
    ]
}

public enum AppDefaults {
    private static let migrationMarkerKey = "didMigrateFromMacAotoKill"

    public static func make() -> UserDefaults {
        let defaults = UserDefaults(suiteName: AppIdentity.bundleIdentifier) ?? .standard
        migrateLegacyDefaultsIfNeeded(to: defaults)
        return defaults
    }

    private static func migrateLegacyDefaultsIfNeeded(to defaults: UserDefaults) {
        guard defaults.object(forKey: migrationMarkerKey) == nil else { return }
        let currentDomain = defaults.persistentDomain(forName: AppIdentity.bundleIdentifier) ?? [:]

        if currentDomain.isEmpty {
            for legacyBundleIdentifier in AppIdentity.legacyBundleIdentifiers {
                guard let legacyDefaults = UserDefaults(suiteName: legacyBundleIdentifier),
                      let legacyDomain = legacyDefaults.persistentDomain(forName: legacyBundleIdentifier),
                      !legacyDomain.isEmpty else { continue }

                defaults.setPersistentDomain(legacyDomain, forName: AppIdentity.bundleIdentifier)
                break
            }
        }

        defaults.set(true, forKey: migrationMarkerKey)
    }
}
