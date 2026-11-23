nonisolated enum UserDefaultsKeys {
    static let isOnboarding = "isOnboarding"
    static let hasRunInitialSetup = "hasRunInitialSetup"

    static let publisherStatus = "publisherStatus"
    static let plannerTargetBase = "plannerTargetBase"
    static let plannerExtraHours = "plannerExtraHours"
    /// Whether Overview adds the Buffer to the monthly goal it shows. Off by default.
    static let bufferInOverview = "bufferInOverview"
    /// Whether the Service Year tab adds the Buffer to the monthly goal it uses. Off by default.
    static let bufferInYear = "bufferInYear"

    static let durationMinuteInterval = "durationMinuteInterval"

    static let overseerFullName = "overseerFullName"
    static let overseerPhoneNumber = "overseerPhoneNumber"
    static let overseerGreetingTemplate = "overseerGreetingTemplate"
    static let overseerFirstName = "overseerFirstName"
    static let overseerLastName = "overseerLastName"

    static let overviewListStyle = "overviewListStyle"

    /// The UUID string of the default category. "" means the user cleared it.
    /// Synced. See `DefaultCategory`.
    static let defaultCategoryID = "defaultCategoryID"

    /// Whether this device has copied the old per-category default flag into
    /// `defaultCategoryID`. Device-only.
    static let hasMigratedDefaultCategory = "hasMigratedDefaultCategory"

    /// When this device last finished a sync with iCloud. Device-only.
    static let cloudSyncLastSuccess = "cloudSyncLastSuccess"
}
