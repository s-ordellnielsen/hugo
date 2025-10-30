//
//  PublisherStatusSelectionView.swift
//  Hugo
//
//  Created by Sebastian Nielsen on 09/10/2025.
//

import SwiftUI

struct PublisherStatusSelectionView: View {
    @AppStorage(UserDefaults.publisherStatusKey) var currentStatus: String = ""

    var body: some View {
        List {
            CurrentPublisherStatusView(currentStatus: currentStatus)

            Section {
                ForEach(PublisherStatusConfig.defaults) { status in
                    Button {
                        currentStatus = status.id
                    } label: {
                        HStack(spacing: 16) {
                            Image(systemName: currentStatus == status.id ? "checkmark.circle.fill" : "circle")
                                .contentTransition(.symbolEffect(.replace.downUp.byLayer, options: .nonRepeating))
                                .font(.title2)
                            VStack(alignment: .leading, spacing: 8) {
                                Text(status.nameKey)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("publisher.status.goaltype.label.\(status.goalType.label)")
                                    Text("publisher.status.goal.label.\(status.goal)")
                                }
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fontWeight(.regular)
                            }
                        }
                    }
                }
            }
            .fontWeight(.semibold)
            .listRowBackground(Color(.clear))
        }
        .navigationTitle("account.page.publisherstatus.title")
        .toolbar {
            ToolbarItem {
                Button {

                } label: {
                    Label("navigation.help", systemImage: "questionmark")
                }
            }
        }
    }
}

private struct CurrentPublisherStatusView: View {
    var currentStatus: String

    var body: some View {
        VStack {
            HStack(spacing: 16) {
                Image(systemName: PublisherStatusConfig.current(currentStatus) != nil ? "circle.badge.checkmark" : "circle")
                    .font(.title)
                    .contentTransition(.symbolEffect(.replace.magic(fallback: .downUp.byLayer)))
                    .symbolRenderingMode(.hierarchical)
                VStack(alignment: .leading) {
                    Text("account.page.publisherselect.current")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                    Text(PublisherStatusConfig.current(currentStatus)?.nameKey ?? "publisher.status.empty")
                        .font(.title2)
                        .fontDesign(.rounded)
                }
            }
            .fontWeight(.semibold)
        }
    }
}

#Preview {
    PublisherStatusSelectionView()
}
