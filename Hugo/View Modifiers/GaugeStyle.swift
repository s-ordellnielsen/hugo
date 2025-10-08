//
//  SwiftUIView.swift
//  Hugo
//
//  Created by Sebastian Nielsen on 08/10/2025.
//

import SwiftUI

struct CircularLarge: GaugeStyle {
    func makeBody(configuration: Configuration) -> some View {
        ZStack {
            Circle()
                .stroke(.primary.opacity(0.1), lineWidth: 32)
            Circle()
                .trim(to: configuration.value)
                .stroke(.primary, style: .init(lineWidth: 32, lineCap: .round))
                .rotationEffect(.degrees(-90))
            configuration.currentValueLabel
        }
    }
}

extension GaugeStyle where Self == CircularLarge {
    static var circularLarge: CircularLarge { .init() }
}
