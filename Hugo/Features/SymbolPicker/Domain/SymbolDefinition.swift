import Foundation

nonisolated struct SymbolDefinition: Identifiable, Sendable {
    let icon: String
    let name: LocalizedStringResource
    let keywordsKey: LocalizedStringResource
    let attributes: [SymbolAttribute]
    let searchIndex: [String]

    var id: String { icon }

    init(
        icon: String,
        name: LocalizedStringResource,
        keywordsKey: LocalizedStringResource,
        attributes: [SymbolAttribute]
    ) {
        self.icon = icon
        self.name = name
        self.keywordsKey = keywordsKey
        self.attributes = attributes

        let localizedName = String(localized: name).lowercased()
        let keywords = String(localized: keywordsKey)
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty }
        self.searchIndex = [localizedName] + keywords
    }

    func matches(_ searchText: String, _ attribute: SymbolAttribute?) -> Bool {
        if let attribute, !attributes.contains(attribute) { return false }
        guard !searchText.isEmpty else { return true }
        let query = searchText.lowercased()
        return searchIndex.contains { $0.contains(query) }
    }
}
