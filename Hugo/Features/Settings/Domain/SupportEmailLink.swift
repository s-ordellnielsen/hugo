import Foundation

/// Builds the `mailto:` link behind Settings' Contact Us button.
nonisolated enum SupportEmailLink {
    /// A `mailto:` URL for `address` with `subject` filled in, or nil when
    /// there is no address.
    static func url(address: String, subject: String) -> URL? {
        guard !address.isEmpty else { return nil }
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = address
        components.queryItems = [URLQueryItem(name: "subject", value: subject)]
        return components.url
    }
}
