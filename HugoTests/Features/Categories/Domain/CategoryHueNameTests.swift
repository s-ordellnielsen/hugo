import Testing

@testable import Hugo

struct CategoryHueNameTests {
    @Test(arguments: [
        (0.0, CategoryHueName.red),
        (0.03, .red),
        (0.04, .orange),
        (0.15, .yellow),
        (0.37, .green),
        (0.5, .teal),
        (0.6, .blue),
        (0.68, .blue),
        (0.78, .purple),
        (0.9, .pink),
        (0.96, .red),
        (1.0, .red),
    ])
    func hueMapsToItsName(hue: Double, expected: CategoryHueName) {
        #expect(CategoryHueName(hue: hue) == expected)
    }

    @Test
    func everyPresetHasTheExpectedName() {
        let names = Dictionary(
            uniqueKeysWithValues: CategoryColorPreset.all.map { ($0.id, CategoryHueName(hue: $0.color.hue)) })
        #expect(names["blue"] == .blue)
        #expect(names["indigo"] == .blue)
        #expect(names["purple"] == .purple)
        #expect(names["pink"] == .pink)
        #expect(names["orange"] == .orange)
        #expect(names["green"] == .green)
    }
}
