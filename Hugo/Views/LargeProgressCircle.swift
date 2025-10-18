//
//  LargeProgressCircle.swift
//  Hugo
//
//  Created by Sebastian Nielsen on 08/10/2025.
//

import SwiftUI

struct LargeProgressCircle: View {
    @Environment(\.colorScheme) var colorScheme

    var progress: Double
    var max: Double

    private let size = CGFloat(360)

    @State private var progressHeight: CGFloat = 0.0

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    colorScheme == .dark
                        ? Color(.secondarySystemBackground)
                        : Color(.systemBackground)
                )
                .frame(width: size, height: size)

            VStack {
                Spacer()
                Rectangle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                .accent, .accent.opacity(0.5),
                            ]),
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .frame(width: size, height: progressHeight)
            }
            .mask {
                Circle()
                    .frame(width: size, height: size)
            }
        }
        .onAppear {
            DispatchQueue.main.async {
                withAnimation(.bouncy(duration: 1.5).delay(0.5)) {
                    progressHeight = min(CGFloat(size / max * CGFloat(progress)), size)
                }
            }
        }
        .onChange(of: progress) { oldValue, newValue in
            withAnimation {
                progressHeight = min(CGFloat(size / max * CGFloat(newValue)), size)
            }
        }
    }
}

#Preview {
    LargeProgressCircle(progress: 32, max: 50)
}
