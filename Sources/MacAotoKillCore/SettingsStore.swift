import Foundation

public final class SettingsStore {
    private let defaults: UserDefaults
    private let autoReleaseEnabledKey = "autoReleaseEnabled"
    private let ramLimitPercentKey = "ramLimitPercent"
    private let swapLimitEnabledKey = "swapLimitEnabled"
    private let swapLimitBytesKey = "swapLimitBytes"
    private let minimumBackgroundDurationKey = "minimumBackgroundDuration"
    private let minimumBackgroundDurationsByBundleIDKey = "minimumBackgroundDurationsByBundleID"
    private let maxAppsPerSweepKey = "maxAppsPerSweep"
    private let languageCodeKey = "languageCode"
    private let lastUpdateCheckAtKey = "lastUpdateCheckAt"
    private let lastPromptedUpdateVersionKey = "lastPromptedUpdateVersion"
    private let automaticUpdateReminderEnabledKey = "automaticUpdateReminderEnabled"

    public convenience init() {
        self.init(defaults: AppDefaults.make())
    }

    public init(defaults: UserDefaults) {
        self.defaults = defaults
        defaults.removeObject(forKey: ramLimitPercentKey)
        migrateLegacyDynamicSwapLimitDefault()
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

    public func autoQuitBackgroundDuration(for bundleID: String) -> TimeInterval? {
        minimumBackgroundDurationsByBundleID[bundleID]
    }

    public func setMinimumBackgroundDuration(_ duration: TimeInterval?, for bundleID: String) {
        let normalizedBundleID = bundleID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedBundleID.isEmpty else { return }

        var values = minimumBackgroundDurationsByBundleID
        if let duration {
            values[normalizedBundleID] = clampedBackgroundDuration(duration)
        } else {
            values.removeValue(forKey: normalizedBundleID)
        }
        minimumBackgroundDurationsByBundleID = values
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

    public func resetMemoryPolicyDefaults() {
        defaults.removeObject(forKey: autoReleaseEnabledKey)
        defaults.removeObject(forKey: ramLimitPercentKey)
        defaults.removeObject(forKey: swapLimitEnabledKey)
        defaults.removeObject(forKey: swapLimitBytesKey)
        defaults.removeObject(forKey: minimumBackgroundDurationKey)
        defaults.removeObject(forKey: minimumBackgroundDurationsByBundleIDKey)
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
}
