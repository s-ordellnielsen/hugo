//
//  DebuggingView.swift
//  Hugo
//
//  Created by Sebastian Nielsen on 20/11/2025.
//

import SwiftUI

struct DebuggingView: View {
    @AppStorage("isOnboarding") var isOnboarding: Bool = false
    
    var body: some View {
        List {
            Button("Reset Onboarding", systemImage: "arrow.counterclockwise") {
                isOnboarding = true
            }
        }
        .navigationTitle("Debugging")
    }
}

#Preview {
    DebuggingView()
}
