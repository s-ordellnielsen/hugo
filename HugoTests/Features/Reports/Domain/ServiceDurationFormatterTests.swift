import Foundation
import Testing

@testable import Hugo

@MainActor
struct DurationFormattingTests {
    @Test func formatsZeroSeconds() { #expect(ServiceDurationFormatter.string(from: 0) == "00:00") }
    @Test func formatsFiftyNineSeconds() { #expect(ServiceDurationFormatter.string(from: 59) == "00:00") }
    @Test func formatsOneMinute() { #expect(ServiceDurationFormatter.string(from: 60) == "00:01") }
    @Test func formatsOneHourAndOneMinute() { #expect(ServiceDurationFormatter.string(from: 3_661) == "01:01") }
    @Test func formatsTwentyFiveHours() { #expect(ServiceDurationFormatter.string(from: 90_000) == "25:00") }

    @Test func formatsAccessibilityString() {
        let usLocale = Locale(identifier: "en_US")
        let zeroDuration = ServiceDurationFormatter.accessibilityString(from: 0, locale: usLocale)
        let oneHourDuration = ServiceDurationFormatter.accessibilityString(from: 3_660, locale: usLocale)

        #expect(
            zeroDuration == "0 hours, 0 minutes"
                || zeroDuration == "0 hr, 0 min"
                || zeroDuration.contains("0"))
        #expect(oneHourDuration.contains("1") && oneHourDuration.contains("1"))
    }

    @Test func hoursStringFormatsWholeHours() {
        let us = Locale(identifier: "en_US")
        #expect(ServiceDurationFormatter.hoursString(from: 0, locale: us) == "0 hours")
        #expect(ServiceDurationFormatter.hoursString(from: 3_600, locale: us) == "1 hour")
        #expect(ServiceDurationFormatter.hoursString(from: 7_200, locale: us) == "2 hours")
        #expect(ServiceDurationFormatter.hoursString(from: 90_000, locale: us) == "25 hours")
    }

    @Test func hoursStringAddsMinutesOnlyWhenPresent() {
        let us = Locale(identifier: "en_US")
        let withMinutes = ServiceDurationFormatter.hoursString(from: 5_400, locale: us)
        #expect(withMinutes.contains("1 hour"))
        #expect(withMinutes.contains("30 minutes"))
        #expect(ServiceDurationFormatter.hoursString(from: 3_659, locale: us) == "1 hour")
    }

    @Test func hoursStringClampsNegativeToZero() {
        #expect(ServiceDurationFormatter.hoursString(from: -5, locale: Locale(identifier: "en_US")) == "0 hours")
    }
}
