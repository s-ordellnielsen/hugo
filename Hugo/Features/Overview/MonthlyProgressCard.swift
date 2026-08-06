import SwiftUI

struct MonthlyProgressCard: View {
    let value: Double
    let monthlyGoal: Double
    let expectedProgress: Double
    let onAddEntry: () -> Void
    let onShowDetails: () -> Void

    @ScaledMetric(relativeTo: .largeTitle) private var heroSize: CGFloat = 80

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Button(action: onShowDetails) {
                ZStack {
                    MonthlyProgressCircle(progress: value, maxValue: monthlyGoal, marker: expectedProgress)
                    VStack {
                        Text(Date.now, format: .dateTime.month(.wide))
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                        Text("\(Int(value))")
                            .font(.system(size: heroSize, weight: .heavy, design: .rounded))
                            .minimumScaleFactor(0.5)
                            .lineLimit(1)
                            .fontWeight(.heavy)
                            .fontDesign(.rounded)
                            .contentTransition(.numericText())
                        MonthlyProgressStatusView(expected: expectedProgress, current: value)
                    }
                }
            }
            .buttonStyle(.card)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(Text("a11y.card.month-progress"))
            .accessibilityValue(Text("\(Int(value)) hours this month"))
            Button(action: onAddEntry) {
                Label("entry.add.label", systemImage: "plus")
                    .padding(12)
            }
            .buttonBorderShape(.circle)
            .font(.largeTitle)
            .labelStyle(.iconOnly)
            .buttonStyle(.glass)
            .padding(.trailing, 8)
            .padding(.bottom, 8)
        }
    }
}
