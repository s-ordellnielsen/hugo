import Testing

@testable import Hugo

struct CategoryProgressColorTests {
    @Test
    func validChannelsArePreserved() {
        let color = CategoryProgressColor(hue: 0.25, saturation: 0.5, brightness: 0.75)
        #expect(color?.hue == 0.25)
        #expect(color?.saturation == 0.5)
        #expect(color?.brightness == 0.75)
    }

    @Test
    func zeroBrightnessMeansNoColor() {
        #expect(CategoryProgressColor(hue: 0.25, saturation: 0.5, brightness: 0) == nil)
    }

    @Test
    func outOfRangeChannelMeansNoColor() {
        #expect(CategoryProgressColor(hue: 1.5, saturation: 0.5, brightness: 0.5) == nil)
    }
}
