//
//  Content.swift
//  Hugo
//
//  Created by Sebastian Nielsen on 31/10/2025.
//

import SwiftUI
import SwiftData

extension CurrentMonthProgress {
    struct Content: View {
        @Environment(\.modelContext) private var modelContext
        @AppStorage(UserDefaults.publisherStatusKey) var publisherStatusId = ""

        var value: Double

        @State private var showAddItemSheet: Bool = false
        @State private var valueText: String = "0"
        @State private var monthlyGoal: Double = 0.00

        var body: some View {
            ZStack {
                CurrentMonthProgress.ProgressCircle(progress: value, maxValue: monthlyGoal)

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
                    Text("entry.progress.month.hours.label")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary.opacity(0.5))
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
                EntrySheet.Add()
            }
            .onAppear {
                monthlyGoal = getMonthlyGoal()
            }
            .onChange(of: publisherStatusId) {
                print("Publisher Status Changed to: \(publisherStatusId)")
                withAnimation(.bouncy.delay(0.25)) {
                    monthlyGoal = getMonthlyGoal()
                }
            }
            .onChange(of: monthlyGoal) { old, new in
                print("Updating goal from \(old) to \(new)")
            }
        }

        private func getMonthlyGoal() -> Double {
            print("Getting monthly goal")
            let currentConfig = PublisherStatusConfig.current(publisherStatusId)

            return Double(currentConfig?.monthlyGoal() ?? 0)
        }
    }
}

#Preview {
    CurrentMonthProgress.Content(value: 12)
}
