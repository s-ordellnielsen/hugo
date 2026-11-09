import Foundation
import Testing

@testable import Hugo

struct CategoryColorPresetTests {
    private var blue: CategoryColor { CategoryColorPreset.all[0].color }

    @Test
    func presetsHaveUniqueIDsAndColors() {
        let presets = CategoryColorPreset.all
        #expect(presets.count == 6)
        #expect(Set(presets.map(\.id)).count == presets.count)
        #expect(Set(presets.map(\.color)).count == presets.count)
    }

    @Test
    func matchingFindsPresetWithinTolerance() {
        #expect(CategoryColorPreset.matching(CategoryColor(hue: 0.6004, tone: 0.5496))?.id == "blue")
        #expect(CategoryColorPreset.matching(CategoryColor(hue: 0.5, tone: 0.5)) == nil)
        #expect(CategoryColorPreset.matching(nil) == nil)
    }

    @Test
    func suggestionPicksFirstUnusedPreset() {
        let indigo = CategoryColorPreset.all[1].color
        #expect(CategoryColorPreset.suggested(forNewCategoryAmong: [nil, blue]) == indigo)
        #expect(CategoryColorPreset.suggested(forNewCategoryAmong: []) == blue)
    }

    @Test
    func suggestionCyclesWhenAllAreUsed() {
        let indigo = CategoryColorPreset.all[1].color
        let existing: [CategoryColor?] = CategoryColorPreset.all.map(\.color) + [blue]
        #expect(CategoryColorPreset.suggested(forNewCategoryAmong: existing) == indigo)
    }

    @Test
    func suggestionIgnoresCustomColors() {
        let custom = CategoryColor(hue: 0.5, tone: 0.5)
        #expect(CategoryColorPreset.suggested(forNewCategoryAmong: [custom]) == blue)
    }
}
