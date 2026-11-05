import Foundation
import Observation

@MainActor
@Observable
final class PlanFormModel {
    let day: CalendarDay
    var durationInSeconds: TimeInterval
    /// Only the hour and minute are used.
    var startTime: Date?
    var selectedTracker: Tracker?
    var isCategoryPickerPresented = false
    var isTimePickerPresented = false
    var validationMessage: String?

    private let preferredTrackerID: UUID?
    private let calendar: Calendar

    init(day: CalendarDay, plan: Plan? = nil, calendar: Calendar = .current) {
        self.day = day
        self.calendar = calendar
        self.durationInSeconds = plan?.duration ?? 0
        self.preferredTrackerID = plan?.categoryID
        self.startTime = plan?.startMinute.flatMap { minute in
            calendar.date(
                bySettingHour: minute / 60, minute: minute % 60, second: 0, of: day.startDate(calendar: calendar))
        }
    }

    var isSaveDisabled: Bool {
        durationInSeconds <= 0 || selectedTracker == nil
    }

    var startMinute: Int? {
        startTime.map { calendar.component(.hour, from: $0) * 60 + calendar.component(.minute, from: $0) }
    }

    func reconcileSelection(with trackers: [Tracker]) {
        if let selectedTracker, trackers.contains(where: { $0.id == selectedTracker.id }) {
            return
        }
        selectedTracker =
            trackers.first(where: { $0.id == preferredTrackerID })
            ?? trackers.first(where: \.isDefault) ?? trackers.first
    }

    func draft() -> PlanDraft? {
        guard durationInSeconds > 0, let selectedTracker else {
            validationMessage = String(
                localized: "planner.plan.validation.invalid",
                defaultValue: "Choose a duration and a category.",
                comment: "Shown when a plan cannot be saved because the duration is zero or no category is chosen.")
            return nil
        }
        validationMessage = nil
        return PlanDraft(day: day, duration: durationInSeconds, startMinute: startMinute, tracker: selectedTracker)
    }
}
