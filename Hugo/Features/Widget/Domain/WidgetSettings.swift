import Foundation
import SwiftData

/// The settings the home screen widget needs, copied into the App Group so the widget can read them.
nonisolated struct WidgetSettings: Codable, Equatable, Sendable {
    /// `UserDefaultsKeys.publisherStatus`, so `PublisherStatus.status(for:)` finds the Monthly goal.
    var publisherStatusID: String
    /// The Buffer hours the Overview adds to the goal: 0 when its switch is off.
    var bufferHours: Int
    /// "major.minor.patch" of the schema of the app build that wrote this.
    var storeSchemaVersion: String

    /// Reads the three standard keys the Overview reads.
    static func current(defaults: UserDefaults) -> WidgetSettings {
        let includeBuffer = defaults.bool(forKey: UserDefaultsKeys.bufferInOverview)
        return WidgetSettings(
            publisherStatusID: defaults.string(forKey: UserDefaultsKeys.publisherStatus) ?? "",
            bufferHours: includeBuffer ? defaults.integer(forKey: UserDefaultsKeys.plannerExtraHours) : 0,
            storeSchemaVersion: schemaVersionString()
        )
    }

    /// The version of the schema this build uses.
    static func schemaVersionString() -> String {
        let version = CurrentSchema.versionIdentifier
        return "\(version.major).\(version.minor).\(version.patch)"
    }
}
