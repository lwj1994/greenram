import Foundation

public final class SettingsStore {
    private let defaults: UserDefaults
    private let autoReleaseEnabledKey = "autoReleaseEnabled"
    private let ramLimitPercentKey = "ramLimitPercent"
    private let swapLimitEnabledKey = "swapLimitEnabled"
    private let swapLimitBytesKey = "swapLimitBytes"
    private let minimumAppMemoryBytesKey = "minimumAppMemoryBytes"
    private let maxAppsPerSweepKey = "maxAppsPerSweep"
    private let languageCodeKey = "languageCode"

    public convenience init() {
        self.init(defaults: AppDefaults.make())
    }

    public init(defaults: UserDefaults) {
        self.defaults = defaults
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
        get { double(forKey: ramLimitPercentKey, defaultValue: MemoryPolicyDefaults.ramLimitPercent) }
        set { defaults.set(clamp(newValue, min: 1, max: 100), forKey: ramLimitPercentKey) }
    }

    public var swapLimitBytes: UInt64 {
        get { uint64(forKey: swapLimitBytesKey, defaultValue: MemoryPolicyDefaults.swapLimitBytes) }
        set { defaults.set(Double(max(newValue, MemoryPolicyDefaults.minimumSwapLimitBytes)), forKey: swapLimitBytesKey) }
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

    public var minimumAppMemoryBytes: UInt64 {
        get { uint64(forKey: minimumAppMemoryBytesKey, defaultValue: MemoryPolicyDefaults.minimumAppMemoryBytes) }
        set { defaults.set(Double(newValue), forKey: minimumAppMemoryBytesKey) }
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

    public func resetMemoryPolicyDefaults() {
        defaults.removeObject(forKey: autoReleaseEnabledKey)
        defaults.removeObject(forKey: ramLimitPercentKey)
        defaults.removeObject(forKey: swapLimitEnabledKey)
        defaults.removeObject(forKey: swapLimitBytesKey)
        defaults.removeObject(forKey: minimumAppMemoryBytesKey)
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
}
