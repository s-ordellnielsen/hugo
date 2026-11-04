import Foundation
import Testing

@testable import Hugo

struct PlannerHoursTextTests {
    private let locale = Locale(identifier: "en_US")

    @Test
    func wholeHoursDropTheMinutes() {
        #expect(PlannerHoursText.short(7_200, locale: locale) == "2h")
    }

    @Test
    func hoursAndMinutesAreBothShown() {
        #expect(PlannerHoursText.short(5_400, locale: locale) == "1h 30m")
    }

    @Test
    func underAnHourShowsMinutesOnly() {
        #expect(PlannerHoursText.short(2_700, locale: locale) == "45m")
    }

    @Test
    func secondsAreDropped() {
        #expect(PlannerHoursText.short(5_430, locale: locale) == "1h 30m")
    }
}
