import Foundation

/// What Hugo shows and emails when its data store can't open: the app
/// version, the build number and the error text.
nonisolated struct StoreLoadFailureReport: Equatable, Sendable {
    let errorDetails: String
    let appVersion: String
    let buildNumber: String

    /// The report for this app, with version and build read from `bundle`.
    static func current(errorDetails: String, bundle: Bundle = .main) -> StoreLoadFailureReport {
        StoreLoadFailureReport(
            errorDetails: errorDetails,
            appVersion: bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?",
            buildNumber: bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
        )
    }

    /// The text shown under Details and used as the email body.
    var text: String {
        "Hugo \(appVersion) (\(buildNumber))\n\n\(errorDetails)"
    }

    /// A `mailto:` URL with `subject` and `text` filled in, or nil when
    /// `email` is empty.
    func mailURL(to email: String, subject: String) -> URL? {
        guard !email.isEmpty else { return nil }
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = email
        components.queryItems = [
            URLQueryItem(name: "subject", value: subject),
            URLQueryItem(name: "body", value: text),
        ]
        return components.url
    }
}
