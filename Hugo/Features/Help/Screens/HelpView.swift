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

    /// How the page is shown. A sheet gets its own navigation bar with a
    /// close button. A pushed page uses the navigation stack it is pushed
    /// onto, so its back button closes it.
    enum Presentation {
        case sheet
        case pushed
    }

    @Environment(\.dismiss) private var dismiss

    private let resourceName: String
    private let bundle: Bundle
    private let presentation: Presentation

    @State private var state: ContentState = .loading

    private var loadID: String {
        "\(bundle.bundleURL.path)|\(resourceName)"
    }

    init(
        for resourceName: String,
        bundle: Bundle = .main,
        presentation: Presentation = .sheet
    ) {
        self.resourceName = resourceName
        self.bundle = bundle
        self.presentation = presentation
    }

    var body: some View {
        switch presentation {
        case .sheet:
            NavigationStack {
                page
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button(role: .close) {
                                dismiss()
                            }
                        }
                    }
            }

        case .pushed:
            page
                .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var page: some View {
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
