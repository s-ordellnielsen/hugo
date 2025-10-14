//
//  PublisherStatusSelectionView.swift
//  Hugo
//
//  Created by Sebastian Nielsen on 09/10/2025.
//

import SwiftUI

struct PublisherStatusSelectionView: View {
    var body: some View {
            List {
                VStack {
                    HStack(spacing: 16) {
                        Image(systemName: "circle.badge.checkmark.fill")
                            .font(.title)
                        VStack(alignment: .leading) {
                            Text("account.page.publisherselect.current")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(.secondary)
                            Text("publisher.status.regularpioneer.full")
                                .font(.title2)
                                .fontDesign(.rounded)
                        }
                    }
                    .fontWeight(.bold)
                }
                
                Section {
                    Button {
                        
                    } label: {
                        Label {
                            VStack(alignment: .leading) {
                                Text("publisher.status.regularpioneer.full")
                                HStack {
                                    HStack(spacing: 4) {
                                        Text("account.publisher.status.goaltype.label")
                                        Text("publisher.status.goaltype.yearly")
                                    }
                                    HStack(spacing: 4) {
                                        Text("account.publisher.status.goal.label")
                                        Text("publisher.status.goal.\(Int(600))")
                                    }
                                }
                                .foregroundStyle(.secondary)
                                .fontWeight(.regular)
                                .font(.caption)
                            }
                        } icon: {
                            Image(systemName: "checkmark.circle.fill")
                        }
                    }
                    Button {
                        
                    } label: {
                        Label {
                            VStack(alignment: .leading) {
                                Text("publisher.status.auxiliary.full")
                                HStack {
                                    HStack(spacing: 4) {
                                        Text("account.publisher.status.goaltype.label")
                                        Text("publisher.status.goaltype.monthly")
                                    }
                                    HStack(spacing: 4) {
                                        Text("account.publisher.status.goal.label")
                                        Text("publisher.status.goal.\(Int(30))")
                                    }
                                }
                                .foregroundStyle(.secondary)
                                .fontWeight(.regular)
                                .font(.caption)
                            }
                        } icon: {
                            Image(systemName: "circle")
                        }
                    }
                    Button {
                        
                    } label: {
                        Label {
                            VStack(alignment: .leading) {
                                Text("publisher.status.publisher.full")
                                HStack {
                                    HStack(spacing: 4) {
                                        Text("account.publisher.status.goaltype.label")
                                        Text("publisher.status.goal.\(Int(0))")
                                    }
                                }
                                .foregroundStyle(.secondary)
                                .fontWeight(.regular)
                                .font(.caption)
                            }
                        } icon: {
                            Image(systemName: "circle")
                        }
                    }
                }
                .fontWeight(.semibold)
                .tint(.primary)
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

#Preview {
    PublisherStatusSelectionView()
}
