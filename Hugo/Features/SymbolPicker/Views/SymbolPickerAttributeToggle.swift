//
//  SymbolPickerAttributeToggle.swift
//  Hugo
//
//  Created by Sebastian Nielsen on 21/11/2025.
//

import SwiftUI

extension SymbolPicker {
    struct AttributeToggle: View {
        @Binding var selection: [SymbolAttribute]
        
        var target: SymbolAttribute
        
        @State private var internalState: Bool = false
        
        var body: some View {
            Toggle(isOn: $internalState) {
                Label(target.label, systemImage: target.icon)
            }
            .onAppear {
                if selection.contains(target) {
                    internalState = true
                }
            }
            .onChange(of: internalState) { _, newValue in
                if newValue == true {
                    if !selection.contains(target) {
                        selection.append(target)
                    }
                } else {
                    if selection.contains(target) {
                        selection.removeAll { $0 == target }
                    }
                }
            }
            .onChange(of: selection) { _, newValue in
                internalState = newValue.contains(target)
            }
        }
    }
}

#Preview {
    @Previewable @State var selection: [SymbolAttribute] = []

    SymbolPicker.AttributeToggle(selection: $selection, target: .fill)
}
