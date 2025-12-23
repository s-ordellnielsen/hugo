//
//  OverviewView.swift
//  Hugo
//
//  Created by Sebastian Nielsen on 18/11/2025.
//

import SwiftUI
import SwiftData

struct OverviewView: View {
    static var currentMonthPredicate: Predicate<Entry> {
        let calendar = Calendar.current
        let now = Date()
        let startOfMonth =
            calendar.dateInterval(of: .month, for: now)?.start ?? now
        let endOfMonth =
            calendar.date(byAdding: .month, value: 1, to: startOfMonth) ?? now

        return #Predicate<Entry> { entry in
            entry.date >= startOfMonth && entry.date < endOfMonth
        }
    }

    @Query(
        filter: OverviewView.currentMonthPredicate,
        sort: \Entry.date,
        order: .reverse
    ) private var entries: [Entry]

    @State private var showAddItemSheet: Bool = false

    var current: Double {
        let totalSeconds = entries.reduce(0) { $0 + Double($1.duration) }

        let totalHours = totalSeconds / 3600.0

        return totalHours
    }

    var formattedMonth: String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMMM, yyyy"

        return dateFormatter.string(from: Date())
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack {
                    CurrentMonthProgressView(value: current) {
                        EntrySheet.Add()
                    }
                    Spacer(minLength: 32)
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            VStack(alignment: .leading) {
                                Text("overview.section.thismonth.title")
                                    .font(.headline)
                                    .fontDesign(.rounded)
                                Text(formattedMonth)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .fontWeight(.medium)
                            }
                            Spacer()
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal)
                        .padding(.top)
                        .padding(.bottom, 4)
                        EntryList.Content(entries: entries)
                        Spacer()
                    }
                    .background(Color(.systemGroupedBackground))
                    .frame(maxWidth: .infinity)
                }
                .frame(maxWidth: .infinity)
                .padding()
            }
            .navigationTitle("overview.title")
            .navigationBarTitleDisplayMode(.inline)
            .background(Color(.systemGroupedBackground))
            .toolbar {
                AccountViewButton()
            }
        }
    }
}

#Preview {
    OverviewView()
        .modelContainer(.preview)
}
