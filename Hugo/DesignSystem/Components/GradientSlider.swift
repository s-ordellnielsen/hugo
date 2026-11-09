import SwiftUI

/// A horizontal slider whose track is any style, such as a gradient. Drag or
/// tap anywhere on the track. VoiceOver adjusts it by `step`.
struct GradientSlider<Track: ShapeStyle, Thumb: ShapeStyle>: View {
    @Binding var value: Double
    let track: Track
    let thumb: Thumb
    let label: Text
    let valueText: Text
    var step: Double = 0.05
    var wraps = false
    /// True when a drag starts, false when it ends. Not called for VoiceOver
    /// adjustments, which change `value` directly.
    var onEditingChanged: (Bool) -> Void = { _ in }

    @ScaledMetric(relativeTo: .body) private var height = HugoLayout.Size.gradientSliderHeight
    @State private var isDragging = false

    private var ring: CGFloat { HugoLayout.Size.gradientSliderThumbRing }

    var body: some View {
        GeometryReader { geometry in
            let slider = GradientSliderGeometry(trackWidth: geometry.size.width, thumbDiameter: height)
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(track)
                    .overlay { Capsule().strokeBorder(.separator, lineWidth: 1) }

                Circle()
                    .fill(thumb)
                    .frame(width: height - 2 * ring, height: height - 2 * ring)
                    .padding(ring)
                    .background { Circle().fill(.white) }
                    .shadow(radius: 2)
                    .position(x: slider.thumbCenterX(for: value), y: height / 2)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { drag in
                        if !isDragging {
                            isDragging = true
                            onEditingChanged(true)
                        }
                        value = slider.value(forX: drag.location.x)
                    }
                    .onEnded { _ in
                        onEditingChanged(false)
                        isDragging = false
                    })
        }
        .frame(height: height)
        .frame(minHeight: HugoLayout.Size.minimumHitTarget)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue(valueText)
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment:
                value = GradientSliderGeometry.stepped(value, by: step, wraps: wraps)
            case .decrement:
                value = GradientSliderGeometry.stepped(value, by: -step, wraps: wraps)
            @unknown default:
                break
            }
        }
    }
}

#Preview {
    @Previewable @State var value = 0.5

    GradientSlider(
        value: $value,
        track: LinearGradient(colors: [.red, .blue], startPoint: .leading, endPoint: .trailing),
        thumb: Color.blue,
        label: Text("Preview"),
        valueText: Text(value, format: .percent.precision(.fractionLength(0))),
        step: 0.1
    )
    .padding()
}
