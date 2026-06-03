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
        XCTAssertEqual(store.minimumAppMemoryBytes, MemoryPolicyDefaults.minimumAppMemoryBytes)
        XCTAssertEqual(store.maxAppsPerSweep, MemoryPolicyDefaults.maxAppsPerSweep)
    }

    func testSwapLimitClampsToMinimum() {
        let suiteName = "milu.greenram.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = SettingsStore(defaults: defaults)
        store.swapLimitBytes = 0

        XCTAssertEqual(store.swapLimitBytes, MemoryPolicyDefaults.minimumSwapLimitBytes)
    }

    func testThresholdConfigurationUsesSharedDefaults() {
        let configuration = MemoryThresholdConfiguration()

        XCTAssertEqual(configuration.ramLimitPercent, MemoryPolicyDefaults.ramLimitPercent)
        XCTAssertEqual(configuration.swapLimitEnabled, MemoryPolicyDefaults.swapLimitEnabled)
        XCTAssertEqual(configuration.swapLimitBytes, MemoryPolicyDefaults.swapLimitBytes)
    }
}
