import Foundation
import Testing
@testable import Hugo

struct RoundingRuleTests {
    @Test
    func exposesAllCasesWithStableIdentities() {
        #expect(RoundingRule.allCases == [.up, .down, .transfer])
        #expect(RoundingRule.allCases.map(\.id) == ["up", "down", "transfer"])
    }

    @Test
    func mapsEachCaseToItsLocalizationKey() {
        #expect(RoundingRule.up.nameKey == "rounding-rule.up")
        #expect(RoundingRule.down.nameKey == "rounding-rule.down")
        #expect(RoundingRule.transfer.nameKey == "rounding-rule.transfer")
    }

    @Test
    func rawValuesRoundTripThroughCodable() throws {
        let encoded = try JSONEncoder().encode(RoundingRule.transfer)
        #expect(String(data: encoded, encoding: .utf8) == "\"transfer\"")
        #expect(try JSONDecoder().decode(RoundingRule.self, from: encoded) == .transfer)
    }
}
