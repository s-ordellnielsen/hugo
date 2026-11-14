import Foundation

/// The part of iCloud key-value storage that `SettingsSyncService` uses, so
/// tests can pass an in-memory store.
protocol CloudSettingsStore: AnyObject {
    func object(forKey key: String) -> Any?
    func set(_ value: Any?, forKey key: String)
    @discardableResult func synchronize() -> Bool
}

extension NSUbiquitousKeyValueStore: CloudSettingsStore {}

/// Keeps the synced settings (`SyncedSettings.keys`) the same on all of the
/// user's devices by copying them between this device's `UserDefaults` and
/// iCloud key-value storage.
///
/// - At launch, `start()` takes every value iCloud already has, so a new
///   device picks up the settings of the user's other devices. It then sends
///   the settings only this device has.
/// - After that, `pushToCloud()` sends changes made on this device, and
///   `pullFromCloud()` writes changes from other devices into `UserDefaults`,
///   where `@AppStorage` picks them up.
///
/// A value is only written when it differs, so a change never bounces back
/// and forth between the two stores.
struct SettingsSyncService {
    private let defaults: UserDefaults
    private let cloud: any CloudSettingsStore
    private let keys: [String]

    init(
        defaults: UserDefaults = .standard,
        cloud: any CloudSettingsStore = NSUbiquitousKeyValueStore.default,
        keys: [String] = SyncedSettings.keys
    ) {
        self.defaults = defaults
        self.cloud = cloud
        self.keys = keys
    }

    /// Call once at launch.
    func start() {
        cloud.synchronize()
        pullFromCloud()
        pushToCloud()
    }

    /// Writes every synced setting that iCloud has into `UserDefaults`.
    func pullFromCloud() {
        for key in keys {
            guard let cloudValue = cloud.object(forKey: key) else { continue }
            if !Self.isEqual(defaults.object(forKey: key), cloudValue) {
                defaults.set(cloudValue, forKey: key)
            }
        }
    }

    /// Sends every synced setting this device has to iCloud.
    func pushToCloud() {
        for key in keys {
            guard let localValue = defaults.object(forKey: key) else { continue }
            if !Self.isEqual(cloud.object(forKey: key), localValue) {
                cloud.set(localValue, forKey: key)
            }
        }
    }

    private static func isEqual(_ lhs: Any?, _ rhs: Any) -> Bool {
        guard let lhs = lhs as? NSObject, let rhs = rhs as? NSObject else { return false }
        return lhs.isEqual(rhs)
    }
}
