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
                    //                    NavigationLink(destination: Image(systemName: "checklist"))
                    //                    {
                    //                        Label(
                    //                            "account.group.main.item.personal.goals",
                    //                            systemImage: "checklist"
                    //                        )
                    //                    }
//                    NavigationLink(destination: SettingsView()) {
//                        Label(
//                            "account.group.personalize.item.settings",
//                            systemImage: "gearshape.fill"
//                        )
//                    }
                }
                
                Section {
                    NavigationLink(destination: TrackerSelectionView()) {
                        Label("settings.link.trackers", systemImage: "chart.line.text.clipboard.fill")
                    }
                } footer: {
                    Text("settings.group.trackers.description")
                }
                //                Section("account.group.integrations") {
                //                    NavigationLink(destination: Image(systemName: "calendar")) {
                //                        Label(
                //                            "account.group.integrations.item.calendar",
                //                            systemImage: "calendar"
                //                        )
                //                    }
                //                    NavigationLink(destination: Image(systemName: "cloud.sun.fill")) {
                //                        Label(
                //                            "account.group.integrations.item.weather",
                //                            systemImage: "cloud.sun.fill"
                //                        )
                //                    }
                //                }
                //                Section("account.group.support") {
                //                    NavigationLink(destination: Image(systemName: "sparkles")) {
                //                        Label("account.group.support.item.tipsandtricks", systemImage: "sparkles")
                //                    }
                //                    NavigationLink(destination: Image(systemName: "questionmark.text.page.fill")) {
                //                        Label("account.group.support.item.faq", systemImage: "questionmark.text.page.fill")
                //                    }
                //                    NavigationLink(destination: Image(systemName: "questionmark.bubble.fill")) {
                //                        Label(
                //                            "account.group.support.item.contactus",
                //                            systemImage: "questionmark.bubble.fill"
                //                        )
                //                    }
                //                }
                //                Section {
                //                    Button {
                //
                //                    } label: {
                //                        Label {
                //                            HStack {
                //                                Text("account.group.support.item.rateus")
                //                                Spacer()
                //                                Image(systemName: "arrow.up.right")
                //                                    .foregroundStyle(.tertiary)
                //                                    .font(.caption)
                //                                    .fontWeight(.semibold)
                //                            }
                //                        } icon: {
                //                            Image(systemName: "star.fill")
                //                        }
                //                    }
                //                    Button {
                //
                //                    } label: {
                //                        Label {
                //                            HStack {
                //                                Text("account.group.support.item.recommendus")
                //                                Spacer()
                //                                Image(systemName: "arrow.up.right")
                //                                    .foregroundStyle(.tertiary)
                //                                    .font(.caption)
                //                                    .fontWeight(.semibold)
                //                            }
                //                        } icon: {
                //                            Image(systemName: "heart.circle.fill")
                //                        }
                //                    }
                //                }
                //                Section("account.group.legal") {
                //                    NavigationLink(destination: Image(systemName: "text.page.fill")) {
                //                        Label("account.group.legal.item.termsofuse", systemImage: "text.page.fill")
                //                    }
                //                    NavigationLink(destination: Image(systemName: "exclamationmark.shield.fill")) {
                //                        Label("account.group.legal.item.privacypolicy", systemImage: "exclamationmark.shield.fill")
                //                    }
                //                }
                Section {
                    NavigationLink(destination: DebuggingView()) {
                        Label("Debugging", systemImage: "ant.fill")
                            .foregroundStyle(.red)
                    }
                } footer: {
                    Text("Debugging options are only meant for development purposes. Please do not use these options unless told to do so by the developer.")
                }
            }
            .toolbar {
                ToolbarItem {
                    Button {
                        dismiss()
                    } label: {
                        Label("navigation.dismiss", systemImage: "xmark")
                    }
                }
            }
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
