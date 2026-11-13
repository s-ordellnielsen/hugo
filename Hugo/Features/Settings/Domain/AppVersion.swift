import Foundation

/// The app's version and build number, read from an Info.plist dictionary,
/// for the support email subject and the debug menu's diagnostics.
nonisolated struct AppVersion: Equatable, Sendable {
    let marketingVersion: String
    let buildNumber: String

    init(infoDictionary: [String: Any]) {
        marketingVersion = infoDictionary["CFBundleShortVersionString"] as? String ?? "?"
        buildNumber = infoDictionary["CFBundleVersion"] as? String ?? "?"
    }

    /// The running app's version.
    static var current: AppVersion {
        AppVersion(infoDictionary: Bundle.main.infoDictionary ?? [:])
    }

    /// For example "1.0 (125)".
    var displayString: String {
        "\(marketingVersion) (\(buildNumber))"
    }
}
