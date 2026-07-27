import Foundation
import Testing
@testable import Hugo

@MainActor
struct YearMonthTests {
    @Test
    func ordersMonthsAcrossYears() {
        #expect(YearMonth(year: 2025, month: 12) < YearMonth(year: 2026, month: 1))
        #expect(YearMonth(year: 2026, month: 1) > YearMonth(year: 2025, month: 12))
    }

    @Test
    func ordersMonthsWithinTheSameYear() {
        #expect(YearMonth(year: 2025, month: 2) < YearMonth(year: 2025, month: 9))
        #expect(YearMonth(year: 2025, month: 9) > YearMonth(year: 2025, month: 2))
        #expect(YearMonth(year: 2025, month: 9) == YearMonth(year: 2025, month: 9))
    }

    @Test
    func formatsSeptemberWithRequestedLocale() {
        let month = YearMonth(year: 2025, month: 9)
        #expect(month.monthYearString(locale: Locale(identifier: "en_US_POSIX")) == "September 2025")
    }
}
