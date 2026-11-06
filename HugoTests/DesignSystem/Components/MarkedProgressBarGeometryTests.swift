import Foundation
import Testing

@testable import Hugo

struct MarkedProgressBarGeometryTests {
    @Test
    func zeroHasNoFillAndTinyPositiveFractionsStayWithinTheTrack() throws {
        let zero = MarkedProgressBarGeometry(width: 100, trackHeight: 12, filled: 0)
        #expect(zero.fillCapsuleIsEmpty(for: 0))

        for fraction in [0.001, 0.01] {
            let geometry = MarkedProgressBarGeometry(width: 100, trackHeight: 12, filled: fraction)
            let origin = geometry.fillCapsuleOrigin(for: fraction)
            let end = origin + geometry.fillCapsuleLength(for: fraction)
            #expect(origin < 0)
            #expect(abs(end - 100 * fraction) < 0.000_001)
            #expect(end > 0)
            let visibleRange = try #require(geometry.visibleFillRange(for: fraction))
            #expect(visibleRange.lowerBound >= 0)
            #expect(visibleRange.upperBound <= geometry.width)
            #expect(abs(visibleRange.upperBound - end) < 0.000_001)
            #expect(geometry.fillContains(x: end - 0.05, y: 6, fraction: fraction))
            #expect(!geometry.fillContains(x: end + 0.05, y: 6, fraction: fraction))
            #expect(!geometry.fillContains(x: -0.05, y: 6, fraction: fraction))
        }
    }

    @Test(arguments: [0.1, 0.5, 1.0])
    func ordinaryAndFullFillsEndAtTheirFraction(_ fraction: Double) {
        let geometry = MarkedProgressBarGeometry(width: 120, trackHeight: 12, filled: fraction)
        #expect(geometry.fillCapsuleOrigin(for: fraction) + geometry.fillCapsuleLength(for: fraction) == 120 * fraction)
        #expect(!geometry.fillCapsuleIsEmpty(for: fraction))
    }

    @Test(arguments: [-1.0, 1.5, -.infinity, .infinity, .nan])
    func invalidAndOutOfRangeFractionsNormalizeWithoutInvalidDimensions(_ input: Double) {
        let geometry = MarkedProgressBarGeometry(width: 0, trackHeight: 12, filled: input, extended: input)
        #expect(geometry.filled >= 0 && geometry.filled <= 1)
        #expect(geometry.extended >= geometry.filled && geometry.extended <= 1)
        #expect(geometry.fillCapsuleLength(for: input) >= 0)
        #expect(geometry.fillCapsuleIsEmpty(for: input))
    }

    @Test
    func extensionNeverEndsBeforeSolidDuringInterpolatedSamples() {
        for step in 0...100 {
            let progress = Double(step) / 100
            let filled = 0.1 + (0.8 - 0.1) * progress
            let extended = 0.8 + (0.1 - 0.8) * progress
            let geometry = MarkedProgressBarGeometry(
                width: 200,
                trackHeight: 12,
                filled: filled,
                extended: extended
            )
            #expect(geometry.extended >= geometry.filled)
            #expect(geometry.extendedEnd >= geometry.filledEnd)
        }
    }

    @Test
    func rightToLeftKeepsTheLogicalLeadingEndAtTheTrailingEdge() throws {
        let geometry = MarkedProgressBarGeometry(
            width: 100,
            trackHeight: 12,
            filled: 0.01,
            marker: 0.25,
            isRightToLeft: true
        )
        let range = try #require(geometry.visibleFillRange(for: geometry.filled))
        #expect(range.lowerBound > 80)
        #expect(range.upperBound == 100)
        #expect(geometry.markerCenter == 75)
    }

    @Test(arguments: [0.0, 0.5, 1.0])
    func markerCenterKeepsItsWidthInsideBounds(_ fraction: Double) throws {
        let geometry = MarkedProgressBarGeometry(width: 100, trackHeight: 12, filled: 0, marker: fraction)
        let center = try #require(geometry.markerCenter)
        #expect(center >= geometry.markerWidth / 2)
        #expect(center <= 100 - geometry.markerWidth / 2)
    }

    @Test
    func normalizedFractionsClampNonFiniteAndOutOfRangeValues() {
        let geometry = MarkedProgressBarGeometry(
            width: 100,
            trackHeight: 12,
            filled: -0.5,
            extended: 2,
            marker: .infinity
        )
        #expect(geometry.filled == 0)
        #expect(geometry.extended == 1)
        #expect(geometry.marker == 1)
    }
}
