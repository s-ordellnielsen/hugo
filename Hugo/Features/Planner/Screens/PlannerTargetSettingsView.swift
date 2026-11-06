import Combine
import SwiftData
import SwiftUI
import UIKit

struct PlannerTargetSettingsView: View {
    @AppStorage(UserDefaultsKeys.plannerTargetBase) private var base: PlannerTargetBase = .monthlyGoal
    @AppStorage(UserDefaultsKeys.plannerExtraHours) private var extraHours = 0
    @AppStorage(UserDefaultsKeys.publisherStatus) private var statusID = ""
    @Environment(\.scenePhase) private var scenePhase
    @State private var refreshedToday: Date = .now
    @Query private var yearEntries: [Entry]
    @Query private var submissions: [SubmittedReport]
    @Query private var trackers: [Tracker]

    private let fixedNow: Date?
    private let calendar: Calendar
    private let locale: Locale

    private var now: Date { fixedNow ?? refreshedToday }

    init(now: Date? = nil, calendar: Calendar = .current, locale: Locale = .current) {
        self.fixedNow = now
        self.calendar = calendar
        self.locale = locale
        let initialNow = now ?? .now
        _refreshedToday = State(initialValue: initialNow)
        let range = TheocraticYear.containing(initialNow, calendar: calendar).dateRange(calendar: calendar)
        let start = range.lowerBound
        let end = range.upperBound
        _yearEntries = Query(
            filter: #Predicate<Entry> { $0.date >= start && $0.date < end },
            sort: \Entry.date)
        _submissions = Query(sort: \SubmittedReport.year)
    }

    private var status: PublisherStatus? { PublisherStatus.status(for: statusID) }
    private var hasGoal: Bool { (status?.monthlyGoal ?? 0) > 0 }

    private var creditedBeforeCurrentMonth: TimeInterval {
        PlannerTarget.creditedBeforeCurrentMonth(
            entries: yearEntries, submissions: submissions, trackers: trackers,
            status: status, now: now, calendar: calendar, locale: locale)
    }

    private var preview: PlannerTargetPreview {
        PlannerTargetPreview.make(
            base: base, extraHours: extraHours, status: status,
            creditedBeforeCurrentMonth: creditedBeforeCurrentMonth,
            now: now, calendar: calendar, locale: locale)
    }

    var body: some View {
        List {
            Section {
                PlannerTargetPreviewView(preview: preview, hasGoal: hasGoal)
                    .padding(.vertical, HugoLayout.Spacing.regular)
            }

            if status?.yearlyGoalRule != nil {
                Section {
                    SelectableOptionRow(
                        title: Text("planner.target.base.monthlyGoal"),
                        description: Text(preview.monthlyBaseDescription),
                        isSelected: base == .monthlyGoal
                    ) {
                        base = .monthlyGoal
                    }
                    SelectableOptionRow(
                        title: Text("planner.target.base.yearlyGoalShare"),
                        description: Text(preview.adjustedDescription),
                        isSelected: base == .yearlyGoalShare
                    ) {
                        base = .yearlyGoalShare
                    }
                }
            }

            Section {
                Stepper(value: $extraHours, in: 0...30) {
                    LabeledContent(
                        hasGoal
                            ? LocalizedStringKey("planner.target.extra") : LocalizedStringKey("planner.target.title"),
                        value: ServiceDurationFormatter.hoursString(
                            from: TimeInterval(extraHours) * 3_600, locale: locale))
                }
            } footer: {
                Text(
                    hasGoal
                        ? LocalizedStringKey("planner.target.extra.footer")
                        : LocalizedStringKey("planner.target.extra.footer.noGoal"))
            }
        }
        .navigationTitle("planner.target.title")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { refreshToday() }
        }
        .onReceive(
            NotificationCenter.default
                .publisher(for: UIApplication.significantTimeChangeNotification)
                .receive(on: RunLoop.main)
        ) { _ in
            refreshToday()
        }
    }

    private func refreshToday() {
        guard fixedNow == nil else { return }
        let updated = Date.now
        if !calendar.isDate(updated, inSameDayAs: refreshedToday) {
            refreshedToday = updated
        }
    }
}

#Preview("Regular pioneer, behind target") {
    let defaults = UserDefaults(suiteName: "PlannerTargetBehindPreview")!
    defaults.set("regular-pioneer", forKey: UserDefaultsKeys.publisherStatus)
    defaults.set(PlannerTargetBase.yearlyGoalShare.rawValue, forKey: UserDefaultsKeys.plannerTargetBase)
    defaults.set(0, forKey: UserDefaultsKeys.plannerExtraHours)
    let calendar = Calendar(identifier: .gregorian)
    let now = calendar.date(from: DateComponents(year: 2026, month: 11, day: 3, hour: 12))!
    return NavigationStack {
        PlannerTargetSettingsView(now: now, calendar: calendar, locale: Locale(identifier: "en_US"))
    }
    .defaultAppStorage(defaults)
    .modelContainer(.preview)
}

#Preview("Large text") {
    let defaults = UserDefaults(suiteName: "PlannerTargetLargeTextPreview")!
    defaults.set("regular-pioneer", forKey: UserDefaultsKeys.publisherStatus)
    return NavigationStack {
        PlannerTargetSettingsView()
    }
    .defaultAppStorage(defaults)
    .modelContainer(.preview)
    .dynamicTypeSize(.accessibility5)
}
