//
//  PersonalDetailsView.swift
//  Hugo
//
//  Created by Sebastian Nielsen on 09/10/2025.
//

import SwiftUI

struct PersonalDetailsView: View {
    var body: some View {
        List {
            Section {
                VStack(alignment: .center, spacing: 12) {
                    Circle()
                        .frame(width: 128, height: 128)
                    Button{
                        
                    } label: {
                        Text("account.page.personaldetails.changeprofilepicture")
                            .fontWeight(.semibold)
                    }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.capsule)
                }
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear)
            }

            Section {
                Button {

                } label: {
                    Label("Test", systemImage: "person.crop.circle")
                }
            }
        }
        .navigationTitle("account.page.personaldetails.title")
    }
}

#Preview {
    PersonalDetailsView()
}
