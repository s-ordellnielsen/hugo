//
//  CurrentMonthProgressDetailSheet.swift
//  Hugo
//
//  Created by Sebastian Nielsen on 27/11/2025.
//

import SwiftUI

extension CurrentMonthProgressView {
    struct DetailSheet: View {
        @Environment(\.dismiss) private var dismiss
        
        var body: some View {
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading) {
                        SegmentedProgressView()
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                }
                .background(Color(.systemGroupedBackground))
                .navigationTitle("Detailed Report")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(role: .cancel) {
                            dismiss()
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    CurrentMonthProgressView<EmptyView>.DetailSheet()
}
