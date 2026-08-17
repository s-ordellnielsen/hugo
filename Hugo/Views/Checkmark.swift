//
//  Checkmark.swift
//  Hugo
//
//  Created by Sebastian Nielsen on 07/08/2026.
//

import SwiftUI

struct Checkmark: View {
    let checked: Bool

    var body: some View {
        Image(systemName: "checkmark")
            .imageScale(.medium)
            .foregroundStyle(checked ? .hugoAccent : .clear)
            .fontWeight(.semibold)
            .opacity(checked ? 1 : 0)
            .blur(radius: checked ? 0 : 4)
            .scaleEffect(checked ? 1 : 0.8)
            .accessibilityHidden(!checked)
            .motion(Motion.feedback, value: checked)
    }
}

#Preview {
    Checkmark(checked: true)
}
