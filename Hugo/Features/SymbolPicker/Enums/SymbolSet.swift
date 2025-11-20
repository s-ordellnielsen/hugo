//
//  SymbolSet.swift
//  Hugo
//
//  Created by Sebastian Nielsen on 20/11/2025.
//

import Foundation

enum SymbolSet: String, CaseIterable {
    case tracker

    var symbols: [SymbolDefinition] {
        switch self {
        case .tracker:
            [
                SymbolDefinition(
                    icon: "figure.walk",
                    name: "symbol.walk",
                    keywordsKey: "symbol.walk.keywords"
                ),
                SymbolDefinition(
                    icon: "phone.fill",
                    name: "symbol.phone",
                    keywordsKey: "symbol.phone.keywords"
                ),
                SymbolDefinition(
                    icon: "phone",
                    name: "symbol.phone",
                    keywordsKey: "symbol.phone.keywords"
                ),
                SymbolDefinition(
                    icon: "envelope",
                    name: "symbol.envelope",
                    keywordsKey: "symbol.envelope.keywords"
                ),
                SymbolDefinition(
                    icon: "pencil",
                    name: "symbol.pencil",
                    keywordsKey: "symbol.pencil.keywords"
                ),
                SymbolDefinition(
                    icon: "pencil.line",
                    name: "symbol.pencil",
                    keywordsKey: "symbol.pencil.keywords"

                ),
                SymbolDefinition(
                    icon: "pencil.and.scribble",
                    name: "symbol.pencil",
                    keywordsKey: "symbol.pencil.keywords"
                ),
            ]
        }
    }
}
