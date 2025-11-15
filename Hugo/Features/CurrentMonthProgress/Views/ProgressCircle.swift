//
//  SwiftUIView.swift
//  Hugo
//
//  Created by Sebastian Nielsen on 31/10/2025.
//

import SwiftUI

extension CurrentMonthProgressView {
    struct ProgressCircle: View {
        @Environment(\.colorScheme) var colorScheme

        var progress: Double
        var maxValue: Double
        var marker: Double?
        
        var normalizedProgress: Double {
            guard maxValue > 0 else { return 0 }
            return min(max(progress / maxValue, 0), 1)
        }
        
        var normalizedMarker: Double {
            guard let marker, maxValue > 0 else { return 0 }
            return min(max(marker / maxValue, 0), 1)
        }
        
        var progressHeight: CGFloat {
            let raw = normalizedProgress * Double(size)
            let extra: Double = normalizedProgress >= 1 ? 1.0 : 0.0
            return CGFloat(ceil(raw + extra))
        }
        
        var markerHeight: CGFloat {
            CGFloat(normalizedMarker * Double(size))
        }
        
        var markerLineWidth: CGFloat {
            let radius = size / 2
            let centerY = radius
            let distanceFromCenter = abs(markerHeight - centerY)
            
            guard distanceFromCenter <= radius else { return 0 }
            
            let widthHalf = sqrt(pow(radius, 2) - pow(distanceFromCenter, 2))
            return max(CGFloat(2 * widthHalf - lineOffset), 0)
        }

        private let size = CGFloat(360)
        private let lineOffset = Double(8)

        var body: some View {
            ZStack(alignment: .bottom) {
                Circle()
                    .fill(
                        colorScheme == .dark
                            ? Color(.secondarySystemBackground)
                            : Color(.systemBackground)
                    )
                    .frame(width: size, height: size)
                
                Rectangle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                .orange, .yellow,
                            ]),
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .frame(width: size, height: progressHeight)
                    .animation(.spring(response: 0.6, dampingFraction: 0.9, blendDuration: 0).delay(0.2), value: progressHeight)
                
                if let _ = marker {
                    VStack(spacing: 0) {
                        Spacer()
                        Rectangle()
                            .fill(.black.opacity(0.25))
                            .frame(width: markerLineWidth, height: 4)
                            .cornerRadius(2)
                        Spacer()
                            .frame(height: markerHeight)
                    }
                    .frame(height: size)
                }
            }
            .frame(width: size, height: size)
            .clipShape(Circle())
        }
    }
}

#Preview {
    CurrentMonthProgressView<EmptyView>.ProgressCircle(progress: 34, maxValue: 50, marker: 12)
}
