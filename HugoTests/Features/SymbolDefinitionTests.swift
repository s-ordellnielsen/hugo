import Foundation
import Testing

@testable import Hugo

@MainActor
struct SymbolDefinitionTests {
    private let symbol = SymbolDefinition(
        icon: "phone.fill",
        name: "symbol.phone",
        keywordsKey: "symbol.phone.keywords",
        attributes: [.fill]
    )

    @Test
    func emptyQueryMatchesWhenNoAttributeIsRequired() {
        #expect(symbol.matches("", nil))
    }

    @Test
    func localizedNameMatchesWithDifferentCasing() {
        let localizedName = String(localized: symbol.name)
        let differentlyCasedName = localizedName.uppercased()

        #expect(symbol.matches(differentlyCasedName, nil))
    }

    @Test
    func commaSeparatedKeywordMatches() {
        let keywords = String(localized: symbol.keywordsKey)
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }

        #expect(symbol.matches(String(keywords[1]), nil))
    }

    @Test
    func absentRequiredAttributeDoesNotMatch() {
        #expect(!symbol.matches("phone", .cropped))
    }

    @Test
    func attributeOnlyFilterMatchesExistingAttribute() {
        #expect(symbol.matches("", .fill))
    }
}
