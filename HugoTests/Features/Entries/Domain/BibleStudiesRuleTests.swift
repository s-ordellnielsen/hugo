import Testing

@testable import Hugo

struct BibleStudiesRuleTests {
    @Test
    func allowedCategoryAlwaysShowsTheControl() {
        #expect(BibleStudiesRule.showsControl(categoryAllows: true, count: 0))
        #expect(BibleStudiesRule.showsControl(categoryAllows: true, count: 2))
    }

    @Test
    func disallowedCategoryHidesTheControlOnlyWithoutStudies() {
        #expect(!BibleStudiesRule.showsControl(categoryAllows: false, count: 0))
        #expect(BibleStudiesRule.showsControl(categoryAllows: false, count: 1))
    }

    @Test
    func savedCountIsZeroWhenTheCategoryTurnsStudiesOff() {
        #expect(BibleStudiesRule.savedCount(3, categoryAllows: true) == 3)
        #expect(BibleStudiesRule.savedCount(3, categoryAllows: false) == 0)
        #expect(BibleStudiesRule.savedCount(-1, categoryAllows: true) == 0)
    }
}
