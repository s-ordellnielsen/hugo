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
    @State private var filteredSymbols: [SymbolDefinition] = []

    private func refreshFilter() {
        if searchText.isEmpty && attributes == nil {
            filteredSymbols = set.symbols
        } else {
            filteredSymbols = set.symbols.filter { $0.matches(searchText, attributes) }
        }
    }

    private var columns: [GridItem] {
        let count = UIDevice.current.userInterfaceIdiom == .pad ? 8 : 4
        return Array(repeating: GridItem(.flexible(minimum: 70)), count: count)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
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
            .navigationTitle("symbolPicker.field.icon.pickAnIcon")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem {
                    Menu {
                        Button {
                            attributes = nil
                        } label: {
                            Text("symbolPicker.filter.showAll.label")
                        }
                        Divider()
                        Picker("symbolPicker.filter.attributes.label", selection: $attributes) {
                            ForEach(SymbolAttribute.allCases, id: \.id) { attribute in
                                Label(attribute.label, systemImage: attribute.icon)
                                    .tag(attribute)
                            }
                        }
                    } label: {
                        Label(
                            "common.filter",
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
        .onAppear {
            refreshFilter()
        }
        .onChange(of: searchText) {
            refreshFilter()
        }
        .onChange(of: attributes) {
            refreshFilter()
        }
    }

    @ViewBuilder
    private func symbolButton(_ symbol: SymbolDefinition) -> some View {
        Image(systemName: symbol.icon)
            .font(.system(size: 24))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .aspectRatio(1, contentMode: .fit)
            .background(
                selectedSymbol == symbol.id
                    ? Color.accent : Color(.secondarySystemGroupedBackground)
            )
            .cornerRadius(24)
            .accessibilityLabel(Text(symbol.name))
            .accessibilityAddTraits(selectedSymbol == symbol.id ? [.isButton, .isSelected] : .isButton)
            .foregroundStyle(selectedSymbol == symbol.id ? .white : .primary)
    }
}

#Preview {
    @Previewable @State var sym: String = "figure.walk"
    SymbolPicker(set: .tracker, selectedSymbol: $sym)
}
