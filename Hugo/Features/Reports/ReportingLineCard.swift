import SwiftUI

struct ReportingLineCard: View {
    let result: ReportingLineResult
    @Binding var rule: RoundingRule?
    let monthName: (YearMonth) -> String

    @ScaledMetric(relativeTo: .body) private var categoryFontSize = 18
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isPendingChoiceHighlighted = false

    var body: some View {
        VStack(alignment: .leading, spacing: HugoLayout.Spacing.regular) {
            header
            reportedTimeSection
            actualTimeSection
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(.rect(cornerRadius: HugoLayout.CornerRadius.card))
        .task(id: isUndecided && !reduceMotion) {
            guard isUndecided, !reduceMotion else {
                isPendingChoiceHighlighted = false
                return
            }

            while !Task.isCancelled {
                withAnimation(.easeInOut(duration: 1.1)) {
                    isPendingChoiceHighlighted.toggle()
                }
                try? await Task.sleep(for: .seconds(1.1))
            }
        }
    }

    private var header: some View {
        HStack(spacing: HugoLayout.Spacing.regular) {
            Image(systemName: result.line.iconName)
                .frame(width: HugoLayout.Size.categoryIcon, height: HugoLayout.Size.categoryIcon)
                .background(.mint)
                .foregroundStyle(.white)
                .clipShape(.circle)
                .accessibilityHidden(true)

            lineTitle
                .fontWeight(.medium)
                .font(.system(size: categoryFontSize))

            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private var lineTitle: some View {
        if result.line.type == .main {
            Text("category.default.label")
        } else {
            Text(verbatim: result.line.name)
        }
    }

    @ViewBuilder
    private var carriedInRow: some View {
        if result.line.carriedInSeconds > 0, !result.line.carriedInFrom.isEmpty {
            let duration = ServiceDurationFormatter.accessibilityString(from: result.line.carriedInSeconds)
            let months = result.line.carriedInFrom.map(monthName).joined(separator: ", ")
            let label = Text("report.line.carried-in.\(duration).\(months)")

            HStack(alignment: .firstTextBaseline, spacing: HugoLayout.Spacing.compact) {
                Text("↘")
                    .accessibilityHidden(true)
                label
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(label)
        }
    }

    private var reportedTimeSection: some View {
        VStack(alignment: .leading, spacing: HugoLayout.Spacing.compact) {
            reportedTimeLabel
            reportedTimeValue

            if result.line.needsRule {
                roundingRulePicker
            }
        }
        .padding(.top, HugoLayout.Spacing.compact)
        .accessibilityElement(children: .contain)
    }

    private var reportedTimeLabel: some View {
        Text("report.line.reported")
            .font(.caption)
            .foregroundStyle(.secondary)
    }

    private var reportedTimeValue: some View {
        Group {
            if isUndecided {
                Text("report.line.not-finalized")
                    .opacity(reduceMotion || isPendingChoiceHighlighted ? 1 : 0.65)
            } else {
                Text(verbatim: reportedTime)
                    .contentTransition(.numericText())
                    .motion(Motion.value, value: result.submittedHours)
            }
        }
        .font(.title2.weight(.semibold))
        .monospacedDigit()
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var actualTimeSection: some View {
        if showsActualTime || hasCarriedIn {
            VStack(alignment: .leading, spacing: HugoLayout.Spacing.compact) {
                if showsActualTime {
                    actualTimeRow
                }

                carriedInRow
            }
            .padding(.top, HugoLayout.Spacing.spacious)
            .accessibilityElement(children: .combine)
        }
    }

    private var actualTimeRow: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline, spacing: HugoLayout.Spacing.tight) {
                Text("report.line.actual")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                actualTimeValue
            }
            .fixedSize(horizontal: true, vertical: false)

            VStack(alignment: .leading, spacing: HugoLayout.Spacing.tight) {
                Text("report.line.actual")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                actualTimeValue
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var showsActualTime: Bool {
        isUndecided || actualDurationComponents.minutes > 0 || result.submittedHours != actualDurationComponents.hours
    }

    private var hasCarriedIn: Bool {
        result.line.carriedInSeconds > 0 && !result.line.carriedInFrom.isEmpty
    }

    private var actualTimeValue: some View {
        Text(verbatim: actualTime)
            .font(.subheadline)
            .foregroundStyle(.primary)
            .monospacedDigit()
            .accessibilityLabel(Text(verbatim: actualTimeAccessibilityLabel))
    }

    private var actualDurationComponents: (hours: Int, minutes: Int) {
        let seconds = max(result.line.actualSeconds, 0)
        let hours = Int(seconds / 3_600)
        let minutes = Int(seconds.truncatingRemainder(dividingBy: 3_600) / 60)
        return (hours, minutes)
    }

    private var actualHoursText: String {
        Duration.seconds(actualDurationComponents.hours * 3_600)
            .formatted(Duration.UnitsFormatStyle(allowedUnits: [.hours], width: .wide))
    }

    private var actualTime: String {
        guard actualDurationComponents.minutes > 0 else { return actualHoursText }
        let minutesText = Duration.seconds(actualDurationComponents.minutes * 60)
            .formatted(Duration.UnitsFormatStyle(allowedUnits: [.minutes], width: .abbreviated))
        return "\(actualHoursText) \(minutesText)"
    }

    private var actualTimeAccessibilityLabel: String {
        guard actualDurationComponents.minutes > 0 else { return actualHoursText }
        return ServiceDurationFormatter.accessibilityString(from: result.line.actualSeconds)
    }

    private var reportedTime: String {
        Duration.seconds(result.submittedHours * 3_600)
            .formatted(Duration.UnitsFormatStyle(allowedUnits: [.hours], width: .wide))
    }

    private var isUndecided: Bool {
        if case .undecided = result.disposition {
            return true
        }
        return false
    }

    private var roundingRulePicker: some View {
        Menu {
            ForEach(RoundingRule.allCases) { option in
                Button {
                    rule = option
                } label: {
                    if rule == option {
                        Label(option.localizedName, systemImage: "checkmark")
                    } else {
                        Text(option.localizedName)
                    }
                }
            }
        } label: {
            HStack(spacing: HugoLayout.Spacing.small) {
                roundingDispositionLabel
                Image(systemName: "chevron.down")
                    .font(.caption2)
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(roundingDispositionAccessibilityLabel)
        .accessibilityHint(Text("report.line.choose-action-hint"))
    }

    private var roundingDispositionAccessibilityLabel: Text {
        switch result.disposition {
        case .none:
            Text("report.line.reported")
        case .undecided(let seconds):
            Text("report.line.choose.\(ServiceDurationFormatter.accessibilityString(from: seconds))")
        case .roundedUp(let seconds):
            Text("report.line.rounded-up.\(ServiceDurationFormatter.accessibilityString(from: seconds))")
        case .roundedDown(let seconds):
            Text("report.line.rounded-down.\(ServiceDurationFormatter.accessibilityString(from: seconds))")
        case .transferred(let seconds):
            Text("report.line.transferred.\(ServiceDurationFormatter.accessibilityString(from: seconds))")
        }
    }

    @ViewBuilder
    private var roundingDispositionLabel: some View {
        switch result.disposition {
        case .none:
            EmptyView()
        case .undecided:
            Text("report.line.handle-extra-minutes")
        case .roundedUp(let seconds):
            dispositionLabel(
                glyph: "⤒",
                text: Text("report.line.rounded-up.\(ServiceDurationFormatter.accessibilityString(from: seconds))")
            )
        case .roundedDown(let seconds):
            dispositionLabel(
                glyph: "⤓",
                text: Text("report.line.rounded-down.\(ServiceDurationFormatter.accessibilityString(from: seconds))")
            )
        case .transferred(let seconds):
            dispositionLabel(
                glyph: "↗",
                text: Text("report.line.transferred.\(ServiceDurationFormatter.accessibilityString(from: seconds))")
            )
        }
    }

    private func dispositionLabel(glyph: String, text: Text) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: HugoLayout.Spacing.compact) {
            Text(verbatim: glyph)
                .accessibilityHidden(true)
            text
        }
        .accessibilityElement(children: .combine)
    }

}
