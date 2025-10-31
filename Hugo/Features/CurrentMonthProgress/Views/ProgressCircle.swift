//
//  SwiftUIView.swift
//  Hugo
//
//  Created by Sebastian Nielsen on 31/10/2025.
//

import SwiftUI

extension CurrentMonthProgress {
    struct ProgressCircle: View {
        @Environment(\.colorScheme) var colorScheme

        var progress: Double
        var maxValue: Double
        
        var normalizedProgress: Double {
            guard maxValue > 0 else { return 0 }
            return min(max(progress / maxValue, 0), 1)
        }
        
        var progressHeight: CGFloat {
            let raw = normalizedProgress * Double(size)
            let extra: Double = normalizedProgress >= 1 ? 1.0 : 0.0
            return CGFloat(ceil(raw + extra))
        }

        private let size = CGFloat(360)

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
            }
            .frame(width: size, height: size)
            .clipShape(Circle())
        }
    }
}

#Preview {
    CurrentMonthProgress.ProgressCircle(progress: 24, maxValue: 50)
}
