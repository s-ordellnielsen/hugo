/// The settings that stay the same on every device signed in to the user's
/// Apple Account, through iCloud key-value storage. Every other key in
/// `UserDefaultsKeys` stays on the device: the onboarding and setup flags,
/// the publisher status (the planned status timeline moves it into synced
/// data) and the Overview's list style.
enum SyncedSettings {
    static let keys: [String] = [
        UserDefaultsKeys.yearlyGoalPacing,
        UserDefaultsKeys.plannerTargetBase,
        UserDefaultsKeys.plannerExtraHours,
        UserDefaultsKeys.durationMinuteInterval,
        UserDefaultsKeys.overseerFullName,
        UserDefaultsKeys.overseerPhoneNumber,
        UserDefaultsKeys.overseerGreetingTemplate,
        UserDefaultsKeys.overseerFirstName,
        UserDefaultsKeys.overseerLastName,
    ]
}
