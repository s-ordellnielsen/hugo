import SwiftUI

struct YearlyGoalPacingSettingsView: View {
    @AppStorage(UserDefaultsKeys.yearlyGoalPacing) private var pacing: YearlyGoalPacing = .proRated
    @AppStorage(UserDefaultsKeys.publisherStatus) private var statusID = ""

    let now: Date
    let calendar: Calendar
    let locale: Locale

    init(now: Date = .now, calendar: Calendar = .current, locale: Locale = .current) {
        self.now = now
        self.calendar = calendar
        self.locale = locale
    }

    private var calculation: CurrentMonthCalculation? {
        CurrentMonthCalculation.make(
            status: PublisherStatus.status(for: statusID), now: now, calendar: calendar, locale: locale)
    }

    var body: some View {
        List {
            if let calculation {
                Section {
                    CurrentMonthCalculationPreview(calculation: calculation, selected: pacing, locale: locale)
                        .padding(.vertical, HugoLayout.Spacing.compact)
                }

                Section {
                    ForEach(calculation.options, id: \.pacing) { option in
                        SelectableOptionRow(
                            title: Text(option.pacing.label),
                            description: Text(option.pacing.explanation),
                            isSelected: pacing == option.pacing
                        ) {
                            pacing = option.pacing
                        }
                    }
                }
            } else {
                Section {
                    ContentUnavailableView(
                        "settings.yearlyGoal.pacing.noGoal",
                        systemImage: "chart.line.uptrend.xyaxis")
                }
            }
        }
        .navigationTitle("settings.yearlyGoal.pacing")
    }
}

#Preview {
    NavigationStack {
        YearlyGoalPacingSettingsView(
            now: Calendar(identifier: .gregorian).date(from: DateComponents(year: 2026, month: 11, day: 3))!,
            calendar: Calendar(identifier: .gregorian),
            locale: Locale(identifier: "en_US"))
    }
    .defaultAppStorage(UserDefaults(suiteName: "CurrentMonthCalculationPreview")!)
}
