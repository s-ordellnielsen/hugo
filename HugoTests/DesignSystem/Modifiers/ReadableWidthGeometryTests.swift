import CoreGraphics
import Testing

@testable import Hugo

struct ReadableWidthGeometryTests {
    private let maxWidth: CGFloat = 672

    private func margins(
        width: CGFloat, leadingInset: CGFloat = 0, trailingInset: CGFloat = 0
    ) -> ReadableWidthGeometry.ListMargins? {
        ReadableWidthGeometry.listMargins(
            containerWidth: width, leadingInset: leadingInset, trailingInset: trailingInset,
            maxWidth: maxWidth)
    }

    @Test
    func phoneWidthKeepsSystemMargin() {
        #expect(margins(width: 393) == nil)
    }

    @Test
    func iPadPortraitWidensMargin() {
        #expect(margins(width: 834) == .init(leading: 81, trailing: 81))
    }

    @Test
    func largeIPadLandscapeWidensMargin() {
        #expect(margins(width: 1376) == .init(leading: 352, trailing: 352))
    }

    @Test
    func marginAtMinimumKeepsSystemMargin() {
        #expect(margins(width: 712) == nil)
    }

    @Test
    func marginJustAboveMinimumApplies() {
        #expect(margins(width: 714) == .init(leading: 21, trailing: 21))
    }

    @Test
    func nonFiniteWidthKeepsSystemMargin() {
        #expect(margins(width: .infinity) == nil)
    }

    @Test
    func sidebarShiftsColumnRight() {
        #expect(margins(width: 1210, leadingInset: 240) == .init(leading: 389, trailing: 149))
    }

    @Test
    func sidebarOnNarrowScreenKeepsSystemMargin() {
        #expect(margins(width: 834, leadingInset: 240) == nil)
    }

    @Test
    func trailingInsetIsKeptClear() {
        #expect(margins(width: 1210, trailingInset: 100) == .init(leading: 219, trailing: 319))
    }

    @Test
    func negativeInsetCountsAsZero() {
        #expect(margins(width: 834, leadingInset: -10) == .init(leading: 81, trailing: 81))
    }
}
