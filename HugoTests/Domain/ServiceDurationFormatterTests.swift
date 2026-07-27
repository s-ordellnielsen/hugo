import Foundation
import Testing
@testable import Hugo

struct DurationFormattingTests {
    @Test func formatsZeroSeconds() { #expect(ServiceDurationFormatter.string(from: 0) == "00:00") }
    @Test func formatsFiftyNineSeconds() { #expect(ServiceDurationFormatter.string(from: 59) == "00:00") }
    @Test func formatsOneMinute() { #expect(ServiceDurationFormatter.string(from: 60) == "00:01") }
    @Test func formatsOneHourAndOneMinute() { #expect(ServiceDurationFormatter.string(from: 3_661) == "01:01") }
    @Test func formatsTwentyFiveHours() { #expect(ServiceDurationFormatter.string(from: 90_000) == "25:00") }
}
