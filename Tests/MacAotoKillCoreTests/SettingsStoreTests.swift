import XCTest
@testable import MacAotoKillCore

final class SettingsStoreTests: XCTestCase {
    func testDefaultMemoryPolicyMatchesMVPDefaults() {
        let suiteName = "milu.greenram.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = SettingsStore(defaults: defaults)

        XCTAssertEqual(store.ramLimitPercent, MemoryPolicyDefaults.ramLimitPercent)
        XCTAssertEqual(store.swapLimitEnabled, MemoryPolicyDefaults.swapLimitEnabled)
        XCTAssertEqual(store.swapLimitBytes, MemoryPolicyDefaults.swapLimitBytes)
        XCTAssertEqual(store.minimumBackgroundDuration, MemoryPolicyDefaults.minimumBackgroundDuration)
        XCTAssertTrue(store.minimumBackgroundDurationsByBundleID.isEmpty)
        XCTAssertTrue(store.autoQuitBundleIDs.isEmpty)
        XCTAssertTrue(store.memoryLimitsByBundleID.isEmpty)
        XCTAssertEqual(store.maxAppsPerSweep, MemoryPolicyDefaults.maxAppsPerSweep)
        XCTAssertTrue(store.automaticUpdateReminderEnabled)
    }

    func testDefaultSwapLimitIsEightGB() {
        XCTAssertEqual(MemoryPolicyDefaults.swapLimitBytes, 8 * 1024 * 1024 * 1024)
    }

    func testLegacyDynamicSwapLimitDefaultMigratesToEightGB() {
        let legacyDefault = min(
            MemoryPolicyDefaults.maximumSwapLimitBytes,
            max(MemoryPolicyDefaults.minimumSwapLimitBytes, ProcessInfo.processInfo.physicalMemory / 2)
        )
        guard legacyDefault != MemoryPolicyDefaults.defaultSwapLimitBytes else { return }

        let suiteName = "milu.greenram.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set(Double(legacyDefault), forKey: "swapLimitBytes")

        let store = SettingsStore(defaults: defaults)

        XCTAssertEqual(store.swapLimitBytes, MemoryPolicyDefaults.defaultSwapLimitBytes)
    }

    func testLegacyNearEightGBSwapLimitDriftMigratesToEightGB() {
        let suiteName = "milu.greenram.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set(
            Double(MemoryPolicyDefaults.defaultSwapLimitBytes + 256 * 1024 * 1024),
            forKey: "swapLimitBytes"
        )

        let store = SettingsStore(defaults: defaults)

        XCTAssertEqual(store.swapLimitBytes, MemoryPolicyDefaults.defaultSwapLimitBytes)
    }

    func testStartupRemovesLegacyRamLimitOverride() {
        let suiteName = "milu.greenram.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set(80, forKey: "ramLimitPercent")

        let store = SettingsStore(defaults: defaults)

        XCTAssertEqual(store.ramLimitPercent, 100)
        XCTAssertNil(defaults.object(forKey: "ramLimitPercent"))
    }

    func testSwapLimitClampsToMinimum() {
        let suiteName = "milu.greenram.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = SettingsStore(defaults: defaults)
        store.swapLimitBytes = 0

        XCTAssertEqual(store.swapLimitBytes, MemoryPolicyDefaults.minimumSwapLimitBytes)
    }

    func testSwapLimitClampsToMaximum() {
        let suiteName = "milu.greenram.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = SettingsStore(defaults: defaults)
        store.swapLimitBytes = 128 * 1024 * 1024 * 1024

        XCTAssertEqual(store.swapLimitBytes, MemoryPolicyDefaults.maximumSwapLimitBytes)
    }

    func testCustomBackgroundDurationsPersistAndClampToMinimum() {
        let suiteName = "milu.greenram.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = SettingsStore(defaults: defaults)
        store.setMinimumBackgroundDuration(30, for: "com.example.short")
        store.setMinimumBackgroundDuration(45 * 60, for: "com.example.long")

        XCTAssertEqual(store.minimumBackgroundDurationsByBundleID["com.example.short"], MemoryPolicyDefaults.minimumConfigurableBackgroundDuration)
        XCTAssertEqual(store.customMinimumBackgroundDuration(for: "com.example.long"), 45 * 60)
        XCTAssertNil(store.customMinimumBackgroundDuration(for: "com.example.default"))
        XCTAssertTrue(store.autoQuitBundleIDs.isEmpty)
    }

    func testAutoQuitBundleIDsPersistSeparatelyFromCustomBackgroundDurations() {
        let suiteName = "milu.greenram.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = SettingsStore(defaults: defaults)
        store.setMinimumBackgroundDuration(45 * 60, for: "com.example.timed")
        store.setAutoQuitEnabled(true, for: "com.example.auto")
        store.setAutoQuitEnabled(true, for: "  com.example.trimmed  ")
        store.setAutoQuitEnabled(false, for: "com.example.auto")

        XCTAssertEqual(store.minimumBackgroundDurationsByBundleID.keys.sorted(), ["com.example.timed"])
        XCTAssertEqual(store.autoQuitBundleIDs, ["com.example.trimmed"])
        XCTAssertFalse(store.isAutoQuitEnabled(for: "com.example.timed"))
        XCTAssertTrue(store.isAutoQuitEnabled(for: "com.example.trimmed"))
    }

    func testMemoryLimitsPersistSeparatelyAndClamp() {
        let suiteName = "milu.greenram.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = SettingsStore(defaults: defaults)
        store.setMemoryLimitBytes(30, for: "com.example.small")
        store.setMemoryLimitBytes(45 * 1024 * 1024 * 1024, for: "  com.example.large  ")
        store.setMemoryLimitBytes(nil, for: "com.example.small")

        XCTAssertEqual(store.memoryLimitsByBundleID.keys.sorted(), ["com.example.large"])
        XCTAssertEqual(store.customMemoryLimitBytes(for: "com.example.large"), 45 * 1024 * 1024 * 1024)
        XCTAssertNil(store.customMemoryLimitBytes(for: "com.example.small"))
        XCTAssertTrue(store.autoQuitBundleIDs.isEmpty)

        store.setMemoryLimitBytes(1, for: "com.example.minimum")
        XCTAssertEqual(store.customMemoryLimitBytes(for: "com.example.minimum"), MemoryPolicyDefaults.minimumAppMemoryLimitBytes)

        store.setMemoryLimitBytes(UInt64.max, for: "com.example.maximum")
        XCTAssertEqual(store.customMemoryLimitBytes(for: "com.example.maximum"), MemoryPolicyDefaults.maximumAppMemoryLimitBytes)
    }

    func testLegacyCustomBackgroundDurationsMigrateToAutoQuitBundleIDsOnce() {
        let suiteName = "milu.greenram.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set([
            "com.example.legacy-short": 10 * 60,
            "com.example.legacy-long": 45 * 60
        ], forKey: "minimumBackgroundDurationsByBundleID")

        let store = SettingsStore(defaults: defaults)

        XCTAssertEqual(store.autoQuitBundleIDs, ["com.example.legacy-long", "com.example.legacy-short"])
        XCTAssertEqual(store.customMinimumBackgroundDuration(for: "com.example.legacy-long"), 45 * 60)
    }

    func testEmptyLegacyMigrationStillMarksAutoQuitListMigrated() {
        let suiteName = "milu.greenram.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = SettingsStore(defaults: defaults)
        store.setMinimumBackgroundDuration(45 * 60, for: "com.example.new-custom-time")
        let reloadedStore = SettingsStore(defaults: defaults)

        XCTAssertTrue(reloadedStore.autoQuitBundleIDs.isEmpty)
        XCTAssertEqual(reloadedStore.customMinimumBackgroundDuration(for: "com.example.new-custom-time"), 45 * 60)
    }

    func testResetMemoryPolicyDefaultsRemovesAppRules() {
        let suiteName = "milu.greenram.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = SettingsStore(defaults: defaults)
        store.setMinimumBackgroundDuration(45 * 60, for: "com.example.long")
        store.setAutoQuitEnabled(true, for: "com.example.auto")
        store.setMemoryLimitBytes(2 * 1024 * 1024 * 1024, for: "com.example.memory")

        store.resetMemoryPolicyDefaults()

        XCTAssertTrue(store.minimumBackgroundDurationsByBundleID.isEmpty)
        XCTAssertTrue(store.autoQuitBundleIDs.isEmpty)
        XCTAssertTrue(store.memoryLimitsByBundleID.isEmpty)
    }

    func testCustomBackgroundDurationAddedAfterResetDoesNotMigrateToAutoQuit() {
        let suiteName = "milu.greenram.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = SettingsStore(defaults: defaults)
        store.setMinimumBackgroundDuration(45 * 60, for: "com.example.before-reset")
        store.resetMemoryPolicyDefaults()
        store.setMinimumBackgroundDuration(10 * 60, for: "com.example.after-reset")
        let reloadedStore = SettingsStore(defaults: defaults)

        XCTAssertTrue(reloadedStore.autoQuitBundleIDs.isEmpty)
        XCTAssertEqual(reloadedStore.customMinimumBackgroundDuration(for: "com.example.after-reset"), 10 * 60)
    }

    func testThresholdConfigurationUsesSharedDefaults() {
        let configuration = MemoryThresholdConfiguration()

        XCTAssertEqual(configuration.ramLimitPercent, MemoryPolicyDefaults.ramLimitPercent)
        XCTAssertEqual(configuration.swapLimitEnabled, MemoryPolicyDefaults.swapLimitEnabled)
        XCTAssertEqual(configuration.swapLimitBytes, MemoryPolicyDefaults.swapLimitBytes)
    }

    func testUpdateCheckStatePersists() {
        let suiteName = "milu.greenram.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = SettingsStore(defaults: defaults)
        let date = Date(timeIntervalSince1970: 1_717_824_000)

        store.lastUpdateCheckAt = date
        store.lastPromptedUpdateVersion = "v0.1.9"
        store.automaticUpdateReminderEnabled = false

        XCTAssertEqual(store.lastUpdateCheckAt, date)
        XCTAssertEqual(store.lastPromptedUpdateVersion, "v0.1.9")
        XCTAssertFalse(store.automaticUpdateReminderEnabled)

        store.lastUpdateCheckAt = nil
        store.lastPromptedUpdateVersion = " "

        XCTAssertNil(store.lastUpdateCheckAt)
        XCTAssertNil(store.lastPromptedUpdateVersion)
    }

    func testOnboardingCompletionPersistsAndSurvivesPolicyReset() {
        let suiteName = "milu.greenram.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = SettingsStore(defaults: defaults)
        XCTAssertFalse(store.hasCompletedOnboarding)

        store.hasCompletedOnboarding = true
        store.resetMemoryPolicyDefaults()

        XCTAssertTrue(SettingsStore(defaults: defaults).hasCompletedOnboarding)
    }
}
