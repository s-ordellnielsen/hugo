import Testing

@testable import Hugo

struct CircleFillGeometryTests {
    @Test(arguments: [0.0, 0.5, 1.0])
    func endpointsAndMiddleMatch(fraction: Double) {
        #expect(abs(CircleFillGeometry.height(forAreaFraction: fraction) - fraction) < 1e-9)
    }

    @Test(arguments: [0.01, 0.05, 0.1, 0.25, 0.4, 0.6, 0.75, 0.9, 0.95, 0.99])
    func heightRoundTripsToArea(fraction: Double) {
        let height = CircleFillGeometry.height(forAreaFraction: fraction)
        #expect(abs(CircleFillGeometry.areaFraction(forHeight: height) - fraction) < 1e-6)
    }

    @Test
    func heightGrowsWithArea() {
        var previous = -1.0
        for step in 0...20 {
            let height = CircleFillGeometry.height(forAreaFraction: Double(step) / 20)
            #expect(height > previous)
            previous = height
        }
    }

    @Test
    func aQuarterOfTheAreaNeedsMoreThanAQuarterOfTheHeight() {
        let height = CircleFillGeometry.height(forAreaFraction: 0.25)
        #expect(height > 0.29 && height < 0.31)
    }

    @Test
    func outOfRangeValuesAreClamped() {
        #expect(CircleFillGeometry.height(forAreaFraction: -0.5) == 0)
        #expect(CircleFillGeometry.height(forAreaFraction: 1.5) == 1)
        #expect(CircleFillGeometry.height(forAreaFraction: .nan) == 0)
    }

    @Test(arguments: [0.1, 0.25, 0.5, 0.75, 0.9])
    func aFullWindowMatchesTheWholeCircle(fraction: Double) {
        let whole = CircleFillGeometry.height(forAreaFraction: fraction)
        let window = CircleFillGeometry.height(forVisibleAreaFraction: fraction, windowBottom: 0, windowHeight: 1)
        #expect(abs(whole - window) < 1e-3)
    }

    @Test
    func theMiddleOfACenteredWindowIsTheCenter() {
        let height = CircleFillGeometry.height(forVisibleAreaFraction: 0.5, windowBottom: 0.15, windowHeight: 0.7)
        #expect(abs(height - 0.5) < 1e-3)
    }

    @Test
    func theLevelStaysInsideTheWindow() {
        #expect(CircleFillGeometry.height(forVisibleAreaFraction: 0, windowBottom: 0.15, windowHeight: 0.7) == 0.15)
        #expect(
            abs(CircleFillGeometry.height(forVisibleAreaFraction: 1, windowBottom: 0.15, windowHeight: 0.7) - 0.85)
                < 1e-9)
        #expect(CircleFillGeometry.height(forVisibleAreaFraction: .nan, windowBottom: 0.15, windowHeight: 0.7) == 0.15)
    }

    @Test
    func theVisibleLevelGrowsWithTheFraction() {
        var previous = -1.0
        for step in 0...20 {
            let height = CircleFillGeometry.height(
                forVisibleAreaFraction: Double(step) / 20, windowBottom: 0.115, windowHeight: 0.77, windowLeft: 0.38)
            #expect(height > previous)
            previous = height
        }
    }

    @Test
    func clippingTheLeftSideLowersTheLevelBelowTheMiddle() {
        let open = CircleFillGeometry.height(forVisibleAreaFraction: 0.25, windowBottom: 0.115, windowHeight: 0.77)
        let clipped = CircleFillGeometry.height(
            forVisibleAreaFraction: 0.25, windowBottom: 0.115, windowHeight: 0.77, windowLeft: 0.38)
        #expect(open - clipped > 1e-3)
    }

    @Test
    func clippingTheLeftSideKeepsAHalfFilledCenteredWindowAtTheCenter() {
        let clipped = CircleFillGeometry.height(
            forVisibleAreaFraction: 0.5, windowBottom: 0.115, windowHeight: 0.77, windowLeft: 0.38)
        #expect(abs(clipped - 0.5) < 1e-3)
    }
}
