import SwiftData
import SwiftUI

struct CategoryProgressBreakdownView: View {
    @Query private var entries: [Entry]
    @Query private var trackers: [Tracker]
    @AppStorage(UserDefaultsKeys.publisherStatus) private var statusID = ""

    init(month: YearMonth = Date().yearMonth()) {
        let start = month.date()
        let end = month.nextMonth().date()
        _entries = Query(filter: #Predicate<Entry> { $0.date >= start && $0.date < end })
    }

    private var rows: [CategoryProgressRow] {
        CategoryProgressAggregator.rows(entries: entries, trackers: trackers)
    }

    private func displayColor(for row: CategoryProgressRow) -> Color {
        guard let color = row.color else { return .hugoAccent }
        return Color(hue: color.hue, saturation: color.saturation, brightness: color.brightness)
    }

    var body: some View {
        let total = max(
            rows.reduce(0) { $0 + $1.duration } / 3600, Double(PublisherStatus.status(for: statusID)?.monthlyGoal ?? 0))
        VStack(alignment: .leading, spacing: 12) {
            GeometryReader { geometry in
                HStack(spacing: 0) {
                    ForEach(rows) { row in
                        Rectangle().fill(displayColor(for: row))
                            .frame(width: total > 0 ? geometry.size.width * CGFloat(row.duration / 3600 / total) : 0)
                    }
                }.background(Color(.secondarySystemGroupedBackground)).clipShape(RoundedRectangle(cornerRadius: 24))
            }.frame(height: 56)
            ForEach(rows) { row in
                HStack {
                    Image(systemName: row.iconName)
                    Text(row.name)
                    Spacer()
                    Text(ServiceDurationFormatter.string(from: row.duration)).monospacedDigit().foregroundStyle(
                        .secondary)
                }
            }
        }
    }
}
