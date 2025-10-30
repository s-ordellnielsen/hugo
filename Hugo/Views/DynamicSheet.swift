//
//  DynamicSheet.swift
//  Hugo
//
//  Created by Sebastian Nielsen on 23/10/2025.
//

import SwiftUI

struct DynamicSheet<Content: View>: View {
    var animation: Animation = .bouncy
    @ViewBuilder var content: Content
    @State private var height: CGFloat = 0
    
    var body: some View {
        ZStack {
            content
                .fixedSize(horizontal: false, vertical: true)
                .onGeometryChange(for: CGSize.self) {
                    $0.size
                } action: { newValue in
                    if height == .zero {
                        height = min(newValue.height, windowSize.height - 110)
                    } else {
                        withAnimation(animation) {
                            height = min(newValue.height, windowSize.height - 110)
                        }
                    }
                }
        }
        .modifier(SheetHeightModifier(height: height))
    }
    
    var windowSize: CGSize {
        if let size = (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.screen.bounds.size {
            return size
        }
        
        return .zero
    }
}

fileprivate struct SheetHeightModifier: ViewModifier, Animatable {
    var height: CGFloat
    var animatableData: CGFloat {
        get { height }
        set { height = newValue }
    }
    
    func body(content: Content) -> some View {
        content
            .presentationDetents(height == .zero ? [.medium] : [.height(height)])
    }
}

#Preview {
    ContentView()
}
