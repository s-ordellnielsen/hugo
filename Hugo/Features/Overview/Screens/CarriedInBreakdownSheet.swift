import SwiftData
import SwiftUI

/// The month's carried-in time split by category. Opened from the
/// carried-in line on the Overview.
struct CarriedInBreakdownSheet: View {
    let carriedIn: CarriedInTime
    /// The month's carried-in entries.
    let entries: [Entry]

    @Environment(\.dismiss) private var dismiss
    @Query private var trackers: [Tracker]

    var body: some View {
        let rows = CategoryTotals.rows(entries: entries, trackers: trackers)
        NavigationStack {
            List {
                Section {
                    Text(carriedIn.label())
                        .foregroundStyle(.secondary)
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
                } footer: {
                    Text("overview.carried.breakdown.footer")
                }
            }
            .navigationTitle("overview.carried.breakdown.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("navigation.done") { dismiss() }
                }
            }
        }
    }
}
