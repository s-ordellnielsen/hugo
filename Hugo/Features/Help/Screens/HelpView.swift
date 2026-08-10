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
    @Environment(\.dismiss) private var dismiss

    private let content: String?

    init(
        for resourceName: String,
        bundle: Bundle = .main
    ) {
        guard
            let url = bundle.url(
                forResource: resourceName, withExtension: "md"
            )
        else {
            Self.logger.error("Help resource not found: \(resourceName, privacy: .public)")
            self.content = nil
            return
        }

        do {
            self.content = try String(
                contentsOf: url,
                encoding: .utf8
            )
        } catch {
            Self.logger.error(
                "Unable to parse help resource \(resourceName, privacy: .public): \(error.localizedDescription, privacy: .public)"
            )
            self.content = nil
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if let content {
                    ScrollView {
                        Markdown(content)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                    }
                } else {
                    ContentUnavailableView(
                        "help.unavailable.title", systemImage: "questionmark.circle",
                        description: Text("help.unavailable.description"))
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
        .presentationDragIndicator(.visible)
    }

    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "Hugo",
        category: "Help"
    )
}

#Preview {
    HelpView(for: "RoundingRule")
}
