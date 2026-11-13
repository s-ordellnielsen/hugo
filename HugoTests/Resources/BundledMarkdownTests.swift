import Foundation
import Testing

/// Every Markdown page that `HelpView` shows must ship in English (Base) and
/// Danish. A missing file makes the sheet show "Unavailable".
struct BundledMarkdownTests {
    @Test(arguments: ["RoundingRule", "PrivacyPolicy", "TermsOfUse"])
    func pageShipsInEnglishAndDanish(name: String) throws {
        for localization in ["Base", "da"] {
            let url = try #require(
                Bundle.main.url(
                    forResource: name, withExtension: "md", subdirectory: nil, localization: localization),
                "\(name).md is missing for \(localization)")
            let text = try String(contentsOf: url, encoding: .utf8)
            #expect(text.hasPrefix("# "))
            #expect(!text.contains("!["), "\(name).md must not load images")
        }
    }

    @Test(arguments: ["Base", "da"])
    func privacyPolicyNamesItsPublishedCopy(localization: String) throws {
        let url = try #require(
            Bundle.main.url(
                forResource: "PrivacyPolicy", withExtension: "md", subdirectory: nil,
                localization: localization))
        let text = try String(contentsOf: url, encoding: .utf8)
        #expect(text.contains("https://hugo.ordellnielsen.com/privacy"))
        #expect(text.contains("app@ordellnielsen.com"))
    }

    @Test(arguments: ["Base", "da"])
    func termsPointToAppleEULAAndThePrivacyPolicy(localization: String) throws {
        let url = try #require(
            Bundle.main.url(
                forResource: "TermsOfUse", withExtension: "md", subdirectory: nil,
                localization: localization))
        let text = try String(contentsOf: url, encoding: .utf8)
        #expect(text.contains("https://www.apple.com/legal/internet-services/itunes/dev/stdeula/"))
        #expect(text.contains("https://hugo.ordellnielsen.com/privacy"))
        #expect(text.contains("JW.org"))
    }
}
