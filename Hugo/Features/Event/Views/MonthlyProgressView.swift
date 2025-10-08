//
//  MonthlyProgressView.swift
//  Hugo
//
//  Created by Sebastian Nielsen on 08/10/2025.
//

import SwiftUI
import SwiftData

struct MonthlyProgressView: View {
    @Environment(\.modelContext) private var modelContext

    var value: Double

    @State private var showAddItemSheet: Bool = false
    @State private var valueText: String = "0"

    var body: some View {
        ZStack {
            LargeProgressCircle(progress: value, max: 50.0)

            VStack {
                Text("October")
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
                Text("Hours")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary.opacity(0.5))
            }

            Button {
                showAddItemSheet.toggle()
            } label: {
                Image(systemName: "plus")
                    .font(.largeTitle)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary.opacity(0.80))
                    .padding(12)
            }
            .buttonBorderShape(.circle)
            .buttonStyle(.glass)
            .offset(x: 128, y: 128)

        }
        .sheet(isPresented: $showAddItemSheet) {
            AddEventSheet(submitAction: addItem)
                .presentationDetents([.large])
        }
    }
    
    private func addItem(date: Date, duration: Int) {
        withAnimation(.bouncy.delay(0.5)) {
            let newItem = Event(
                type: EventType.fieldService,
                timestamp: date,
                duration: duration
            )
            modelContext.insert(newItem)
        }
    }
}

#Preview {
    MonthlyProgressView(value: 32)
}
