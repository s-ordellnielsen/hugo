//
//  OverviewListView.swift
//  Hugo
//
//  Created by Sebastian Nielsen on 07/09/2026.
//

import SwiftData
import SwiftUI

struct OverviewListView: View {
    var entries: [Entry]

    @AppStorage(UserDefaultsKeys.overviewListStyle) private var listStyle: OverviewListStyle = .byDate

    @State var selectedEntry: Entry? = nil
    @State var showAddEntrySheet: Bool = false

    var body: some View {
        VStack(spacing: HugoLayout.Spacing.regular) {
            if entries.isEmpty {
                ContentUnavailableView {
                    Label {
                        Text("overview.entries.empty")
                            .fontDesign(.serif)
                    } icon: {
                        Image(systemName: "text.page.badge.magnifyingglass")
                    }
                } description: {
                    Text("overview.entries.empty.description")
                } actions: {
                    Button("overview.entries.empty.actions.add") {
                        showAddEntrySheet.toggle()
                    }
                }
                .padding(.top, HugoLayout.Spacing.small)
            } else {
                HStack {
                    Text("entries.list.this_month.header")
                        .font(.headline)
                        .padding(.leading, HugoLayout.Spacing.card)
                    Spacer()
                    OverviewListStyleControl(selection: $listStyle)
                }
                if listStyle == .byEntry {
                    OverviewEntryList(entries: entries, selectedEntry: $selectedEntry)
                } else if listStyle == .byDate {
                    OverviewDateList(entries: entries, selectedEntry: $selectedEntry)
                }
            }
        }
        .padding(.top)
        .motion(Motion.presence, value: entries.count)
        .sheet(item: $selectedEntry) { entry in
            EntryDetailView(entry: entry)
                .presentationDetents([.medium])
        }
        .sheet(isPresented: $showAddEntrySheet) {
            AddEntryView()
        }
    }
}

struct OverviewEntryList: View {
    var entries: [Entry]

    @Binding var selectedEntry: Entry?

    var body: some View {
        ForEach(entries) { entry in
            EntryRow(entry: entry, selectedEntry: $selectedEntry)
                .transition(.move(edge: .top).combined(with: .opacity))
        }
    }
}

struct OverviewDateList: View {
    var entries: [Entry]

    @Binding var selectedEntry: Entry?

    var body: some View {
        ForEach(dates) { date in
            DateListItem(section: date)
                .equatable()
                .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    private var dates: [DateSection] {
        let groupedByDate = Dictionary(grouping: entries) { entry in
            Calendar.current.startOfDay(for: entry.date)
        }

        let sections: [DateSection] = groupedByDate.map { date, entries in
            DateSection(date: date, entries: entries.reversed())
        }
        .sorted { $0.date > $1.date }

        return sections
    }

    private struct DateSection: Identifiable, Equatable {
        var date: Date
        var entries: [Entry]

        var id: Date { date }

        static func == (lhs: DateSection, rhs: DateSection) -> Bool {
            lhs.date == rhs.date
                && lhs.entries.map(\.id) == rhs.entries.map(\.id)
                && lhs.entries.map(\.duration) == rhs.entries.map(\.duration)
                && lhs.entries.map(\.date) == rhs.entries.map(\.date)
        }
    }

    private struct DateListItem: View, Equatable {
        var section: DateSection

        var body: some View {
            VStack {
                HStack(alignment: .bottom) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(section.date, format: .dateTime.day())
                            .font(.title)
                            .fontWeight(.semibold)
                            .fontDesign(.serif)
                        Text(section.date, format: .dateTime.month())
                    }
                    Spacer()
                    VStack(alignment: .trailing) {
                        Text("Total")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(duration.formatted(.units(allowed: [.hours, .minutes], width: .abbreviated)))
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                }
                Divider()
                VStack(spacing: HugoLayout.Spacing.small) {
                    ForEach(section.entries) { entry in
                        DateEntryRow(entry: entry)
                            .equatable()
                    }
                }
                .padding(.top, HugoLayout.Spacing.small)
            }
            .padding(HugoLayout.Spacing.card)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(.rect(cornerRadius: HugoLayout.CornerRadius.card))
        }

        private var duration: Duration {
            section.entries.reduce(into: .zero) { $0 += Duration.seconds($1.duration) }
        }
    }

    private struct DateEntryRow: View, Equatable {
        var entry: Entry

        var body: some View {
            HStack {
                Text(entry.date, format: .dateTime.hour().minute())
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                Text(entry.tracker?.name ?? "default.tracker")
                Spacer()
                Text(Duration.seconds(entry.duration).formatted(.time(pattern: .hourMinute)))
                    .monospacedDigit()
            }
        }

        static func == (lhs: Self, rhs: Self) -> Bool {
            lhs.entry.id == rhs.entry.id && lhs.entry.date == rhs.entry.date && lhs.entry.duration == rhs.entry.duration
        }
    }
}

#Preview {
    OverviewView()
        .modelContainer(.preview)
}
