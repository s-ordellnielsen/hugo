import Foundation

/// Normalized geometry shared by the marked progress bar's drawing and tests.
nonisolated struct MarkedProgressBarGeometry: Equatable, Sendable {
    let width: Double
    let trackHeight: Double
    let markerWidth: Double
    let isRightToLeft: Bool
    let filled: Double
    let extended: Double
    let marker: Double?

    init(
        width: Double,
        trackHeight: Double,
        markerWidth: Double = 2,
        filled: Double,
        extended: Double? = nil,
        marker: Double? = nil,
        isRightToLeft: Bool = false
    ) {
        self.width = max(0, width.isFinite ? width : 0)
        self.trackHeight = max(0, trackHeight.isFinite ? trackHeight : 0)
        self.markerWidth = max(0, markerWidth.isFinite ? markerWidth : 0)
        self.isRightToLeft = isRightToLeft
        self.filled = Self.normalized(filled)
        self.extended = max(self.filled, Self.normalized(extended ?? filled))
        self.marker = marker.map(Self.normalized)
    }

    var filledEnd: Double { width * filled }
    var extendedEnd: Double { width * extended }

    var markerCenter: Double? {
        guard let marker else { return nil }
        let halfMarker = min(markerWidth / 2, width / 2)
        let logicalPosition = width * marker
        let position = isRightToLeft ? width - logicalPosition : logicalPosition
        return min(max(position, halfMarker), width - halfMarker)
    }

    func fillCapsuleOrigin(for fraction: Double) -> Double {
        let end = width * Self.normalized(fraction)
        let length = max(end, trackHeight)
        return isRightToLeft ? width - end : end - length
    }

    func fillCapsuleLength(for fraction: Double) -> Double {
        let end = width * Self.normalized(fraction)
        return max(end, trackHeight)
    }

    func visibleFillRange(for fraction: Double) -> ClosedRange<Double>? {
        guard !fillCapsuleIsEmpty(for: fraction) else { return nil }
        let origin = fillCapsuleOrigin(for: fraction)
        let end = origin + fillCapsuleLength(for: fraction)
        let visibleStart = max(origin, 0)
        let visibleEnd = min(end, width)
        guard visibleStart <= visibleEnd else { return nil }
        return visibleStart...visibleEnd
    }

    func fillCapsuleIsEmpty(for fraction: Double) -> Bool {
        Self.normalized(fraction) == 0 || width == 0 || trackHeight == 0
    }

    func fillContains(x: Double, y: Double, fraction: Double) -> Bool {
        guard x.isFinite, y.isFinite, !fillCapsuleIsEmpty(for: fraction) else { return false }

        let radius = min(trackHeight / 2, width / 2)
        guard y >= 0, y <= trackHeight else { return false }
        let trackCenterX = min(max(x, radius), width - radius)
        guard squaredDistance(x, y, centerX: trackCenterX, centerY: radius) <= radius * radius else {
            return false
        }

        let origin = fillCapsuleOrigin(for: fraction)
        let length = fillCapsuleLength(for: fraction)
        let fillRadius = min(trackHeight / 2, length / 2)
        let fillCenterX = min(max(x, origin + fillRadius), origin + length - fillRadius)
        return squaredDistance(x, y, centerX: fillCenterX, centerY: trackHeight / 2) <= fillRadius * fillRadius
    }

    private func squaredDistance(_ x: Double, _ y: Double, centerX: Double, centerY: Double) -> Double {
        let dx = x - centerX
        let dy = y - centerY
        return dx * dx + dy * dy
    }

    private static func normalized(_ value: Double) -> Double {
        guard value.isFinite else { return value == .infinity ? 1 : 0 }
        return min(max(value, 0), 1)
    }
}
