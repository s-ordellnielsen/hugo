import Foundation
import Testing

@testable import Hugo

@MainActor
struct HeadlineDurationTests {
    @Test func zeroIsZeroHours() { #expect(HeadlineDuration(seconds: 0) == .hours(0)) }
    @Test func underAMinuteIsZeroHours() { #expect(HeadlineDuration(seconds: 59) == .hours(0)) }
    @Test func oneMinuteIsMinutes() { #expect(HeadlineDuration(seconds: 60) == .minutes(1)) }
    @Test func fortyFiveMinutesIsMinutes() { #expect(HeadlineDuration(seconds: 45 * 60) == .minutes(45)) }
    @Test func justUnderAnHourIsMinutes() { #expect(HeadlineDuration(seconds: 3_599) == .minutes(59)) }
    @Test func oneHourIsHours() { #expect(HeadlineDuration(seconds: 3_600) == .hours(1)) }
    @Test func minutesAboveAnHourAreDropped() { #expect(HeadlineDuration(seconds: 5_400) == .hours(1)) }
    @Test func negativeIsZeroHours() { #expect(HeadlineDuration(seconds: -600) == .hours(0)) }

    @Test func valueIsTheShownNumber() {
        #expect(HeadlineDuration.minutes(45).value == 45)
        #expect(HeadlineDuration.hours(12).value == 12)
    }

    @Test func spokenTextNamesTheUnit() {
        let us = Locale(identifier: "en_US")
        #expect(HeadlineDuration.minutes(45).spokenText(locale: us) == "45 minutes")
        #expect(HeadlineDuration.hours(1).spokenText(locale: us) == "1 hour")
        #expect(HeadlineDuration.hours(12).spokenText(locale: us) == "12 hours")
    }
}
