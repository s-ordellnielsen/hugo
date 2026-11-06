import SwiftUI

/// A normalized progress track with an optional faded extension and marker.
/// Callers must expose equivalent semantic information because this view hides
/// its drawing and marker label from VoiceOver.
struct MarkedProgressBar<MarkerLabel: View>: View {
    private let filled: Double
    private let extended: Double
    private let marker: Double?
    private let markerLabel: MarkerLabel

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.layoutDirection) private var layoutDirection

    init(
        filled: Double,
        extended: Double? = nil,
        marker: Double? = nil,
        @ViewBuilder markerLabel: () -> MarkerLabel
    ) {
        self.filled = Self.normalized(filled)
        self.extended = max(self.filled, Self.normalized(extended ?? filled))
        self.marker = marker.map(Self.normalized)
        self.markerLabel = markerLabel()
    }

    var body: some View {
        MarkedProgressBarLayout(
            marker: marker,
            markerPosition: marker ?? 0.5,
            isRightToLeft: layoutDirection == .rightToLeft,
            trackHeight: HugoLayout.Size.goalTrackHeight,
            markerHeight: markerHeight,
            labelGap: HugoLayout.Spacing.tight
        ) {
            ZStack(alignment: .leading) {
                ProgressTrack(filled: filled, extended: extended, layoutDirection: layoutDirection)
                    .frame(height: HugoLayout.Size.goalTrackHeight)
                if let marker {
                    ProgressMarker(
                        fraction: marker,
                        isRightToLeft: layoutDirection == .rightToLeft
                    )
                    .fill(.primary)
                    .frame(height: markerHeight)
                }
            }
            .accessibilityHidden(true)
            markerLabel
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityHidden(true)
        }
        .animation(
            Motion.progress,
            value: MarkedProgressBarValues(
                filled: filled,
                extended: extended,
                marker: marker
            )
        )
        .transaction { transaction in
            if reduceMotion {
                transaction.animation = nil
                transaction.disablesAnimations = true
            }
        }
        .accessibilityHidden(true)
    }

    private var markerHeight: CGFloat {
        HugoLayout.Size.goalTrackHeight + 2 * HugoLayout.Spacing.tight
    }

    private static func normalized(_ value: Double) -> Double {
        guard value.isFinite else { return value == .infinity ? 1 : 0 }
        return min(max(value, 0), 1)
    }
}

extension MarkedProgressBar where MarkerLabel == EmptyView {
    init(filled: Double, extended: Double? = nil, marker: Double? = nil) {
        self.init(filled: filled, extended: extended, marker: marker) {
            EmptyView()
        }
    }
}

private struct MarkedProgressBarValues: Equatable {
    let filled: Double
    let extended: Double
    let marker: Double?
}

private struct ProgressTrack: View {
    let filled: Double
    let extended: Double
    let layoutDirection: LayoutDirection

    var body: some View {
        GeometryReader { proxy in
            let geometry = MarkedProgressBarGeometry(
                width: proxy.size.width,
                trackHeight: HugoLayout.Size.goalTrackHeight,
                filled: filled,
                extended: extended,
                isRightToLeft: layoutDirection == .rightToLeft
            )
            ZStack(alignment: .leading) {
                Capsule().fill(.quaternary)
                FillCapsuleShape(
                    filled: geometry.filled,
                    extended: geometry.extended,
                    drawsExtended: true,
                    isRightToLeft: geometry.isRightToLeft
                )
                .fill(Color.hugoAccent.opacity(0.35))
                FillCapsuleShape(
                    filled: geometry.filled,
                    extended: geometry.extended,
                    drawsExtended: false,
                    isRightToLeft: geometry.isRightToLeft
                )
                .fill(Color.hugoAccent)
            }
            .frame(height: HugoLayout.Size.goalTrackHeight)
            .clipShape(Capsule())
            .accessibilityHidden(true)
        }
    }
}

private nonisolated struct FillCapsuleShape: Shape {
    var filled: Double
    var extended: Double
    let drawsExtended: Bool
    let isRightToLeft: Bool

    var animatableData: AnimatablePair<Double, Double> {
        get { AnimatablePair(filled, extended) }
        set {
            filled = newValue.first
            extended = newValue.second
        }
    }

    func path(in rect: CGRect) -> Path {
        let geometry = MarkedProgressBarGeometry(
            width: rect.width,
            trackHeight: rect.height,
            filled: filled,
            extended: extended,
            isRightToLeft: isRightToLeft
        )
        let fraction = drawsExtended ? geometry.extended : geometry.filled
        guard !geometry.fillCapsuleIsEmpty(for: fraction) else { return Path() }

        let capsule = CGRect(
            x: rect.minX + geometry.fillCapsuleOrigin(for: fraction),
            y: rect.minY,
            width: geometry.fillCapsuleLength(for: fraction),
            height: rect.height
        )
        var path = Path()
        path.addRoundedRect(
            in: capsule,
            cornerSize: CGSize(width: rect.height / 2, height: rect.height / 2)
        )
        return path
    }
}

private nonisolated struct ProgressMarker: Shape {
    var fraction: Double
    let isRightToLeft: Bool

    var animatableData: Double {
        get { fraction }
        set { fraction = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let geometry = MarkedProgressBarGeometry(
            width: rect.width,
            trackHeight: rect.height - 8,
            filled: 0,
            marker: fraction,
            isRightToLeft: isRightToLeft
        )
        guard let center = geometry.markerCenter else { return Path() }

        let marker = CGRect(
            x: rect.minX + center - 1,
            y: rect.minY,
            width: 2,
            height: rect.height
        )
        var path = Path()
        path.addRoundedRect(
            in: marker,
            cornerSize: CGSize(width: 1, height: 1)
        )
        return path
    }
}

private nonisolated struct MarkedProgressBarLayout: Layout {
    let marker: Double?
    var markerPosition: Double
    let isRightToLeft: Bool
    let trackHeight: CGFloat
    let markerHeight: CGFloat
    let labelGap: CGFloat

    var animatableData: Double {
        get { markerPosition }
        set { markerPosition = newValue }
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = max(0, proposal.width ?? 0)
        guard marker != nil else { return CGSize(width: width, height: markerHeight) }

        let labelSize = subviews[1].sizeThatFits(ProposedViewSize(width: width, height: nil))
        let labelGap = labelSize.height > 0 ? self.labelGap : 0
        return CGSize(width: width, height: labelSize.height + labelGap + markerHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let width = max(0, bounds.width)

        guard marker != nil else {
            subviews[0].place(
                at: CGPoint(x: bounds.minX, y: bounds.minY + markerHeight / 2),
                anchor: .leading,
                proposal: ProposedViewSize(width: width, height: markerHeight)
            )
            return
        }

        let labelSize = subviews[1].sizeThatFits(ProposedViewSize(width: width, height: nil))
        let labelGap = labelSize.height > 0 ? self.labelGap : 0
        let markerCenter = physicalPosition(for: markerPosition, width: width)
        let labelCenter = min(max(markerCenter, labelSize.width / 2), width - labelSize.width / 2)

        subviews[1].place(
            at: CGPoint(x: bounds.minX + labelCenter, y: bounds.minY + labelSize.height / 2),
            anchor: .center,
            proposal: ProposedViewSize(width: width, height: labelSize.height)
        )
        subviews[0].place(
            at: CGPoint(
                x: bounds.minX,
                y: bounds.minY + labelSize.height + labelGap + markerHeight / 2
            ),
            anchor: .leading,
            proposal: ProposedViewSize(width: width, height: markerHeight)
        )
    }

    private func physicalPosition(for fraction: Double, width: CGFloat) -> CGFloat {
        let geometry = MarkedProgressBarGeometry(
            width: width,
            trackHeight: trackHeight,
            filled: 0,
            marker: fraction,
            isRightToLeft: isRightToLeft
        )
        return geometry.markerCenter ?? width / 2
    }
}

#Preview("Fill and marker cases") {
    VStack(alignment: .leading, spacing: HugoLayout.Spacing.roomy) {
        MarkedProgressBar(filled: 0)
        MarkedProgressBar(filled: 0.001)
        MarkedProgressBar(filled: 0, extended: 0.55)
        MarkedProgressBar(filled: 0.42)
        MarkedProgressBar(filled: 0.01, extended: 0.18, marker: 0) {
            Text("A long goal label that wraps at narrow widths")
        }
        MarkedProgressBar(filled: 0.42, extended: 0.72, marker: 0.5) {
            Text("50 hours")
        }
        MarkedProgressBar(filled: 1, marker: 1) {
            Text("A goal label near the trailing edge")
        }
    }
    .padding()
    .frame(width: 240)
}

#Preview("Rapid changes") {
    ChangingBarPreview()
}

private struct ChangingBarPreview: View {
    @State private var step = 0
    private let values: [(Double, Double, Double)] = [
        (0.001, 0.2, 0), (0.45, 0.7, 0.55), (0.85, 1, 1), (0.1, 0.35, 0.2),
        (0.25, 0.2, 0.5),
    ]

    var body: some View {
        VStack(spacing: HugoLayout.Spacing.regular) {
            let value = values[step % values.count]
            MarkedProgressBar(filled: value.0, extended: value.1, marker: value.2) {
                Text("A longer goal label")
            }
            Button("Change values") { step += 1 }
        }
        .padding()
    }
}

#Preview("Dark mode") {
    VStack(spacing: HugoLayout.Spacing.regular) {
        MarkedProgressBar(filled: 0.35, extended: 0.7, marker: 0.55) {
            Text("Monthly goal: 50 hours")
        }
        MarkedProgressBar(filled: 0.2, extended: 0.45, marker: 0.65) {
            Text("Change the values to see the instant update")
        }
    }
    .padding()
    .preferredColorScheme(.dark)
}

#Preview("Large text and long Danish label") {
    MarkedProgressBar(filled: 0.3, extended: 0.65, marker: 0.5) {
        Text("Månedligt mål: 50 timer inklusive ekstra buffer")
    }
    .padding()
    .frame(width: 220)
    .dynamicTypeSize(.accessibility5)
}

#Preview("Right-to-left") {
    MarkedProgressBar(filled: 0.3, extended: 0.65, marker: 0.5) {
        Text("Goal: 50 hours")
    }
    .padding()
    .environment(\.layoutDirection, .rightToLeft)
}
