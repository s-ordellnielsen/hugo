import SwiftUI
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

    /// A marker without a label gives the layout only one subview. This used
    /// to crash (index out of range) in the Planner header whenever the plan
    /// went past the monthly target.
    @Test @MainActor
    func markerWithoutLabelRendersAtMarkerHeight() throws {
        let renderer = ImageRenderer(
            content: MarkedProgressBar(filled: 0.4, extended: 1, marker: 0.8).frame(width: 300))
        let image = try #require(renderer.uiImage)
        #expect(image.size.height == HugoLayout.Size.goalTrackHeight + 2 * HugoLayout.Spacing.tight)
    }

    @Test @MainActor
    func plannerBarPastTheTargetRenders() throws {
        let renderer = ImageRenderer(
            content: PlannerProgressBar(
                loggedSeconds: 10 * 3_600, stillPlannedSeconds: 20 * 3_600, targetSeconds: 25 * 3_600
            )
            .frame(width: 300))
        #expect(renderer.uiImage != nil)
    }
}
