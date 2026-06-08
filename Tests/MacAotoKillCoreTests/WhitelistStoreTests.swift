import XCTest
@testable import MacAotoKillCore

final class WhitelistStoreTests: XCTestCase {
    func testDefaultsSeedEditableWhitelist() {
        let (store, defaults, suiteName) = makeStore()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        XCTAssertTrue(store.contains("com.apple.finder"))
        XCTAssertEqual(store.allBundleIDs, WhitelistStore.defaultProtectedBundleIDs)
    }

    func testDefaultProtectedBundleIDCanBeRemoved() {
        let (store, defaults, suiteName) = makeStore()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        store.remove("com.apple.finder")

        XCTAssertFalse(store.contains("com.apple.finder"))
        XCTAssertFalse(store.allBundleIDs.contains("com.apple.finder"))
    }

    func testMigratesLegacyUserWhitelistIntoEditableList() {
        let suiteName = "milu.greenram.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set(["com.example.notes"], forKey: "userWhitelistBundleIDs")

        let store = WhitelistStore(defaults: defaults)

        XCTAssertTrue(store.contains("com.example.notes"))
        XCTAssertTrue(store.contains("com.apple.finder"))
        XCTAssertEqual(
            Set(defaults.stringArray(forKey: "whitelistBundleIDs") ?? []),
            WhitelistStore.defaultProtectedBundleIDs.union(["com.example.notes"])
        )
    }

    private func makeStore() -> (WhitelistStore, UserDefaults, String) {
        let suiteName = "milu.greenram.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        return (WhitelistStore(defaults: defaults), defaults, suiteName)
    }
}
