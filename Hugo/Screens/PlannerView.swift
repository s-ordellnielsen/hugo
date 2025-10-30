//
//  CalendarView.swift
//  Hugo
//
//  Created by Sebastian Nielsen on 06/10/2025.
//

import SwiftUI

struct PlannerView: View {
    var body: some View {
        NavigationStack {
            VStack {
                Text("misc.comingsoon")
                Button {
                    
                } label: {
                    Label("misc.comingsoon", systemImage: "star")
                }
                .buttonStyle(.glassProminent)
            }
            .navigationTitle(Text("planner.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem {
                    AccountViewButton()
                }
            }
        }
    }
}

#Preview {
    PlannerView()
}
