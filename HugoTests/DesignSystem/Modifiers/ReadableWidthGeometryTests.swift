import CoreGraphics
import Testing

@testable import Hugo

struct ReadableWidthGeometryTests {
    private let maxWidth: CGFloat = 672

    @Test
    func phoneWidthKeepsSystemMargin() {
        #expect(ReadableWidthGeometry.listMargin(containerWidth: 393, maxWidth: maxWidth) == nil)
    }

    @Test
    func iPadPortraitWidensMargin() {
        #expect(ReadableWidthGeometry.listMargin(containerWidth: 834, maxWidth: maxWidth) == 81)
    }

    @Test
    func largeIPadLandscapeWidensMargin() {
        #expect(ReadableWidthGeometry.listMargin(containerWidth: 1376, maxWidth: maxWidth) == 352)
    }

    @Test
    func marginAtMinimumKeepsSystemMargin() {
        #expect(ReadableWidthGeometry.listMargin(containerWidth: 712, maxWidth: maxWidth) == nil)
    }

    @Test
    func marginJustAboveMinimumApplies() {
        #expect(ReadableWidthGeometry.listMargin(containerWidth: 714, maxWidth: maxWidth) == 21)
    }

    @Test
    func nonFiniteWidthKeepsSystemMargin() {
        #expect(ReadableWidthGeometry.listMargin(containerWidth: .infinity, maxWidth: maxWidth) == nil)
    }
}
