import CoreGraphics

/// Maps between a 0...1 value and a thumb position on a horizontal track.
/// The thumb's center stays a radius away from each end, so the whole thumb
/// stays on the track.
nonisolated struct GradientSliderGeometry: Equatable, Sendable {
    let trackWidth: CGFloat
    let thumbDiameter: CGFloat

    private var span: CGFloat { max(0, trackWidth - thumbDiameter) }

    /// The thumb center's x for `value` (clamped to 0...1).
    func thumbCenterX(for value: Double) -> CGFloat {
        let clamped = min(1, max(0, value.isFinite ? value : 0))
        return thumbDiameter / 2 + span * CGFloat(clamped)
    }

    /// The value for a touch at `x`, clamped to 0...1. On a track no wider
    /// than the thumb, returns 0.
    func value(forX x: CGFloat) -> Double {
        guard span > 0 else { return 0 }
        let raw = Double((x - thumbDiameter / 2) / span)
        return min(1, max(0, raw.isFinite ? raw : 0))
    }

    /// `value` moved by `step` and clamped to 0...1. If `wraps` is true it
    /// wraps around instead (for hue: 1 + 1/24 becomes 1/24).
    static func stepped(_ value: Double, by step: Double, wraps: Bool) -> Double {
        let next = value + step
        guard wraps else { return min(1, max(0, next)) }
        if next == 1 { return 1 }
        let wrapped = next.truncatingRemainder(dividingBy: 1)
        return wrapped < 0 ? wrapped + 1 : wrapped
    }
}
