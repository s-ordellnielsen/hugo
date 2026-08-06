//
//  CategorySettingsView.swift
//  Hugo
//
//  Created by Sebastian Nielsen on 06/08/2026.
//

import SwiftUI

struct CategorySettingsView: View {
    var body: some View {
		List {
			NavigationLink(destination: CategoryListView()) {
				Label("settings.screens.categories.items.list", systemImage: "list.bullet")
			}
		}
		.navigationTitle("settings.group.settings.category")
    }
}

#Preview {
    CategorySettingsView()
}
