import SwiftUI
import Testing

@testable import Hugo

/// The "by date" rows touch and are shorter than the 44 pt minimum at the
/// default text size, so the day cards stay compact (SLN-302).
@MainActor
struct OverviewDateListLayoutTests {
    @Test
    func entryRowsAreCompact() throws {
        let one = try renderedHeight(entryCount: 1)
        let three = try renderedHeight(entryCount: 3)
        let rowPitch = (three - one) / 2

        #expect(rowPitch < HugoLayout.Size.minimumHitTarget)
        #expect(rowPitch >= 30)
    }

    /// Height of one day card holding `entryCount` entries.
    private func renderedHeight(entryCount: Int) throws -> CGFloat {
        let start = Calendar.current.startOfDay(for: .now)
        let entries = (0..<entryCount).map { index in
            Entry(date: start.addingTimeInterval(TimeInterval(9 + index) * 3_600), duration: 1_800, tracker: nil)
        }
        let renderer = ImageRenderer(
            content: VStack { OverviewDateList(entries: entries, selectedEntry: .constant(nil)) }
                .frame(width: 390))
        let image = try #require(renderer.uiImage)
        return image.size.height
    }
}
