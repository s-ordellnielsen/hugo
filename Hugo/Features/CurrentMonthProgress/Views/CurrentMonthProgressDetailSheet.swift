//
//  CurrentMonthProgressDetailSheet.swift
//  Hugo
//
//  Created by Sebastian Nielsen on 27/11/2025.
//

import SwiftUI

extension CurrentMonthProgressView {
    struct DetailSheet: View {
        var body: some View {
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading) {

                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                }
                .background(Color(.systemGroupedBackground))
                .navigationTitle("Detailed Report")
                .navigationBarTitleDisplayMode(.inline)
            }
        }
    }
}

#Preview {
    CurrentMonthProgressView<EmptyView>.DetailSheet()
}
