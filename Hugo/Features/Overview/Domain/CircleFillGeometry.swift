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
}
