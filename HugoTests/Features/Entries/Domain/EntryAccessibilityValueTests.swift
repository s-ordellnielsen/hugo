import Testing

@testable import Hugo

struct EntryAccessibilityValueTests {
    @Test
    func withoutBibleStudiesItIsTheSpokenDuration() {
        #expect(
            EntryAccessibilityValue.text(duration: 5_400, bibleStudies: 0)
                == ServiceDurationFormatter.accessibilityString(from: 5_400))
    }

    @Test
    func bibleStudiesFollowTheDuration() {
        let spoken = ServiceDurationFormatter.accessibilityString(from: 5_400)
        let text = EntryAccessibilityValue.text(duration: 5_400, bibleStudies: 2)
        #expect(text.hasPrefix(spoken + ", "))
        #expect(text.contains("2"))
    }
}
