import Foundation
import Observation

struct EntryDraft {
    let date: Date
    let duration: TimeInterval
    let tracker: Tracker
    let bibleStudies: Int
}

@MainActor
@Observable
final class AddEntryFormModel {
    var date: Date
    var time: Date?
    var durationDate: Date
    var bibleStudies = 0
    var selectedTracker: Tracker?
    var isTimePickerPresented = false
    var isCategoryPickerPresented = false
    var validationMessage: String?

    private let calendar: Calendar
    private let now: Date

	init(calendar: Calendar = .current, now: Date = .now, seededDate: Date? = nil) {
        self.calendar = calendar
        self.now = now
        self.date = calendar.startOfDay(for: seededDate ?? now)
        self.durationDate = calendar.startOfDay(for: now)
    }

    var durationInSeconds: TimeInterval {
        EntryDurationConversion.seconds(from: durationDate, calendar: calendar)
    }

    var isSubmitDisabled: Bool {
        durationInSeconds == 0 || selectedTracker == nil
    }

    var combinedDate: Date? {
        guard var components = calendar.dateComponents([.year, .month, .day], from: date) as DateComponents? else { return nil }
        if let time {
            components.hour = calendar.component(.hour, from: time)
            components.minute = calendar.component(.minute, from: time)
            components.second = calendar.component(.second, from: time)
        } else {
            components.hour = 0
            components.minute = 0
            components.second = 0
        }
        return calendar.date(from: components)
    }

    func reconcileSelection(with trackers: [Tracker]) {
        if let selectedTracker, trackers.contains(where: { $0.id == selectedTracker.id }) {
            return
        }
        selectedTracker = trackers.first(where: \.isDefault) ?? trackers.first
    }

    func incrementBibleStudies() {
        bibleStudies += 1
    }

    func decrementBibleStudies() {
        bibleStudies = max(0, bibleStudies - 1)
    }

    func draft() -> EntryDraft? {
        guard let combinedDate, let selectedTracker, durationInSeconds > 0 else {
            validationMessage = "entry.add.validation.invalid"
            return nil
        }
        validationMessage = nil
        return EntryDraft(date: combinedDate, duration: durationInSeconds, tracker: selectedTracker, bibleStudies: bibleStudies)
    }
}

enum EntryDurationConversion {
    static func seconds(from date: Date, calendar: Calendar) -> TimeInterval {
        let components = calendar.dateComponents([.hour, .minute, .second], from: date)
        return TimeInterval((components.hour ?? 0) * 3600 + (components.minute ?? 0) * 60 + (components.second ?? 0))
    }

    static func date(from seconds: TimeInterval, calendar: Calendar, reference: Date) -> Date {
        var components = calendar.dateComponents([.year, .month, .day], from: reference)
        let wholeSeconds = max(0, Int(seconds))
        components.hour = wholeSeconds / 3600
        components.minute = (wholeSeconds % 3600) / 60
        components.second = wholeSeconds % 60
        return calendar.date(from: components) ?? reference
    }
}
