//
//  PublisherStatusOptionRow.swift
//  Hugo
//
//  Created by Sebastian Nielsen on 07/08/2026.
//

import SwiftUI

struct PublisherStatusOptionRow: View {
	enum Style {
		case list
		case card
	}
	
	let status: PublisherStatus
	let isSelected: Bool
	let style: Style
	let action: () -> Void
	
	var body: some View {
		Button(action: action) {
			switch style {
				case .list:
					rowContent
						.frame(maxWidth: .infinity, alignment: .leading)
					
				case .card:
					rowContent
						.padding(.horizontal, 24)
						.padding(.vertical, 16)
						.frame(maxWidth: .infinity, alignment: .leading)
						.background(Color(.secondarySystemGroupedBackground))
						.clipShape(.rect(cornerRadius: 32))
			}
		}
		.buttonStyle(.plain)
		.accessibilityAddTraits(isSelected ? .isSelected : [])
	}
	
	private var rowContent: some View {
		HStack(alignment: .center, spacing: 12) {
			VStack(alignment: .leading, spacing: 4) {
				Text(status.nameKey)
				
				Text(status.goalDescription)
					.font(.caption)
					.foregroundStyle(.secondary)
			}
			
			Spacer(minLength: 12)
			
			Checkmark(checked: isSelected)
		}
		.contentShape(Rectangle())
	}
}
