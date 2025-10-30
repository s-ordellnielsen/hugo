//
//  ReportView.swift
//  Hugo
//
//  Created by Sebastian Nielsen on 08/10/2025.
//

import SwiftData
import SwiftUI

struct ReportView: View {
    var body: some View {
        NavigationStack {
            MonthlyReportList.Content()
                .navigationTitle("report.title")
                .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    ReportView()
        .modelContainer(.preview)
}
