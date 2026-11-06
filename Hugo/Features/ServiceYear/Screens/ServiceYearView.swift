import SwiftData
import SwiftUI

struct ServiceYearView: View {
    @Query private var earliestEntry: [Entry]
    @Query private var latestEntry: [Entry]

    @State private var scrollPosition: TheocraticYear.ID?
    @State private var displayedYear: TheocraticYear?
    @State private var scrolledPages: [TheocraticYear.ID: Bool] = [:]
    @State private var isYearPickerPresented = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var resetToken: UUID

    init(resetToken: UUID = UUID()) {
        self.resetToken = resetToken
        var earliest = FetchDescriptor<Entry>(sortBy: [SortDescriptor(\.date, order: .forward)])
        earliest.fetchLimit = 1
        _earliestEntry = Query(earliest)
        var latest = FetchDescriptor<Entry>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        latest.fetchLimit = 1
        _latestEntry = Query(latest)
    }

    private var years: [TheocraticYear] {
        TheocraticYear.availableYears(
            entryDates: (earliestEntry + latestEntry).map(\.date),
            now: .now
        )
    }

    private var currentYear: TheocraticYear {
        Date().theocraticYear()
    }

    private var activeYear: TheocraticYear {
        displayedYear ?? currentYear
    }

    private var isScrolledFromTop: Bool {
        scrolledPages[activeYear.id] ?? false
    }

    private var yearTitle: some View {
        HStack(spacing: 0) {
            Text(String(activeYear.startYear))
                .contentTransition(.numericText(value: Double(activeYear.startYear)))
            Text(String("/"))
            Text(String(activeYear.startYear + 1))
                .contentTransition(.numericText(value: Double(activeYear.startYear + 1)))
                .animation(.snappy.delay(0.05), value: activeYear.startYear + 1)
        }
        .font(.system(.headline, design: .serif, weight: .bold))
        .lineLimit(1)
        .minimumScaleFactor(0.75)
        .monospacedDigit()
    }

    /// The chevron after the year title. A hidden copy before the title keeps
    /// the year text optically centered.
    private var yearTitleChevron: some View {
        Image(systemName: "chevron.down")
            .font(.caption.weight(.bold))
            .foregroundStyle(.secondary)
    }

    /// Slides the pager to `year`, or jumps there with Reduce Motion on. The
    /// existing `onChange(of: scrollPosition)` handler updates `displayedYear`
    /// and animates the title.
    private func jump(to year: TheocraticYear) {
        withAnimation(reduceMotion ? nil : Motion.presence) {
            scrollPosition = year.id
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView(.horizontal) {
                LazyHStack(spacing: 0) {
                    ForEach(years) { year in
                        ServiceYearPageView(
                            year: year,
                            onScrolledFromTopChange: { newValue in
                                scrolledPages[year.id] = newValue
                            }
                        )
                        .containerRelativeFrame(.horizontal)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.paging)
            .scrollPosition(id: $scrollPosition)
            .scrollIndicators(.hidden)
            .background(Color(.systemGroupedBackground))
            .navigationTitle(activeYear.displayName)
            .navigationSubtitle("year.subtitle")
            .navigationBarTitleDisplayMode(.inline)
            .scrollEdgeEffectHidden(!isScrolledFromTop, for: .top)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    if years.count > 1 {
                        Button {
                            isYearPickerPresented = true
                        } label: {
                            HStack(spacing: HugoLayout.Spacing.tight) {
                                yearTitleChevron
                                    .hidden()
                                yearTitle
                                yearTitleChevron
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("year.picker.a11y.label")
                        .accessibilityValue(activeYear.spokenName)
                        .accessibilityHint("year.picker.a11y.hint")
                        .popover(isPresented: $isYearPickerPresented) {
                            TheocraticYearPicker(years: years, selection: activeYear, onSelect: jump(to:))
                                .presentationCompactAdaptation(.popover)
                        }
                    } else {
                        yearTitle
                    }
                }
                ToolbarItem {
                    SettingsButton(sizeClass: .compact)
                }
            }
        }
        .onAppear {
            if scrollPosition == nil {
                scrollPosition = currentYear.id
                displayedYear = currentYear
            }
        }
        .onChange(
            of: scrollPosition,
            { _, newValue in
                guard let newValue, let year = years.first(where: { $0.id == newValue }) else { return }
                withAnimation(.snappy) {
                    displayedYear = year
                }
            }
        )
        .onChange(of: resetToken) {
            withAnimation {
                scrollPosition = currentYear.id
                displayedYear = currentYear
            }
        }
    }
}

#Preview {
    ServiceYearView()
        .modelContainer(.preview)
}
