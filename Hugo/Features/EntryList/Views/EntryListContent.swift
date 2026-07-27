//
//  Content.swift
//  Hugo
//
//  Created by Sebastian Nielsen on 31/10/2025.
//

import SwiftUI

extension EntryList {
    struct Content: View {
        var entries: [Entry]

        @State var selectedEntry: Entry? = nil

        var body: some View {
            ForEach(entries) { entry in
                EntryList.Row(entry: entry, selectedEntry: $selectedEntry)
            }
            .sheet(item: $selectedEntry) { entry in
                EntryList.DetailSheet(entry: entry)
                    .presentationDetents([.medium])
            }
        }
    }
}
