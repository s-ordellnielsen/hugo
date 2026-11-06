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
}
