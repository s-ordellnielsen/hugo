import SwiftUI

/// A strip of calendar years with a band in the middle that holds one
/// theocratic year, for example `2025 [2026 / 2027] 2028`. A flick glides
/// through the years and settles with a whole theocratic year in the band.
/// The Year tab shows that year once the strip comes to rest.
struct TheocraticYearPicker: View {
    /// The pager's years, oldest first, with no gaps.
    let years: [TheocraticYear]
    /// The year the Year tab shows.
    let selection: TheocraticYear
    let onSelect: (TheocraticYear) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled
    @ScaledMetric(relativeTo: .title3) private var cellWidth: CGFloat = HugoLayout.Size.yearPickerCellWidth

    @State private var position = ScrollPosition(edge: .leading)
    @State private var yearInBand: TheocraticYear?
    @State private var scrollPhase: ScrollPhase = .idle

    private var layout: TheocraticYearStripLayout {
        TheocraticYearStripLayout(
            years: years,
            cellWidth: cellWidth,
            maximumStripWidth: HugoLayout.Size.yearPickerMaximumStripWidth
        )
    }

    private var shownYear: TheocraticYear {
        yearInBand ?? selection
    }

    var body: some View {
        let layout = self.layout
        VStack(spacing: HugoLayout.Spacing.regular) {
            strip(layout)
            Text("year.picker.hint")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, HugoLayout.Spacing.spacious)
        .padding(.vertical, HugoLayout.Spacing.card)
        .dynamicTypeSize(...DynamicTypeSize.xxLarge)
        .onAppear {
            yearInBand = selection
            position.scrollTo(x: layout.offset(for: selection))
        }
    }

    private func strip(_ layout: TheocraticYearStripLayout) -> some View {
        ScrollView(.horizontal) {
            HStack(spacing: 0) {
                ForEach(layout.calendarYears, id: \.self) { calendarYear in
                    Button {
                        handleTap(on: calendarYear, layout: layout)
                    } label: {
                        Text(String(calendarYear))
                            .font(.system(.title3, design: .serif, weight: .bold))
                            .monospacedDigit()
                            .frame(width: layout.cellWidth)
                            .frame(minHeight: HugoLayout.Size.minimumHitTarget)
                            .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .visualEffect { content, proxy in
                        content.opacity(
                            layout.emphasis(forCellMidX: proxy.frame(in: .scrollView(axis: .horizontal)).midX)
                        )
                    }
                }
            }
            .padding(.horizontal, layout.edgePadding)
        }
        .frame(width: layout.stripWidth)
        .scrollIndicators(.hidden)
        .scrollTargetBehavior(TheocraticYearStripSnapping(layout: layout))
        .scrollPosition($position)
        .onScrollGeometryChange(for: TheocraticYear.self) { geometry in
            layout.year(forOffset: geometry.contentOffset.x + geometry.contentInsets.leading)
        } action: { _, year in
            yearInBand = year
        }
        .onScrollPhaseChange { _, phase in
            scrollPhase = phase
            if phase == .idle {
                select(yearInBand)
            }
        }
        .sensoryFeedback(.selection, trigger: yearInBand) { _, _ in
            scrollPhase != .idle
        }
        .mask {
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0),
                    .init(color: .black, location: 0.1),
                    .init(color: .black, location: 0.9),
                    .init(color: .clear, location: 1),
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
        }
        .background {
            Capsule()
                .fill(Color(.tertiarySystemFill))
                .frame(width: layout.cellWidth * 2)
        }
        .overlay {
            Text(String("/"))
                .font(.system(.title3, design: .serif, weight: .bold))
                .foregroundStyle(.secondary)
                .allowsHitTesting(false)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("year.picker.a11y.label")
        .accessibilityValue(shownYear.spokenName)
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment:
                move(to: layout.year(shownYear, movedBy: 1), layout: layout)
            case .decrement:
                move(to: layout.year(shownYear, movedBy: -1), layout: layout)
            @unknown default:
                break
            }
        }
    }

    private func handleTap(on calendarYear: Int, layout: TheocraticYearStripLayout) {
        switch layout.tapAction(forCalendarYear: calendarYear, yearInBand: shownYear) {
        case .close:
            dismiss()
        case .select(let year):
            move(to: year, layout: layout)
        }
    }

    /// Scrolls the strip so `year` is in the band and shows it on the Year tab right away.
    private func move(to year: TheocraticYear, layout: TheocraticYearStripLayout) {
        yearInBand = year
        let animation: Animation? = reduceMotion || voiceOverEnabled ? nil : Motion.value
        withAnimation(animation) {
            position.scrollTo(x: layout.offset(for: year))
        }
        select(year)
    }

    private func select(_ year: TheocraticYear?) {
        guard let year, year != selection else { return }
        onSelect(year)
    }
}

/// Lets the strip glide with momentum, then settles where a whole theocratic
/// year sits in the band.
private nonisolated struct TheocraticYearStripSnapping: ScrollTargetBehavior {
    let layout: TheocraticYearStripLayout

    func updateTarget(_ target: inout ScrollTarget, context: TargetContext) {
        target.rect.origin.x = layout.snappedOffset(forProposedOffset: target.rect.origin.x)
    }
}

#Preview {
    TheocraticYearPicker(
        years: (2019...2026).map(TheocraticYear.init(startYear:)),
        selection: TheocraticYear(startYear: 2024),
        onSelect: { _ in }
    )
}
