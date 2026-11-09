import CoreGraphics
import Foundation
import Testing

@testable import Hugo

struct GradientSliderGeometryTests {
    private let geometry = GradientSliderGeometry(trackWidth: 200, thumbDiameter: 36)

    @Test
    func thumbStaysOnTrack() {
        #expect(geometry.thumbCenterX(for: 0) == 18)
        #expect(geometry.thumbCenterX(for: 1) == 182)
        #expect(geometry.thumbCenterX(for: 0.5) == 100)
    }

    @Test
    func touchMapsToValueAndClamps() {
        #expect(geometry.value(forX: 18) == 0)
        #expect(geometry.value(forX: 182) == 1)
        #expect(geometry.value(forX: 100) == 0.5)
        #expect(geometry.value(forX: -50) == 0)
        #expect(geometry.value(forX: 500) == 1)
    }

    @Test
    func narrowTrackReturnsZero() {
        let narrow = GradientSliderGeometry(trackWidth: 30, thumbDiameter: 36)
        for x: CGFloat in [-10, 0, 15, 30, 100] {
            #expect(narrow.value(forX: x) == 0)
        }
    }

    @Test
    func steppingClamps() {
        #expect(GradientSliderGeometry.stepped(0.95, by: 0.1, wraps: false) == 1)
        #expect(GradientSliderGeometry.stepped(0.05, by: -0.1, wraps: false) == 0)
    }

    @Test
    func steppingWrapsForHue() {
        let up = GradientSliderGeometry.stepped(1.0, by: 1.0 / 24, wraps: true)
        #expect(abs(up - 1.0 / 24) < 1e-9)
        let down = GradientSliderGeometry.stepped(0, by: -1.0 / 24, wraps: true)
        #expect(abs(down - 23.0 / 24) < 1e-9)
    }
}
