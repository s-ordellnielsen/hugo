//
//  Content.swift
//  Hugo
//
//  Created by Sebastian Nielsen on 31/10/2025.
//

import SwiftUI

struct EntryListView: View {
    var entries: [Entry]

    @State var selectedEntry: Entry? = nil

    var body: some View {
        LazyVStack(spacing: 12) {
            ForEach(entries) { entry in
                EntryRow(entry: entry, selectedEntry: $selectedEntry)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .motion(Motion.presence, value: entries.count)
        .sheet(item: $selectedEntry) { entry in
            EntryDetailView(entry: entry)
                .presentationDetents([.medium])
        }
    }
}
