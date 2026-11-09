import Foundation
import Testing

@testable import Hugo

struct CategoryColorTests {
    @Test
    func storedNilMeansAutomatic() {
        #expect(CategoryColor(storedHue: nil, storedTone: 0.5) == nil)
        #expect(CategoryColor(storedHue: 0.5, storedTone: nil) == nil)
        #expect(CategoryColor(storedHue: nil, storedTone: nil) == nil)
    }

    @Test
    func storedOutOfRangeOrNonFiniteMeansAutomatic() {
        #expect(CategoryColor(storedHue: 1.5, storedTone: 0.5) == nil)
        #expect(CategoryColor(storedHue: 0.5, storedTone: -0.1) == nil)
        #expect(CategoryColor(storedHue: .nan, storedTone: 0.5) == nil)
    }

    @Test
    func clampingInitializerClamps() {
        let clamped = CategoryColor(hue: 1.4, tone: -1)
        #expect(clamped.hue == 1)
        #expect(clamped.tone == 0)

        let nonFinite = CategoryColor(hue: .nan, tone: .infinity)
        #expect(nonFinite.hue == 0)
        #expect(nonFinite.tone == 0)
    }

    @Test
    func blueMatchesTheFormulaInBothAppearances() {
        let blue = CategoryColor(hue: 0.60, tone: 0.55)

        let light = blue.components(for: .light)
        #expect(abs(light.hue - 0.60) < 1e-9)
        #expect(abs(light.saturation - 0.7825) < 1e-9)
        #expect(abs(light.brightness - 0.689) < 1e-9)

        let dark = blue.components(for: .dark)
        #expect(abs(dark.hue - 0.60) < 1e-9)
        #expect(abs(dark.saturation - 0.494) < 1e-9)
        #expect(abs(dark.brightness - 0.945) < 1e-9)
    }

    @Test
    func lightToneDeepensAndDarkToneSaturates() {
        let lightest = CategoryColor(hue: 0.6, tone: 0).components(for: .light)
        let deepest = CategoryColor(hue: 0.6, tone: 1).components(for: .light)
        #expect(lightest.brightness > deepest.brightness)

        let dullest = CategoryColor(hue: 0.6, tone: 0).components(for: .dark)
        let vividest = CategoryColor(hue: 0.6, tone: 1).components(for: .dark)
        #expect(dullest.saturation < vividest.saturation)
    }

    @Test
    func faintYellowIsDarkenedInLightMode() {
        let yellow = CategoryColor(hue: 0.15, tone: 0).components(for: .light)
        #expect(yellow.brightness < 0.92)
    }

    @Test
    func everyColorMeetsTheContrastFloor() {
        for hueIndex in 0..<48 {
            for toneIndex in 0...10 {
                let color = CategoryColor(hue: Double(hueIndex) / 48.0, tone: Double(toneIndex) / 10.0)

                let light = color.components(for: .light)
                let lightRGB = CategoryColor.rgb(light)
                let lightLuminance = CategoryColor.relativeLuminance(
                    red: lightRGB.red, green: lightRGB.green, blue: lightRGB.blue)
                for background in CategoryColor.lightBackgrounds {
                    let ratio = CategoryColor.contrastRatio(lightLuminance, background)
                    #expect(ratio >= CategoryColor.minimumContrast - 1e-9)
                }

                let dark = color.components(for: .dark)
                let darkRGB = CategoryColor.rgb(dark)
                let darkLuminance = CategoryColor.relativeLuminance(
                    red: darkRGB.red, green: darkRGB.green, blue: darkRGB.blue)
                for background in CategoryColor.darkBackgrounds {
                    let ratio = CategoryColor.contrastRatio(darkLuminance, background)
                    #expect(ratio >= CategoryColor.minimumContrast - 1e-9)
                }
            }
        }
    }
}
