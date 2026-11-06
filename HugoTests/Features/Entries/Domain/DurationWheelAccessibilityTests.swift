import Foundation
import Testing

@testable import Hugo

struct DurationWheelAccessibilityTests {
    private let english = Locale(identifier: "en_US")
    private let danish = Locale(identifier: "da_DK")

    @Test
    func hoursCarryTheirUnitInEnglish() {
        #expect(DurationWheelAccessibility.hoursLabel(0, locale: english) == "0 hours")
        #expect(DurationWheelAccessibility.hoursLabel(1, locale: english) == "1 hour")
        #expect(DurationWheelAccessibility.hoursLabel(2, locale: english) == "2 hours")
    }

    @Test
    func minutesCarryTheirUnitInEnglish() {
        #expect(DurationWheelAccessibility.minutesLabel(0, locale: english) == "0 minutes")
        #expect(DurationWheelAccessibility.minutesLabel(1, locale: english) == "1 minute")
        #expect(DurationWheelAccessibility.minutesLabel(30, locale: english) == "30 minutes")
    }

    @Test
    func unitsAreDanishInDanish() {
        let oneHour = DurationWheelAccessibility.hoursLabel(1, locale: danish)
        let twoHours = DurationWheelAccessibility.hoursLabel(2, locale: danish)
        let thirtyMinutes = DurationWheelAccessibility.minutesLabel(30, locale: danish)
        #expect(oneHour.hasPrefix("1") && oneHour.hasSuffix("time"))
        #expect(twoHours.hasPrefix("2") && twoHours.hasSuffix("timer"))
        #expect(thirtyMinutes.hasPrefix("30") && thirtyMinutes.hasSuffix("minutter"))
    }
}
