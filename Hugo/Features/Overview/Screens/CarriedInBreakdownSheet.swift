import SwiftData
import SwiftUI

/// The month's carried-in time split by category. Opened from the
/// carried-in line on the Overview.
struct CarriedInBreakdownSheet: View {
    let carriedIn: CarriedInTime
    /// The month's carried-in entries.
    let entries: [Entry]

    @Query private var trackers: [Tracker]

    var body: some View {
        let rows = CategoryTotals.rows(entries: entries, trackers: trackers)
        List {
            Section {
                Text(carriedIn.label())
                    .font(.system(.title2, design: .serif, weight: .bold))
                    .accessibilityAddTraits(.isHeader)
                    .listRowBackground(Color.clear)
            }
            Section {
                ForEach(rows) { row in
                    LabeledContent {
                        Text(ServiceDurationFormatter.hoursString(from: row.duration))
                    } label: {
                        Label(row.name, systemImage: row.iconName)
                    }
                }
            } header: {
                Text("overview.carried.breakdown.header")
            }
        }
    }
}
