import SwiftUI

/// A month's credited time as one large serif number with its unit, as the
/// month cards on the Year tab and the month detail page show it.
struct MonthHeadline: View {
    enum Size {
        /// On a month card.
        case regular
        /// At the top of the month detail page.
        case large
    }

    let seconds: TimeInterval
    var size: Size = .regular
    /// Draws the number faded, for a regular-size month with nothing logged.
    /// The large size is never faded.
    var isFaded = false

    @ScaledMetric(relativeTo: .largeTitle) private var largeNumberSize: CGFloat = 56

    /// The large headline is never faded: it is the page's main number.
    private var fades: Bool { isFaded && size == .regular }

    private var headline: HeadlineDuration {
        HeadlineDuration(seconds: seconds)
    }

    private var unitLabel: LocalizedStringKey {
        switch headline {
        case .minutes: "duration.minutesUnit"
        case .hours(1): "service_year.month.hour"
        case .hours: "service_year.month.hours"
        }
    }

    private var numberFont: Font {
        size == .large
            ? .system(size: largeNumberSize, weight: .bold, design: .serif)
            : .system(.title, design: .serif, weight: .bold)
    }

    private var unitFont: Font {
        .system(size == .large ? .title2 : .title3, design: .serif, weight: .semibold)
    }

    @ViewBuilder
    private var number: some View {
        let text = Text(headline.value, format: .number)
            .font(numberFont)
            .foregroundStyle(fades ? AnyShapeStyle(.tertiary) : AnyShapeStyle(Color.primary))
            .contentTransition(.numericText(value: Double(headline.value)))
        if size == .large {
            text
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.5)
        } else {
            text
        }
    }

    private var unit: some View {
        Text(unitLabel)
            .font(unitFont)
            .foregroundStyle(fades ? AnyShapeStyle(.tertiary) : AnyShapeStyle(.secondary))
    }

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline, spacing: HugoLayout.Spacing.compact) {
                number
                unit
            }
            VStack(alignment: .leading, spacing: HugoLayout.Spacing.compact) {
                number
                unit
            }
        }
        .animation(.snappy, value: headline)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: headline.spokenText()))
    }
}

#Preview {
    VStack(alignment: .leading) {
        MonthHeadline(seconds: 42 * 3_600, size: .large)
        MonthHeadline(seconds: 45 * 60)
        MonthHeadline(seconds: 0, isFaded: true)
    }
}

#Preview("Large, accessibility size") {
    MonthHeadline(seconds: 142 * 3_600, size: .large)
        .dynamicTypeSize(.accessibility3)
        .padding()
}
