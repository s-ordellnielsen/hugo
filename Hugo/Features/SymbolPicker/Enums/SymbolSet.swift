//
//  SymbolSet.swift
//  Hugo
//
//  Created by Sebastian Nielsen on 20/11/2025.
//

import Foundation
import SwiftUI

enum SymbolSet: String, CaseIterable {
    case tracker

    var symbols: [SymbolDefinition] {
        switch self {
        case .tracker:
            [
                SymbolDefinition(
                    icon: "figure.walk",
                    name: "symbol.walk",
                    keywordsKey: "symbol.walk.keywords",
                    attributes: []
                ),
                SymbolDefinition(
                    icon: "phone.fill",
                    name: "symbol.phone",
                    keywordsKey: "symbol.phone.keywords",
                    attributes: [.fill]
                ),
                SymbolDefinition(
                    icon: "phone",
                    name: "symbol.phone",
                    keywordsKey: "symbol.phone.keywords",
                    attributes: []
                ),
                SymbolDefinition(
                    icon: "envelope",
                    name: "symbol.envelope",
                    keywordsKey: "symbol.envelope.keywords",
                    attributes: []
                ),
                SymbolDefinition(
                    icon: "envelope.fill",
                    name: "symbol.envelope",
                    keywordsKey: "symbol.envelope.keywords",
                    attributes: [.fill]
                ),
                SymbolDefinition(
                    icon: "pencil",
                    name: "symbol.pencil",
                    keywordsKey: "symbol.pencil.keywords",
                    attributes: []
                ),
                SymbolDefinition(
                    icon: "pencil.line",
                    name: "symbol.pencil",
                    keywordsKey: "symbol.pencil.keywords",
                    attributes: []

                ),
                SymbolDefinition(
                    icon: "pencil.and.scribble",
                    name: "symbol.pencil",
                    keywordsKey: "symbol.pencil.keywords",
                    attributes: []
                ),
                SymbolDefinition(
                    icon: "folder",
                    name: "symbol.folder",
                    keywordsKey: "symbol.folder.keywords",
                    attributes: []
                ),
                SymbolDefinition(
                    icon: "folder.fill",
                    name: "symbol.folder",
                    keywordsKey: "symbol.folder.keywords",
                    attributes: [.fill]
                ),
                SymbolDefinition(
                    icon: "paperplane",
                    name: "symbol.paperplane",
                    keywordsKey: "symbol.paperplane.keywords",
                    attributes: []
                ),
                SymbolDefinition(
                    icon: "paperplane.fill",
                    name: "symbol.paperplane",
                    keywordsKey: "symbol.paperplane.keywords",
                    attributes: [.fill]
                ),
                SymbolDefinition(
                    icon: "document",
                    name: "symbol.document",
                    keywordsKey: "symbol.document.keywords",
                    attributes: []
                ),
                SymbolDefinition(
                    icon: "document.fill",
                    name: "symbol.document",
                    keywordsKey: "symbol.document.keywords",
                    attributes: [.fill]
                ),
                SymbolDefinition(
                    icon: "calendar",
                    name: "symbol.calendar",
                    keywordsKey: "symbol.calendar.keywords",
                    attributes: []
                ),
                SymbolDefinition(
                    icon: "arrowshape.left.fill",
                    name: "symbol.arrowshape",
                    keywordsKey: "symbol.arrowshape.keywords",
                    attributes: [.fill]
                ),
                SymbolDefinition(
                    icon: "arrowshape.right.fill",
                    name: "symbol.arrowshape",
                    keywordsKey: "symbol.arrowshape.keywords",
                    attributes: [.fill]
                ),
                SymbolDefinition(
                    icon: "arrowshape.up.fill",
                    name: "symbol.arrowshape",
                    keywordsKey: "symbol.arrowshape.keywords",
                    attributes: [.fill]
                ),
                SymbolDefinition(
                    icon: "arrowshape.down.fill",
                    name: "symbol.arrowshape",
                    keywordsKey: "symbol.arrowshape.keywords",
                    attributes: [.fill]
                ),
                SymbolDefinition(
                    icon: "book",
                    name: "symbol.book",
                    keywordsKey: "symbol.book.keywords",
                    attributes: []
                ),
                SymbolDefinition(
                    icon: "book.fill",
                    name: "symbol.book",
                    keywordsKey: "symbol.book.keywords",
                    attributes: [.fill]
                ),
                SymbolDefinition(
                    icon: "rectangle.grid.3x1",
                    name: "symbol.grid",
                    keywordsKey: "symbol.grid.keywords",
                    attributes: []
                ),
                SymbolDefinition(icon: "rectangle.grid.3x1.fill", name: "symbol.grid", keywordsKey: "symbol.grid.keywords", attributes: [.fill]),
                SymbolDefinition(icon: "square.grid.3x1.below.line.grid.1x2", name: "symbol.grid", keywordsKey: "symbol.grid.keywords", attributes: []),
                SymbolDefinition(icon: "square.grid.3x1.below.line.grid.1x2.fill", name: "symbol.grid", keywordsKey: "symbol.grid.keywords", attributes: [.fill]),
                SymbolDefinition(icon: "building", name: "symbol.building", keywordsKey: "symbol.building.keywords", attributes: []),
                SymbolDefinition(icon: "building.fill", name: "symbol.building", keywordsKey: "symbol.building.keywords", attributes: [.fill]),
                SymbolDefinition(icon: "building.2", name: "symbol.building", keywordsKey: "symbol.building.keywords", attributes: []),
                SymbolDefinition(icon: "building.2.fill", name: "symbol.building", keywordsKey: "symbol.building.keywords", attributes: [.fill]),
                SymbolDefinition(icon: "building.2.crop.circle.fill", name: "symbol.building", keywordsKey: "symbol.building.keywords", attributes: [.fill, .cropped])
            ]
        }
    }
}

#Preview {
    @Previewable @State var selection: String = ""

    SymbolPicker(set: .tracker, selectedSymbol: $selection)
}
