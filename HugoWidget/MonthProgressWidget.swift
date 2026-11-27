import SwiftUI
import WidgetKit

struct MonthProgressWidget: Widget {
    static let kind = "MonthProgress"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: MonthProgressProvider()) { entry in
            MonthProgressWidgetView(state: entry.state, date: entry.date)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("widget.month.name")
        .description(Text("widget.month.description"))
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
