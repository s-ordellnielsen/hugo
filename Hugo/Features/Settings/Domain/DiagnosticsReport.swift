import Foundation

/// The text the debug menu copies for a bug report. It holds versions,
/// device facts and record counts only. Never add names, category names,
/// overseer details or anything else the user typed.
nonisolated struct DiagnosticsReport: Equatable, Sendable {
    var appVersion: AppVersion
    /// For example "iOS 26.1".
    var systemVersion: String
    /// "iPhone" or "iPad".
    var deviceModel: String
    /// The app language in use, for example "da".
    var language: String
    var iCloudStatus: String
    /// For example "SchemaV13".
    var schemaName: String
    /// For example "10.0.0".
    var schemaVersion: String
    /// Nil when the count could not be read.
    var entryCount: Int?
    var categoryCount: Int?

    /// English on purpose: the developer reads it.
    var text: String {
        [
            "Hugo \(appVersion.displayString)",
            "\(systemVersion), \(deviceModel)",
            "Language: \(language)",
            "iCloud: \(iCloudStatus)",
            "Schema: \(schemaName) (\(schemaVersion))",
            "Entries: \(entryCount.map(String.init) ?? "unknown")",
            "Categories: \(categoryCount.map(String.init) ?? "unknown")",
        ].joined(separator: "\n")
    }
}
