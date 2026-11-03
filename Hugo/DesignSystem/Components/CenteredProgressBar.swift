import SwiftUI

/// A bar whose center means "exactly on target". The knob moves left or right of the
/// center and a trail runs from the center point to the knob.
struct CenteredProgressBar: View {
    /// -1 (left end) ... 0 (center) ... 1 (right end).
    let fraction: Double
    let accessibilityLabel: LocalizedStringKey
    let accessibilityValue: String

    private var clampedFraction: Double {
        min(1, max(-1, fraction))
    }

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let centerX = width / 2
            let knobX = centerX + clampedFraction * (centerX - HugoLayout.Size.goalKnobDiameter / 2)
            let trackHeight = HugoLayout.Size.goalTrackHeight
            let trailWidth = abs(knobX - centerX) + trackHeight / 2
            let trailStart = knobX >= centerX ? centerX - trackHeight / 2 : knobX

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color(.tertiarySystemFill))
                    .frame(height: HugoLayout.Size.goalTrackHeight)

                if clampedFraction != 0 {
                    Capsule()
                        .fill(.hugoAccent)
                        .frame(width: trailWidth, height: trackHeight)
                        .offset(x: trailStart)
                }

                Circle()
                    .fill(Color(.systemBackground))
                    .overlay(Circle().stroke(.hugoAccent, lineWidth: 4))
                    .frame(width: HugoLayout.Size.goalKnobDiameter, height: HugoLayout.Size.goalKnobDiameter)
                    .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
                    .offset(x: knobX - HugoLayout.Size.goalKnobDiameter / 2)
            }
            .frame(maxHeight: .infinity)
            .motion(Motion.progress, value: clampedFraction)
        }
        .frame(height: HugoLayout.Size.goalKnobDiameter)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(accessibilityValue)
    }
}

#Preview {
    VStack(spacing: HugoLayout.Spacing.card) {
        ForEach([-1, -0.3, 0, 0.6, 1], id: \.self) { fraction in
            CenteredProgressBar(
                fraction: fraction,
                accessibilityLabel: "Progress",
                accessibilityValue: "\(Int(fraction * 100)) percent")
        }
    }
    .padding()
}
