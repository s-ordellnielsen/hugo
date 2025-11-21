//
//  SymbolPicker.swift
//  Hugo
//
//  Created by Sebastian Nielsen on 20/11/2025.
//

import SwiftUI

struct SymbolPicker: View {
    @Environment(\.dismiss) private var dismiss

    var set: SymbolSet

    @Binding var selectedSymbol: String

    @State private var searchText: String = ""
    @State private var attributes: SymbolAttribute? = nil

    var filteredSymbols: [SymbolDefinition] {
        if searchText.isEmpty && attributes == nil {
            return set.symbols
        }
        return set.symbols.filter { $0.matches(searchText, attributes) }
    }

    private var columns: [GridItem] {
        let count = UIDevice.current.userInterfaceIdiom == .pad ? 8 : 4
        return Array(repeating: GridItem(.flexible(minimum: 70)), count: count)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                //                VStack(alignment: .leading, spacing: 12) {
                //                    HStack {
                //                        Text("Missing an icon?")
                //                            .font(.headline)
                //                        Spacer()
                //                        Button {
                //
                //                        } label: {
                //                            Label("Request Icon", systemImage: "envelope")
                //                        }
                //                        .buttonStyle(.bordered)
                //                    }
                //                    .frame(maxWidth: .infinity, alignment: .leading)
                //                    Text("Let me know! I'll see if I can add it soon.")
                //                        .font(.callout)
                //                        .foregroundStyle(.secondary)
                //                }
                //                .padding()
                //                .background(Color(.secondarySystemGroupedBackground))
                //                .cornerRadius(24)
                //                .padding()
                LazyVGrid(columns: columns) {
                    ForEach(filteredSymbols, id: \.id) { symbol in
                        Button {
                            selectedSymbol = symbol.icon
                            dismiss()
                        } label: {
                            symbolButton(symbol)
                        }
                    }
                }
                .fontWeight(.semibold)
                .tint(.primary)
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Pick an icon")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem {
                    Menu {
                        Button {
                            attributes = nil
                        } label: {
                            Text("Show All")
                        }
                        Divider()
                        Picker("Attributes", selection: $attributes) {
                            ForEach(SymbolAttribute.allCases, id: \.id) { attribute in
                                Label(attribute.label, systemImage: attribute.icon)
                                    .tag(attribute)
                            }
                        }
                    } label: {
                        Label(
                            "Filter",
                            systemImage: "line.3.horizontal.decrease"
                        )
                    }
                    .badge(attributes == nil ? nil : " ")
                }
                ToolbarSpacer(.fixed, placement: .bottomBar)
                DefaultToolbarItem(kind: .search, placement: .bottomBar)
            }
        }
        .searchable(text: $searchText)
    }

    @ViewBuilder
    private func symbolButton(_ symbol: SymbolDefinition) -> some View {
        Image(systemName: symbol.icon)
            .font(.system(size: 24))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .aspectRatio(1, contentMode: .fit)
            .background(
                selectedSymbol == symbol.id
                    ? Color.blue : Color(.secondarySystemGroupedBackground)
            )
            .cornerRadius(24)
            .foregroundStyle(selectedSymbol == symbol.id ? .white : .primary)
    }
}

#Preview {
    @Previewable @State var sym: String = "figure.walk"
    SymbolPicker(set: .tracker, selectedSymbol: $sym)
}
