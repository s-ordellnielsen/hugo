import Foundation

/// Converts between the share of a circle's area that is filled from the
/// bottom and the height the fill reaches. Both are fractions: 0 is empty,
/// 1 is full, and height is measured as a share of the diameter.
nonisolated enum CircleFillGeometry {
    /// Share of the area below `height`. A circular segment of height h in a
    /// circle of radius r has area r²·acos((r−h)/r) − (r−h)·√(2rh−h²). With
    /// r = 1/2 and x = 1 − 2h, dividing by the circle's area πr² gives
    /// (acos(x) − x·√(1−x²)) / π.
    static func areaFraction(forHeight height: Double) -> Double {
        let h = min(max(height, 0), 1)
        let x = 1 - 2 * h
        return (acos(x) - x * (1 - x * x).squareRoot()) / .pi
    }

    /// The height whose fill covers `area` of the circle. The inverse of
    /// `areaFraction(forHeight:)`, found by bisection because it has no
    /// closed form. Values outside 0...1 are clamped; NaN counts as 0.
    static func height(forAreaFraction area: Double) -> Double {
        guard area.isFinite else { return area == .infinity ? 1 : 0 }
        let target = min(max(area, 0), 1)
        if target == 0 || target == 1 { return target }
        var low = 0.0
        var high = 1.0
        for _ in 0..<60 {
            let middle = (low + high) / 2
            if areaFraction(forHeight: middle) < target {
                low = middle
            } else {
                high = middle
            }
        }
        return (low + high) / 2
    }

    /// The fill height for a circle that is only partly in view. The circle has diameter 1, and the window
    /// is the part you can see: from `windowBottom` up by `windowHeight`, and from `windowLeft` to the right.
    /// All three are shares of the diameter. `area` is the share of the visible part that is filled, and the
    /// result is the water level measured from the circle's bottom, so it is never below `windowBottom` or
    /// above `windowBottom + windowHeight`. Found by summing thin horizontal slices of the visible part.
    static func height(
        forVisibleAreaFraction area: Double, windowBottom: Double, windowHeight: Double, windowLeft: Double = 0
    ) -> Double {
        let bottom = min(max(windowBottom, 0), 1)
        let top = min(bottom + max(windowHeight, 0), 1)
        guard area.isFinite else { return area == .infinity ? top : bottom }
        let target = min(max(area, 0), 1)
        guard top > bottom, target > 0 else { return bottom }
        if target >= 1 { return top }

        let slices = 400
        let step = (top - bottom) / Double(slices)
        var widths: [Double] = []
        widths.reserveCapacity(slices)
        var total = 0.0
        for index in 0..<slices {
            let y = bottom + (Double(index) + 0.5) * step
            let offset = y - 0.5
            let half = max(0, 0.25 - offset * offset).squareRoot()
            let width = max(0, 0.5 + half - max(0.5 - half, windowLeft)) * step
            widths.append(width)
            total += width
        }
        guard total > 0 else { return bottom }

        let goal = target * total
        var filled = 0.0
        for (index, width) in widths.enumerated() {
            if filled + width >= goal {
                let share = width > 0 ? (goal - filled) / width : 0
                return bottom + (Double(index) + share) * step
            }
            filled += width
        }
        return top
    }
}
