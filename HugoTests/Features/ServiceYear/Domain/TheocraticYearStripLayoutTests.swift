import CoreGraphics
import Testing

@testable import Hugo

@MainActor
struct TheocraticYearStripLayoutTests {
    private let cellWidth: CGFloat = 64

    private func layout(_ startYears: ClosedRange<Int>) -> TheocraticYearStripLayout {
        TheocraticYearStripLayout(years: startYears.map(TheocraticYear.init(startYear:)), cellWidth: cellWidth)
    }

    private func year(_ startYear: Int) -> TheocraticYear {
        TheocraticYear(startYear: startYear)
    }

    @Test
    func listsEveryStartYearAndTheLastEndYear() {
        #expect(layout(2024...2026).calendarYears == [2024, 2025, 2026, 2027])
    }

    @Test
    func showsBothCalendarYearsOfASingleYear() {
        let single = layout(2026...2026)
        #expect(single.calendarYears == [2026, 2027])
        #expect(single.yearCount == 1)
    }

    @Test
    func acceptsYearsInAnyOrder() {
        let shuffled = TheocraticYearStripLayout(years: [year(2026), year(2024), year(2025)], cellWidth: cellWidth)
        #expect(shuffled.calendarYears == [2024, 2025, 2026, 2027])
    }

    @Test
    func showsTheBandAndOneYearOnEachSide() {
        let strip = layout(2024...2026)
        #expect(strip.stripWidth == 256)
        #expect(strip.edgePadding == 64)
    }

    @Test
    func placesEachYearOneCellFurther() {
        let strip = layout(2024...2026)
        #expect(strip.offset(for: year(2024)) == 0)
        #expect(strip.offset(for: year(2025)) == 64)
        #expect(strip.offset(for: year(2026)) == 128)
    }

    @Test
    func clampsOffsetsOfYearsOutsideTheStrip() {
        let strip = layout(2024...2026)
        #expect(strip.offset(for: year(2020)) == 0)
        #expect(strip.offset(for: year(2030)) == 128)
    }

    @Test
    func roundsAnOffsetToTheNearestYear() {
        let strip = layout(2024...2026)
        #expect(strip.year(forOffset: 31) == year(2024))
        #expect(strip.year(forOffset: 33) == year(2025))
        #expect(strip.year(forOffset: 100) == year(2026))
    }

    @Test
    func clampsOffsetsPastTheEnds() {
        let strip = layout(2024...2026)
        #expect(strip.year(forOffset: -40) == year(2024))
        #expect(strip.year(forOffset: 900) == year(2026))
    }

    @Test
    func snapsWhereAFlickWouldStopToAWholeYear() {
        let strip = layout(2024...2026)
        #expect(strip.snappedOffset(forProposedOffset: 90) == 64)
        #expect(strip.snappedOffset(forProposedOffset: 100) == 128)
        #expect(strip.snappedOffset(forProposedOffset: -20) == 0)
        #expect(strip.snappedOffset(forProposedOffset: 900) == 128)
    }

    @Test
    func endsTheScrollRangeWithTheLastYearInTheBand() {
        let strip = layout(2019...2026)
        let contentWidth = strip.edgePadding * 2 + strip.cellWidth * CGFloat(strip.calendarYears.count)
        #expect(contentWidth - strip.stripWidth == strip.offset(for: year(2026)))
    }

    @Test
    func emphasizesTheTwoYearsInTheBand() {
        let strip = layout(2024...2026)
        let dimmed = TheocraticYearStripLayout.dimmedEmphasis
        // The strip is 256 wide, so the band's cells are centered at 96 and 160.
        #expect(strip.emphasis(forCellMidX: 96) == 1)
        #expect(strip.emphasis(forCellMidX: 160) == 1)
        #expect(strip.emphasis(forCellMidX: 128) == 1)
        // The neighbouring cells are centered at 32 and 224.
        #expect(strip.emphasis(forCellMidX: 32) == dimmed)
        #expect(strip.emphasis(forCellMidX: 224) == dimmed)
        #expect(strip.emphasis(forCellMidX: -100) == dimmed)
        let halfway = strip.emphasis(forCellMidX: 64)
        #expect(abs(halfway - (1 + dimmed) / 2) < 0.0001)
    }

    @Test
    func closesWhenTappingAYearInTheBand() {
        let strip = layout(2022...2027)
        #expect(strip.tapAction(forCalendarYear: 2025, yearInBand: year(2025)) == .close)
        #expect(strip.tapAction(forCalendarYear: 2026, yearInBand: year(2025)) == .close)
    }

    @Test
    func makesAnEarlierTappedYearTheStartYear() {
        let strip = layout(2022...2027)
        #expect(strip.tapAction(forCalendarYear: 2024, yearInBand: year(2025)) == .select(year(2024)))
        #expect(strip.tapAction(forCalendarYear: 2022, yearInBand: year(2025)) == .select(year(2022)))
    }

    @Test
    func makesALaterTappedYearTheEndYear() {
        let strip = layout(2022...2027)
        #expect(strip.tapAction(forCalendarYear: 2027, yearInBand: year(2025)) == .select(year(2026)))
        #expect(strip.tapAction(forCalendarYear: 2028, yearInBand: year(2025)) == .select(year(2027)))
    }

    @Test
    func movesByAStepAndStopsAtTheEnds() {
        let strip = layout(2024...2026)
        #expect(strip.year(year(2025), movedBy: 1) == year(2026))
        #expect(strip.year(year(2025), movedBy: -1) == year(2024))
        #expect(strip.year(year(2026), movedBy: 1) == year(2026))
        #expect(strip.year(year(2024), movedBy: -1) == year(2024))
    }
}
