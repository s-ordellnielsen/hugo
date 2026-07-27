import Foundation
import Testing
@testable import Hugo

struct DurationFormattingTests {
    @Test func formatsZeroSeconds() { #expect(formatDuration(0) == "00:00") }
    @Test func formatsFiftyNineSeconds() { #expect(formatDuration(59) == "00:00") }
    @Test func formatsOneMinute() { #expect(formatDuration(60) == "00:01") }
    @Test func formatsOneHourAndOneMinute() { #expect(formatDuration(3_661) == "01:01") }
    @Test func formatsTwentyFiveHours() { #expect(formatDuration(90_000) == "25:00") }
}
