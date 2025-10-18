//
//  ReportView.swift
//  Hugo
//
//  Created by Sebastian Nielsen on 08/10/2025.
//

import SwiftUI

struct ReportView: View {
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
            .navigationTitle(Text("Report"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem {
                    AccountViewButton()
                }
            }
        }    }
}

#Preview {
    ReportView()
}
