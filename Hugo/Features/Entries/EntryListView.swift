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
        ForEach(entries) { entry in
            EntryRow(entry: entry, selectedEntry: $selectedEntry)
        }
        .sheet(item: $selectedEntry) { entry in
            EntryDetailView(entry: entry)
                .presentationDetents([.medium])
        }
    }
}
