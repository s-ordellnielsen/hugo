//
//  SymbolDefinition.swift
//  Hugo
//
//  Created by Sebastian Nielsen on 20/11/2025.
//

import Foundation

nonisolated struct SymbolDefinition: Codable, Identifiable {
    let icon: String
    let name: LocalizedStringResource
    let keywordsKey: LocalizedStringResource
    let attributes: [SymbolAttribute]

    var id: String { self.icon }

    nonisolated private var localizedName: String {
        String(localized: name)
    }

    nonisolated private var keywords: [String] {
        let keywordsString = String(localized: keywordsKey)
        return
            keywordsString
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
    }

    nonisolated func matches(_ searchText: String, _ attr: SymbolAttribute?) -> Bool {
        var satisfiesAttributes: Bool = true

        if attr != nil && !attributes.contains(attr!) {
            satisfiesAttributes = false
        }

        guard !searchText.isEmpty && satisfiesAttributes else {
            return satisfiesAttributes
        }

        let query = searchText.lowercased()

        if localizedName.lowercased().contains(query) {
            return true
        }

        return keywords.contains { $0.lowercased().contains(query) }
    }
}
