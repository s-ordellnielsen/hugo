//
//  AccountView.swift
//  Hugo
//
//  Created by Sebastian Nielsen on 09/10/2025.
//

import SwiftData
import SwiftUI

struct AccountView: View {
    @Environment(\.dismiss) var dismiss
    @AppStorage(UserDefaults.publisherStatusKey) var publisherStatus = ""

    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink(destination: PublisherStatusSelectionView())
                    {
                        Label {
                            Text("account.group.main.item.publisher.status")
                            Text(
                                PublisherStatusConfig.current(publisherStatus)?
                                    .nameKey
                                    ?? "account.group.main.item.publisher.status.empty"
                            )
                        } icon: {
                            Image(systemName: "circle.badge.checkmark.fill")
                        }
                    }
                }
                
                Section {
                    NavigationLink(destination: TrackerSettingsView()) {
                        Label("settings.link.trackers", systemImage: "chart.line.text.clipboard.fill")
                    }
                } footer: {
                    Text("settings.group.trackers.description")
                }
                Section {
                    NavigationLink(destination: DebuggingView()) {
                        Label("debug.title", systemImage: "ant.fill")
                            .foregroundStyle(.red)
                    }
                } footer: {
                    Text("debug.disclaimer")
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .cancel) {
                        dismiss()
                    }
                }
            }
            .tint(.primary)
        }
    }
}

struct AccountViewButton: View {
    @State private var showAccount: Bool = false

    var body: some View {
        Button {
            showAccount = true
        } label: {
            Image(systemName: "person.fill")
        }
        .sheet(isPresented: $showAccount) {
            AccountView()
                .presentationDetents([.large])
        }
    }
}

#Preview {
    AccountView()
        .modelContainer(.preview)
}
