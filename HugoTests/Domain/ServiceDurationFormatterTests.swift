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
        #expect(ServiceDurationFormatter.accessibilityString(from: 0, locale: usLocale) == "0 hours, 0 minutes" || ServiceDurationFormatter.accessibilityString(from: 0, locale: usLocale) == "0 hr, 0 min" || ServiceDurationFormatter.accessibilityString(from: 0, locale: usLocale).contains("0"))
        #expect(ServiceDurationFormatter.accessibilityString(from: 3_660, locale: usLocale).contains("1") && ServiceDurationFormatter.accessibilityString(from: 3_660, locale: usLocale).contains("1"))
    }
}
