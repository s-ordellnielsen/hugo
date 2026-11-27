/// The settings that stay the same on every device signed in to the user's
/// Apple Account, through iCloud key-value storage. Every other key in
/// `UserDefaultsKeys` stays on the device: the onboarding and setup flags,
/// the default category migration flag and the Overview's list style.
///
/// `widgetSettings` is a device-only copy in the App Group and is not a synced setting.
///
/// When the publisher status timeline (SLN-227) moves the status into
/// SwiftData, remove `publisherStatus` from this list.
enum SyncedSettings {
    static let keys: [String] = [
        UserDefaultsKeys.publisherStatus,
        UserDefaultsKeys.plannerTargetBase,
        UserDefaultsKeys.plannerExtraHours,
        UserDefaultsKeys.bufferInOverview,
        UserDefaultsKeys.bufferInYear,
        UserDefaultsKeys.durationMinuteInterval,
        UserDefaultsKeys.overseerFullName,
        UserDefaultsKeys.overseerPhoneNumber,
        UserDefaultsKeys.overseerGreetingTemplate,
        UserDefaultsKeys.overseerFirstName,
        UserDefaultsKeys.overseerLastName,
        UserDefaultsKeys.defaultCategoryID,
    ]
}
