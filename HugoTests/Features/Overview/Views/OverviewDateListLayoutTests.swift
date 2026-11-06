import SwiftUI
import Testing

@testable import Hugo

/// The "by date" rows touch and sit as close together as before SLN-294
/// (one line of text plus 6 pt), so the day cards stay compact.
@MainActor
struct OverviewDateListLayoutTests {
    @Test
    func entryRowsAreCompact() throws {
        let one = try renderedHeight(entryCount: 1)
        let three = try renderedHeight(entryCount: 3)
        let rowPitch = (three - one) / 2

        // Same spacing as before SLN-294: one line of text plus 6 pt, all of it tappable.
        #expect(rowPitch < 32)
        #expect(rowPitch >= 24)
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
