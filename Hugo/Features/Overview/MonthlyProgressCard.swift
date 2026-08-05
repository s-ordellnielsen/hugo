import SwiftUI

struct MonthlyProgressCard: View {
    let value: Double
    let monthlyGoal: Double
    let expectedProgress: Double
    let onAddEntry: () -> Void
    let onShowDetails: () -> Void

    var body: some View {
        ZStack {
            Button(action: onShowDetails) {
                MonthlyProgressCircle(progress: value, maxValue: monthlyGoal, marker: expectedProgress)
                VStack {
                    Text(Date.now, format: .dateTime.month(.wide))
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                    Text("\(Int(value))")
                        .font(.system(size: 80))
                        .fontWeight(.heavy)
                        .fontDesign(.rounded)
                        .contentTransition(.numericText())
                    MonthlyProgressStatusView(expected: expectedProgress, current: value)
                }
                Button(action: onAddEntry) { Label("entry.add.label", systemImage: "plus").padding(12) }
                    .buttonBorderShape(
                        .circle
                    )
                    .font(.largeTitle)
                    .labelStyle(.iconOnly)
                    .buttonStyle(.glass)
                    .offset(x: 128, y: 128)
            }
            .buttonStyle(.card)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(Text("a11y.card.month-progress"))
            .accessibilityValue(Text("\(Int(value)) hours this month"))
        }
    }
}
