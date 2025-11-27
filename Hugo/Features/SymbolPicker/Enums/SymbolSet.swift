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
                    icon: "paperplane.circle.fill",
                    name: "symbol.paperplane",
                    keywordsKey: "symbol.paperplane.keywords",
                    attributes: [.fill, .cropped]
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
                    icon: "calendar.circle.fill",
                    name: "symbol.calendar",
                    keywordsKey: "symbol.calendar.keywords",
                    attributes: [.cropped, .fill]
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
                    icon: "book.circle.fill",
                    name: "symbol.book",
                    keywordsKey: "symbol.book.keywords",
                    attributes: [.fill, .cropped]
                ),
                SymbolDefinition(
                    icon: "books.vertical",
                    name: "symbol.book",
                    keywordsKey: "symbol.book.keywords",
                    attributes: []
                ),
                SymbolDefinition(
                    icon: "books.vertical.fill",
                    name: "symbol.book",
                    keywordsKey: "symbol.book.keywords",
                    attributes: [.fill]
                ),
                SymbolDefinition(
                    icon: "books.vertical.circle.fill",
                    name: "symbol.book",
                    keywordsKey: "symbol.book.keywords",
                    attributes: [.fill, .cropped]
                ),
                SymbolDefinition(
                    icon: "book.closed",
                    name: "symbol.book",
                    keywordsKey: "symbol.book.keywords",
                    attributes: []
                ),
                SymbolDefinition(
                    icon: "book.closed.fill",
                    name: "symbol.book",
                    keywordsKey: "symbol.book.keywords",
                    attributes: [.fill]
                ),
                SymbolDefinition(
                    icon: "book.closed.circle.fill",
                    name: "symbol.book",
                    keywordsKey: "symbol.book.keywords",
                    attributes: [.cropped, .fill]
                ),
                SymbolDefinition(
                    icon: "rectangle.grid.3x1",
                    name: "symbol.grid",
                    keywordsKey: "symbol.grid.keywords",
                    attributes: []
                ),
                SymbolDefinition(
                    icon: "rectangle.grid.3x1.fill",
                    name: "symbol.grid",
                    keywordsKey: "symbol.grid.keywords",
                    attributes: [.fill]
                ),
                SymbolDefinition(
                    icon: "square.grid.3x1.below.line.grid.1x2",
                    name: "symbol.grid",
                    keywordsKey: "symbol.grid.keywords",
                    attributes: []
                ),
                SymbolDefinition(
                    icon: "square.grid.3x1.below.line.grid.1x2.fill",
                    name: "symbol.grid",
                    keywordsKey: "symbol.grid.keywords",
                    attributes: [.fill]
                ),
                SymbolDefinition(
                    icon: "building",
                    name: "symbol.building",
                    keywordsKey: "symbol.building.keywords",
                    attributes: []
                ),
                SymbolDefinition(
                    icon: "building.fill",
                    name: "symbol.building",
                    keywordsKey: "symbol.building.keywords",
                    attributes: [.fill]
                ),
                SymbolDefinition(
                    icon: "building.2",
                    name: "symbol.building",
                    keywordsKey: "symbol.building.keywords",
                    attributes: []
                ),
                SymbolDefinition(
                    icon: "building.2.fill",
                    name: "symbol.building",
                    keywordsKey: "symbol.building.keywords",
                    attributes: [.fill]
                ),
                SymbolDefinition(
                    icon: "building.2.crop.circle.fill",
                    name: "symbol.building",
                    keywordsKey: "symbol.building.keywords",
                    attributes: [.fill, .cropped]
                ),
                SymbolDefinition(icon: "tag", name: "symbol.tag", keywordsKey: "symbol.tag.keywords", attributes: []),
                SymbolDefinition(icon: "tag.fill", name: "symbol.tag", keywordsKey: "symbol.tag.keywords", attributes: [.fill]),
                SymbolDefinition(icon: "tag.circle.fill", name: "symbol.tag", keywordsKey: "symbol.tag.keywords", attributes: [.fill, .cropped]),
                SymbolDefinition(icon: "bubble.left.and.text.bubble.right", name: "symbol.bubble", keywordsKey: "symbol.bubble.keywords", attributes: []),
                SymbolDefinition(icon: "bubble.left.and.text.bubble.right.fill", name: "symbol.bubble", keywordsKey: "symbol.bubble.keywords", attributes: [.fill]),
                SymbolDefinition(icon: "briefcase", name: "symbol.briefcase", keywordsKey: "symbol.briefcase.keywords", attributes: []),
                SymbolDefinition(icon: "briefcase.fill", name: "symbol.briefcase", keywordsKey: "symbol.briefcase.keywords", attributes: [.fill]),
                SymbolDefinition(icon: "briefcase.circle.fill", name: "symbol.briefcase", keywordsKey: "symbol.briefcase.keywords", attributes: [.fill, .cropped]),
                SymbolDefinition(icon: "house", name: "symbol.house", keywordsKey: "symbol.house.keywords", attributes: []),
                SymbolDefinition(icon: "house.fill", name: "symbol.house", keywordsKey: "symbol.house.keywords", attributes: [.fill]),
                SymbolDefinition(icon: "house.circle.fill", name: "symbol.house", keywordsKey: "symbol.house.keywords", attributes: [.fill, .cropped]),
                SymbolDefinition(icon: "cross.case", name: "symbol.firstaid", keywordsKey: "symbol.firstaid.keywords", attributes: []),
                SymbolDefinition(icon: "cross.case.fill", name: "symbol.firstaid", keywordsKey: "symbol.firstaid.keywords", attributes: [.fill])
            ]
        }
    }
}

#Preview {
    @Previewable @State var selection: String = ""

    SymbolPicker(set: .tracker, selectedSymbol: $selection)
}
