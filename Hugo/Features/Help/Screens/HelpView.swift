//
//  HelpView.swift
//  Hugo
//
//  Created by Sebastian Nielsen on 07/08/2026.
//

import MarkdownUI
import OSLog
import SwiftUI

struct HelpView: View {
    private enum ContentState {
        case loading
        case loaded(content: String)
        case unavailable
    }

    @Environment(\.dismiss) private var dismiss

    private let resourceName: String
    private let bundle: Bundle

    @State private var state: ContentState = .loading
	
	private var loadID: String {
		"\(bundle.bundleURL.path)|\(resourceName)"
	}

    init(
        for resourceName: String,
        bundle: Bundle = .main
    ) {
        self.resourceName = resourceName
        self.bundle = bundle
    }

    var body: some View {
        NavigationStack {
            Group {
                switch state {
                case .loading:
                    ProgressView()

                case .loaded(let content):
                    ScrollView {
                        Markdown(content)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                    }

                case .unavailable:
                    ContentUnavailableView(
                        "help.unavailable.title",
                        systemImage: "questionmark.circle",
                        description: Text("help.unavailable.description")
                    )
                }
            }
            .background(Color(.systemGroupedBackground))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(role: .close) {
                        dismiss()
                    }
                }
            }
        }
		.task(id: loadID) {
			await loadContent()
		}
    }

    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "Hugo",
        category: "Help"
    )

    private func loadContent() async {
        state = .loading

        guard
            let url = bundle.url(
                forResource: resourceName,
                withExtension: "md"
            )
        else {
            Self.logger.error("Help resource not found: \(resourceName, privacy: .public)")
            state = .unavailable
            return
        }

        do {
            let content = try await Task.detached(priority: .utility) {
                try Task.checkCancellation()

                return try String(
                    contentsOf: url,
                    encoding: .utf8
                )
            }.value
			
			try Task.checkCancellation()
			state = .loaded(content: content)
        } catch is CancellationError {
			// The sheet was dismissed or its identity changed. Do nothing
        } catch {
            Self.logger.error(
                "Unable to parse help resource \(resourceName, privacy: .public): \(error.localizedDescription, privacy: .public)"
            )
            state = .unavailable
        }
    }
}

#Preview {
    HelpView(for: "RoundingRule")
}
