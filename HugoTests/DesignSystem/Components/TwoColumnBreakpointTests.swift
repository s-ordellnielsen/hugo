import CoreGraphics
import Testing

@testable import Hugo

struct TwoColumnBreakpointTests {
    private func usesTwoColumns(_ width: CGFloat, accessibility: Bool = false) -> Bool {
        TwoColumnBreakpoint.usesTwoColumns(
            availableWidth: width, minimumWidth: 880, isAccessibilitySize: accessibility)
    }

    @Test func phoneIsOneColumn() {
        #expect(!usesTwoColumns(361))
    }

    @Test func iPadPortraitIsOneColumn() {
        #expect(!usesTwoColumns(802))
    }

    @Test func exactlyMinimumIsTwoColumns() {
        #expect(usesTwoColumns(880))
    }

    @Test func iPadLandscapeIsTwoColumns() {
        #expect(usesTwoColumns(1178))
    }

    @Test func accessibilitySizeIsAlwaysOneColumn() {
        #expect(!usesTwoColumns(1178, accessibility: true))
    }

    @Test func nonFiniteWidthIsOneColumn() {
        #expect(!usesTwoColumns(.infinity))
    }
}
