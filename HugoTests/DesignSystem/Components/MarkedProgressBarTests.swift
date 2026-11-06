import Testing

@testable import Hugo

struct MarkedProgressBarTests {
    @Test
    func interpolatedFillStaysClampedAndExtensionNeverMovesBehindSolidFill() {
        for step in 0...100 {
            let progress = Double(step) / 100
            let filled = 0.1 + (0.8 - 0.1) * progress
            let extended = 0.8 + (0.1 - 0.8) * progress
            let geometry = MarkedProgressBarGeometry(
                width: 160,
                trackHeight: 12,
                filled: filled,
                extended: extended
            )

            #expect(geometry.filled >= 0 && geometry.filled <= 1)
            #expect(geometry.extended >= geometry.filled && geometry.extended <= 1)
        }
    }
}
