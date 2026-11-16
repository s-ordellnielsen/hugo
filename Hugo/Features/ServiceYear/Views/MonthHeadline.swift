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
    /// Draws the number faded, for a month with nothing logged.
    var isFaded = false

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

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: HugoLayout.Spacing.compact) {
            Text(headline.value, format: .number)
                .font(.system(size == .large ? .largeTitle : .title, design: .serif, weight: .bold))
                .foregroundStyle(isFaded ? .tertiary : .primary)
                .contentTransition(.numericText(value: Double(headline.value)))
            Text(unitLabel)
                .font(.system(size == .large ? .title2 : .title3, design: .serif, weight: .semibold))
                .foregroundStyle(isFaded ? .tertiary : .secondary)
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
