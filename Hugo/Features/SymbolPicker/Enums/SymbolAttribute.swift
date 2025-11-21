//
//  SymbolAttribute.swift
//  Hugo
//
//  Created by Sebastian Nielsen on 21/11/2025.
//

import Foundation

enum SymbolAttribute: String, Codable, CaseIterable, Identifiable, Equatable {
    case fill
    case cropped

    var id: Self { self }

    var label: LocalizedStringResource {
        switch self {
        case .fill:
            return "symbol.attr.fill"
        case .cropped:
            return "symbol.attr.cropped"
        }
    }

    var icon: String {
        switch self {
        case .fill:
            return "circle.lefthalf.filled.righthalf.striped.horizontal"
        case .cropped:
            return "building.2.crop.circle.fill"
        }
    }
}
