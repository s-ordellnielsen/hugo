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
			.foregroundStyle(.tint)
			.fontWeight(.semibold)
			.frame(width: 20, height: 20)
			.opacity(checked ? 1 : 0)
			.blur(radius: checked ? 0 : 4)
			.scaleEffect(checked ? 1 : 0.8)
			.accessibilityHidden(!checked)
			.animation(.easeOut(duration: 0.2), value: checked)
    }
}

#Preview {
    Checkmark(checked: true)
}
