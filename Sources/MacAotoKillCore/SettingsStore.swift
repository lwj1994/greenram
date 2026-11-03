import Foundation

public final class SettingsStore {
    private let defaults: UserDefaults
    private let autoReleaseEnabledKey = "autoReleaseEnabled"
    private let ramLimitPercentKey = "ramLimitPercent"
    private let swapLimitEnabledKey = "swapLimitEnabled"
    private let swapLimitBytesKey = "swapLimitBytes"
    private let minimumBackgroundDurationKey = "minimumBackgroundDuration"
    private let minimumBackgroundDurationsByBundleIDKey = "minimumBackgroundDurationsByBundleID"
    private let autoQuitBundleIDsKey = "autoQuitBundleIDs"
    private let memoryLimitsByBundleIDKey = "memoryLimitsByBundleID"
    private let maxAppsPerSweepKey = "maxAppsPerSweep"
    private let languageCodeKey = "languageCode"
    private let lastUpdateCheckAtKey = "lastUpdateCheckAt"
    private let lastPromptedUpdateVersionKey = "lastPromptedUpdateVersion"
    private let automaticUpdateReminderEnabledKey = "automaticUpdateReminderEnabled"
    private let hasCompletedOnboardingKey = "hasCompletedOnboarding"

    public convenience init() {
        self.init(defaults: AppDefaults.make())
    }

    public init(defaults: UserDefaults) {
        self.defaults = defaults
        defaults.removeObject(forKey: ramLimitPercentKey)
        migrateLegacyDynamicSwapLimitDefault()
        migrateLegacyAutoQuitBundleIDs()
        defaults.synchronize()
    }

    public var autoReleaseEnabled: Bool {
        get {
            guard defaults.object(forKey: autoReleaseEnabledKey) != nil else {
                return true
            }
            return defaults.bool(forKey: autoReleaseEnabledKey)
        }
        set {
            defaults.set(newValue, forKey: autoReleaseEnabledKey)
        }
    }

    public var ramLimitPercent: Double {
        get { MemoryPolicyDefaults.ramLimitPercent }
        set { defaults.removeObject(forKey: ramLimitPercentKey) }
    }

    public var swapLimitBytes: UInt64 {
        get { clampedSwapLimitBytes(uint64(forKey: swapLimitBytesKey, defaultValue: MemoryPolicyDefaults.swapLimitBytes)) }
        set { defaults.set(Double(clampedSwapLimitBytes(newValue)), forKey: swapLimitBytesKey) }
    }

    public var swapLimitEnabled: Bool {
        get {
            guard defaults.object(forKey: swapLimitEnabledKey) != nil else {
                return MemoryPolicyDefaults.swapLimitEnabled
            }
            return defaults.bool(forKey: swapLimitEnabledKey)
        }
        set {
            defaults.set(newValue, forKey: swapLimitEnabledKey)
        }
    }

    public var minimumBackgroundDuration: TimeInterval {
        get { double(forKey: minimumBackgroundDurationKey, defaultValue: MemoryPolicyDefaults.minimumBackgroundDuration) }
        set { defaults.set(clampedBackgroundDuration(newValue), forKey: minimumBackgroundDurationKey) }
    }

    public var minimumBackgroundDurationsByBundleID: [String: TimeInterval] {
        get {
            guard let storedValues = defaults.dictionary(forKey: minimumBackgroundDurationsByBundleIDKey) else {
                return [:]
            }

            return storedValues.reduce(into: [String: TimeInterval]()) { result, entry in
                guard !entry.key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                if let value = entry.value as? Double {
                    result[entry.key] = clampedBackgroundDuration(value)
                } else if let value = entry.value as? NSNumber {
                    result[entry.key] = clampedBackgroundDuration(value.doubleValue)
                }
            }
        }
        set {
            let normalizedValues = newValue.reduce(into: [String: Double]()) { result, entry in
                let bundleID = entry.key.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !bundleID.isEmpty else { return }
                result[bundleID] = clampedBackgroundDuration(entry.value)
            }
            defaults.set(normalizedValues, forKey: minimumBackgroundDurationsByBundleIDKey)
        }
    }

    public var autoQuitBundleIDs: Set<String> {
        get {
            guard let storedValues = defaults.array(forKey: autoQuitBundleIDsKey) as? [String] else {
                return []
            }

            return Set(storedValues.compactMap { normalizeBundleID($0) })
        }
        set {
            let normalizedValues = Set(newValue.compactMap { normalizeBundleID($0) }).sorted()
            defaults.set(normalizedValues, forKey: autoQuitBundleIDsKey)
        }
    }

    public var memoryLimitsByBundleID: [String: UInt64] {
        get {
            guard let storedValues = defaults.dictionary(forKey: memoryLimitsByBundleIDKey) else {
                return [:]
            }

            return storedValues.reduce(into: [String: UInt64]()) { result, entry in
                guard let bundleID = normalizeBundleID(entry.key) else { return }
                if let value = entry.value as? Double {
                    result[bundleID] = clampedAppMemoryLimitBytes(UInt64(Swift.max(0, value)))
                } else if let value = entry.value as? NSNumber {
                    result[bundleID] = clampedAppMemoryLimitBytes(UInt64(Swift.max(0, value.doubleValue)))
                }
            }
        }
        set {
            let normalizedValues = newValue.reduce(into: [String: Double]()) { result, entry in
                guard let bundleID = normalizeBundleID(entry.key) else { return }
                result[bundleID] = Double(clampedAppMemoryLimitBytes(entry.value))
            }
            defaults.set(normalizedValues, forKey: memoryLimitsByBundleIDKey)
        }
    }

    public func customMinimumBackgroundDuration(for bundleID: String) -> TimeInterval? {
        minimumBackgroundDurationsByBundleID[bundleID]
    }

    public func setMinimumBackgroundDuration(_ duration: TimeInterval?, for bundleID: String) {
        guard let normalizedBundleID = normalizeBundleID(bundleID) else { return }

        var values = minimumBackgroundDurationsByBundleID
        if let duration {
            values[normalizedBundleID] = clampedBackgroundDuration(duration)
        } else {
            values.removeValue(forKey: normalizedBundleID)
        }
        minimumBackgroundDurationsByBundleID = values
    }

    public func isAutoQuitEnabled(for bundleID: String) -> Bool {
        guard let normalizedBundleID = normalizeBundleID(bundleID) else { return false }
        return autoQuitBundleIDs.contains(normalizedBundleID)
    }

    public func setAutoQuitEnabled(_ isEnabled: Bool, for bundleID: String) {
        guard let normalizedBundleID = normalizeBundleID(bundleID) else { return }

        var bundleIDs = autoQuitBundleIDs
        if isEnabled {
            bundleIDs.insert(normalizedBundleID)
        } else {
            bundleIDs.remove(normalizedBundleID)
        }
        autoQuitBundleIDs = bundleIDs
    }

    public func customMemoryLimitBytes(for bundleID: String) -> UInt64? {
        guard let normalizedBundleID = normalizeBundleID(bundleID) else { return nil }
        return memoryLimitsByBundleID[normalizedBundleID]
    }

    public func setMemoryLimitBytes(_ limitBytes: UInt64?, for bundleID: String) {
        guard let normalizedBundleID = normalizeBundleID(bundleID) else { return }

        var values = memoryLimitsByBundleID
        if let limitBytes {
            values[normalizedBundleID] = clampedAppMemoryLimitBytes(limitBytes)
        } else {
            values.removeValue(forKey: normalizedBundleID)
        }
        memoryLimitsByBundleID = values
    }

    public var maxAppsPerSweep: Int {
        get { int(forKey: maxAppsPerSweepKey, defaultValue: MemoryPolicyDefaults.maxAppsPerSweep) }
        set { defaults.set(max(1, min(newValue, 20)), forKey: maxAppsPerSweepKey) }
    }

    public var languageCode: String {
        get {
            guard let value = defaults.string(forKey: languageCodeKey) else {
                return AppLanguage.system.storageCode
            }
            return value
        }
        set {
            defaults.set(AppLanguage.from(storageCode: newValue).storageCode, forKey: languageCodeKey)
        }
    }

    public var lastUpdateCheckAt: Date? {
        get { defaults.object(forKey: lastUpdateCheckAtKey) as? Date }
        set {
            if let newValue {
                defaults.set(newValue, forKey: lastUpdateCheckAtKey)
            } else {
                defaults.removeObject(forKey: lastUpdateCheckAtKey)
            }
        }
    }

    public var lastPromptedUpdateVersion: String? {
        get {
            guard let value = defaults.string(forKey: lastPromptedUpdateVersionKey) else {
                return nil
            }
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
        set {
            if let newValue, !newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                defaults.set(newValue, forKey: lastPromptedUpdateVersionKey)
            } else {
                defaults.removeObject(forKey: lastPromptedUpdateVersionKey)
            }
        }
    }

    public var automaticUpdateReminderEnabled: Bool {
        get {
            guard defaults.object(forKey: automaticUpdateReminderEnabledKey) != nil else {
                return true
            }
            return defaults.bool(forKey: automaticUpdateReminderEnabledKey)
        }
        set {
            defaults.set(newValue, forKey: automaticUpdateReminderEnabledKey)
        }
    }

    public var hasCompletedOnboarding: Bool {
        get { defaults.bool(forKey: hasCompletedOnboardingKey) }
        set { defaults.set(newValue, forKey: hasCompletedOnboardingKey) }
    }

    public func resetMemoryPolicyDefaults() {
        defaults.removeObject(forKey: autoReleaseEnabledKey)
        defaults.removeObject(forKey: ramLimitPercentKey)
        defaults.removeObject(forKey: swapLimitEnabledKey)
        defaults.removeObject(forKey: swapLimitBytesKey)
        defaults.removeObject(forKey: minimumBackgroundDurationKey)
        defaults.removeObject(forKey: minimumBackgroundDurationsByBundleIDKey)
        autoQuitBundleIDs = []
        defaults.removeObject(forKey: memoryLimitsByBundleIDKey)
        defaults.removeObject(forKey: maxAppsPerSweepKey)
    }

    private func double(forKey key: String, defaultValue: Double) -> Double {
        guard defaults.object(forKey: key) != nil else {
            return defaultValue
        }
        return defaults.double(forKey: key)
    }

    private func uint64(forKey key: String, defaultValue: UInt64) -> UInt64 {
        guard defaults.object(forKey: key) != nil else {
            return defaultValue
        }
        return UInt64(max(0, defaults.double(forKey: key)))
    }

    private func int(forKey key: String, defaultValue: Int) -> Int {
        guard defaults.object(forKey: key) != nil else {
            return defaultValue
        }
        return defaults.integer(forKey: key)
    }

    private func clamp(_ value: Double, min minimum: Double, max maximum: Double) -> Double {
        Swift.max(minimum, Swift.min(value, maximum))
    }

    private func clampedBackgroundDuration(_ value: TimeInterval) -> TimeInterval {
        max(MemoryPolicyDefaults.minimumConfigurableBackgroundDuration, value)
    }

    private func clampedSwapLimitBytes(_ value: UInt64) -> UInt64 {
        min(
            MemoryPolicyDefaults.maximumSwapLimitBytes,
            max(MemoryPolicyDefaults.minimumSwapLimitBytes, value)
        )
    }

    private func clampedAppMemoryLimitBytes(_ value: UInt64) -> UInt64 {
        min(
            MemoryPolicyDefaults.maximumAppMemoryLimitBytes,
            max(MemoryPolicyDefaults.minimumAppMemoryLimitBytes, value)
        )
    }

    private func normalizeBundleID(_ bundleID: String) -> String? {
        let trimmed = bundleID.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func migrateLegacyDynamicSwapLimitDefault() {
        guard defaults.object(forKey: swapLimitBytesKey) != nil else { return }

        let legacyDefault = min(
            MemoryPolicyDefaults.maximumSwapLimitBytes,
            max(MemoryPolicyDefaults.minimumSwapLimitBytes, ProcessInfo.processInfo.physicalMemory / 2)
        )
        let storedValue = uint64(forKey: swapLimitBytesKey, defaultValue: MemoryPolicyDefaults.swapLimitBytes)
        let oneGiB = UInt64(1024 * 1024 * 1024)
        let isNearEightGBLegacyDrift = storedValue > MemoryPolicyDefaults.defaultSwapLimitBytes
            && storedValue < MemoryPolicyDefaults.defaultSwapLimitBytes + oneGiB
        guard (storedValue == legacyDefault || isNearEightGBLegacyDrift),
              storedValue != MemoryPolicyDefaults.defaultSwapLimitBytes else {
            return
        }

        defaults.set(Double(MemoryPolicyDefaults.defaultSwapLimitBytes), forKey: swapLimitBytesKey)
    }

    private func migrateLegacyAutoQuitBundleIDs() {
        guard defaults.object(forKey: autoQuitBundleIDsKey) == nil else { return }
        autoQuitBundleIDs = Set(minimumBackgroundDurationsByBundleID.keys)
    }
}
