//
//  PublisherStatusOptionsView.swift
//  Hugo
//
//  Created by Sebastian Nielsen on 07/08/2026.
//

import SwiftUI

struct PublisherStatusOptionsView: View {
	@Binding var selection: String
	let rowStyle: PublisherStatusOptionRow.Style
	
	var body: some View {
		ForEach(PublisherStatus.all) { status in
			PublisherStatusOptionRow(
				status: status,
				isSelected: selection == status.id,
				style: rowStyle
			) {
				selection = status.id
			}
		}
	}
}
