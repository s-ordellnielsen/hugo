import Foundation
import Testing
@testable import Hugo

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
    func localizedNameMatchesCaseInsensitively() {
        #expect(symbol.matches("PHONE", nil))
    }

    @Test
    func commaSeparatedKeywordMatches() {
        #expect(symbol.matches("call", nil))
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
