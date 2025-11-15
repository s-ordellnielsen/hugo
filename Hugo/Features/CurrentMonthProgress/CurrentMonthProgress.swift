//
//  CurrentMonthProgress.swift
//  Hugo
//
//  Created by Sebastian Nielsen on 31/10/2025.
//

import SwiftUI

struct CurrentMonthProgressView<SheetContent: View>: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage(UserDefaults.publisherStatusKey) var publisherStatusId = ""

    var value: Double

    @State private var showAddItemSheet: Bool = false
    @State private var valueText: String = "0"
    @State private var monthlyGoal: Double = 0.00
    
    @ViewBuilder var addItemSheet: () -> SheetContent
    
    var marker: Double {
        let calendar = Calendar.current
        let now = Date.now
        
        let currentDay = calendar.component(.day, from: now)
        let daysInMonth = calendar.range(of: .day, in: .month, for: now)!.count
        
        return Double(currentDay) / Double(daysInMonth) * monthlyGoal
    }

    var body: some View {
        ZStack {
            ProgressCircle(progress: value, maxValue: monthlyGoal, marker: marker)

            VStack {
                Text(Date.now, format: .dateTime.month(.wide))
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                Text(valueText)
                    .font(.system(size: 80))
                    .fontWeight(.heavy)
                    .fontDesign(.rounded)
                    .contentTransition(.numericText())
                    .onAppear {
                        withAnimation(.bouncy.delay(0.05)) {
                            self.valueText = "\(Int(self.value))"
                        }
                    }
                    .onChange(of: value) { oldValue, newValue in
                        withAnimation {
                            self.valueText = "\(Int(newValue))"
                        }
                    }
                StatusText(expectedProgress: marker, currentProgress: value)
            }

            Button {
                showAddItemSheet = true
            } label: {
                Label("entry.add.label", systemImage: "plus")
                    .padding(12)
            }
            .buttonBorderShape(.circle)
            .font(.largeTitle)
            .fontWeight(.semibold)
            .foregroundStyle(.accent)
            .labelStyle(.iconOnly)
            .buttonStyle(.glass)
            .offset(x: 128, y: 128)

        }
        .sheet(isPresented: $showAddItemSheet) {
            addItemSheet()
        }
        .onAppear {
            monthlyGoal = getMonthlyGoal()
        }
        .onChange(of: publisherStatusId) {
            monthlyGoal = getMonthlyGoal()
        }
    }

    private func getMonthlyGoal() -> Double {
        let currentConfig = PublisherStatusConfig.current(publisherStatusId)

        return Double(currentConfig?.monthlyGoal() ?? 0)
    }
}

#Preview {
    CurrentMonthProgressView(value: 34) {
        EntrySheet.Add()
    }
}
