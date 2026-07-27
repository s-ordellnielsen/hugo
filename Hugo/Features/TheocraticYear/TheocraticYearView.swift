//
//  TheocraticYearView.swift
//  Hugo
//
//  Created by Sebastian Nielsen on 27/07/2026.
//

import SwiftUI

struct TheocraticYearView: View {
    var body: some View {
        TabView {
			NavigationStack {
				List {
					Text("1")
				}
				.navigationTitle("2025/2026")
				.navigationSubtitle("Theocratic Year")
				.navigationBarTitleDisplayMode(.inline)
			}
			NavigationStack {
				List {
					Text("2")
				}
				.navigationTitle("2026/2027")
				.navigationSubtitle("Theocratic Year")
				.navigationBarTitleDisplayMode(.inline)
			}
			NavigationStack {
				List {
					Text("3")
				}
				.navigationTitle("2027/2028")
				.navigationSubtitle("Theocratic Year")
				.navigationBarTitleDisplayMode(.inline)
			}
        }
		.tabViewStyle(.page(indexDisplayMode: .never))
		.ignoresSafeArea(edges: .vertical)
		.background(Color(.secondarySystemBackground))
    }
}

#Preview {
    TheocraticYearView()
}
