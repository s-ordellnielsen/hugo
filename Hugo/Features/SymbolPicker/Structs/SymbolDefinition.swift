//
//  SymbolDefinition.swift
//  Hugo
//
//  Created by Sebastian Nielsen on 20/11/2025.
//

import Foundation

struct SymbolDefinition: Codable, Identifiable {
    let icon: String
    let name: LocalizedStringResource
    let keywordsKey: LocalizedStringResource
    
    var id: String { self.icon }
    
    private var localizedName: String {
        String(localized: name)
    }
    
    private var keywords: [String] {
        let keywordsString = String(localized: keywordsKey)
        return keywordsString
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
    }
    
    func matches(_ searchText: String) -> Bool {
        guard !searchText.isEmpty else { return true }
        
        let query = searchText.lowercased()
        
        // Search in name
        if localizedName.lowercased().contains(query) {
            return true
        }
        
        // Search in keywords
        return keywords.contains { $0.lowercased().contains(query) }
    }
}
