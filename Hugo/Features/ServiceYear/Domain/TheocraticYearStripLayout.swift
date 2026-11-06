import CoreGraphics

/// What a tap on a year in the theocratic year picker strip does.
nonisolated enum TheocraticYearStripTapAction: Equatable, Sendable {
    /// Put this theocratic year in the band.
    case select(TheocraticYear)
    /// The tapped year is already in the band: close the picker.
    case close
}

/// The geometry of the theocratic year picker strip.
///
/// The strip shows one cell per calendar year. The two calendar years of the
/// selected theocratic year sit side by side in a band in the middle, for
/// example `2025 [2026 / 2027] 2028`. The content offset `index * cellWidth`
/// puts the theocratic year at `index` (counting from the first year) in the band.
nonisolated struct TheocraticYearStripLayout: Equatable, Sendable {
    /// The opacity of years outside the band.
    static let dimmedEmphasis = 0.4

    /// The oldest theocratic year in the strip.
    let firstYear: TheocraticYear
    /// The newest theocratic year in the strip.
    let lastYear: TheocraticYear
    let cellWidth: CGFloat
    /// The visible width: the band (two cells) and one and a half cells on each
    /// side, so the next years peek in at the edges. Never wider than the
    /// caller's maximum and never narrower than the band.
    let stripWidth: CGFloat

    /// `years` is the pager's list of years, which has no gaps. An empty list
    /// gives a strip with a single year; callers show the picker only with two
    /// or more years.
    init(years: [TheocraticYear], cellWidth: CGFloat, maximumStripWidth: CGFloat = .infinity) {
        let fallback = TheocraticYear(startYear: 0)
        self.firstYear = years.min() ?? fallback
        self.lastYear = years.max() ?? fallback
        self.cellWidth = cellWidth
        self.stripWidth = max(cellWidth * 2, min(cellWidth * 5, maximumStripWidth))
    }

    /// The number of theocratic years the strip can put in the band.
    var yearCount: Int {
        lastYear.startYear - firstYear.startYear + 1
    }

    /// Every start year, plus the end year of the last theocratic year.
    var calendarYears: [Int] {
        Array(firstYear.startYear...(lastYear.startYear + 1))
    }

    /// Space before the first cell and after the last: what the strip shows
    /// beside the band. With it, the scroll range is exactly the offsets that
    /// put a theocratic year in the band.
    var edgePadding: CGFloat {
        (stripWidth - cellWidth * 2) / 2
    }

    /// The content offset that puts `year` in the band. Years outside the strip are clamped.
    func offset(for year: TheocraticYear) -> CGFloat {
        CGFloat(index(of: year)) * cellWidth
    }

    /// The theocratic year in the band at a content offset, rounded to the nearest year.
    func year(forOffset offset: CGFloat) -> TheocraticYear {
        guard cellWidth > 0 else { return firstYear }
        let index = Int((offset / cellWidth).rounded())
        return year(atIndex: index)
    }

    /// The nearest offset that puts a whole theocratic year in the band.
    func snappedOffset(forProposedOffset offset: CGFloat) -> CGFloat {
        self.offset(for: year(forOffset: offset))
    }

    /// The theocratic year `step` years after `year` (before it when negative),
    /// stopping at the first and last year.
    func year(_ year: TheocraticYear, movedBy step: Int) -> TheocraticYear {
        self.year(atIndex: index(of: year) + step)
    }

    /// The opacity for a cell whose center is at `midX` in the strip's visible
    /// coordinates: 1 inside the band, falling to `dimmedEmphasis` at the
    /// neighbouring cells' centers.
    func emphasis(forCellMidX midX: CGFloat) -> Double {
        guard cellWidth > 0 else { return 1 }
        let distance = abs(midX - stripWidth / 2)
        // 0 at the centers of the band's two cells, 1 at the centers of their neighbours.
        let fade = Double((distance - cellWidth / 2) / cellWidth)
        guard fade > 0 else { return 1 }
        guard fade < 1 else { return Self.dimmedEmphasis }
        return 1 - (1 - Self.dimmedEmphasis) * fade
    }

    /// What tapping `calendarYear` does while `yearInBand` is in the band.
    func tapAction(forCalendarYear calendarYear: Int, yearInBand: TheocraticYear) -> TheocraticYearStripTapAction {
        if calendarYear < yearInBand.startYear {
            return .select(year(atIndex: calendarYear - firstYear.startYear))
        }
        if calendarYear > yearInBand.startYear + 1 {
            return .select(year(atIndex: calendarYear - 1 - firstYear.startYear))
        }
        return .close
    }

    private func index(of year: TheocraticYear) -> Int {
        min(max(year.startYear - firstYear.startYear, 0), yearCount - 1)
    }

    private func year(atIndex index: Int) -> TheocraticYear {
        let clamped = min(max(index, 0), yearCount - 1)
        return TheocraticYear(startYear: firstYear.startYear + clamped)
    }
}
