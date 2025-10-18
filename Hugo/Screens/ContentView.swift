//
//  ContentView.swift
//  Hugo
//
//  Created by Sebastian Nielsen on 05/10/2025.
//

import SwiftData
import SwiftUI

struct ContentView: View {
    static var currentMonthPredicate: Predicate<Entry> {
        let calendar = Calendar.current
        let now = Date()
        let startOfMonth = calendar.dateInterval(of: .month, for: now)?.start ?? now
        let endOfMonth = calendar.date(byAdding: .month, value: 1, to: startOfMonth) ?? now
        
        return #Predicate<Entry> { entry in
            entry.date >= startOfMonth && entry.date < endOfMonth
        }
    }
    
    @Query(filter: ContentView.currentMonthPredicate, sort: \Entry.date, order: .reverse) private var entries: [Entry]

    @State private var showAddItemSheet: Bool = false

    let goal: Double = 50.0
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
                    MonthlyProgressView(value: current)
                        .padding(.horizontal, 48)
                        .padding(.bottom, 32)
                        .padding(.top, 16)
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
                        .padding()
                        EntryListView(entries: entries)
                        Spacer()
                    }
                    .padding(.vertical)
                    .padding(.horizontal, 20)
                    .background(Color(.systemGroupedBackground))
                    .frame(maxWidth: .infinity)
                }

                .frame(maxWidth: .infinity)
            }
            .navigationTitle("overview.title")
            .navigationBarTitleDisplayMode(.inline)
            .background(Color(.systemGroupedBackground))
            .toolbar {
                ToolbarItem {
                    AccountViewButton()
                }
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(.preview)
}
