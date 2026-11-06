import Foundation

/// What VoiceOver reads as the value of an entry row: the duration, then the
/// number of Bible studies when there are any.
nonisolated enum EntryAccessibilityValue {
    static func text(duration: TimeInterval, bibleStudies: Int) -> String {
        let spokenDuration = ServiceDurationFormatter.accessibilityString(from: duration)
        guard bibleStudies != 0 else { return spokenDuration }
        let studies = String(localized: "entry.bibelstudies.count.accessibility.\(bibleStudies)")
        return "\(spokenDuration), \(studies)"
    }
}
