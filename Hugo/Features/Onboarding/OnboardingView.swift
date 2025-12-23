//
//  OnboardingView.swift
//  Hugo
//
//  Created by Sebastian Nielsen on 17/11/2025.
//

import SwiftUI

struct OnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(UserDefaults.publisherStatusKey) var currentStatus: String = ""

    @State private var isLoading: Bool = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("splash.subtitle")
                    Text("splash.description.1")
                    Text("splash.description.2")
                    Text("splash.section.publisherStatus.title")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .fontDesign(.rounded)
                        .padding(.top, 32)
                    Text("splash.section.publisherStatus.description")

                    VStack(spacing: 8) {
                        ForEach(PublisherStatusConfig.defaults) { status in
                            Button {
                                currentStatus = status.id
                            } label: {
                                HStack(spacing: 16) {
                                    Image(
                                        systemName: currentStatus == status.id
                                            ? "checkmark.circle.fill" : "circle"
                                    )
                                    .font(.title2)
                                    .tint(.orange)
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text(status.nameKey)
                                            .fontWeight(.medium)
                                            .fontDesign(.rounded)
                                        VStack(alignment: .leading, spacing: 4)
                                        {
                                            Text(
                                                "publisher.status.goaltype.label.\(status.goalType.label)"
                                            )
                                            Text(
                                                "publisher.status.goal.label.\(status.goal)"
                                            )
                                        }
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .fontWeight(.regular)
                                    }
                                }
                                .padding(.horizontal, 24)
                                .padding(.vertical, 16)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(
                                    Color(.secondarySystemGroupedBackground)
                                )
                                .cornerRadius(32)
                                .tint(.primary)
                            }

                        }
                    }
                    .padding(.vertical, 8)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .navigationTitle("splash.title")
            .safeAreaInset(edge: .bottom) {
                Button {
                    Task {
                        await onDismiss()
                    }
                } label: {
                    HStack {
                        if isLoading {
                            ProgressView()
                                .tint(.white)
                                .transition(.blurReplace)
                        } else {
                            Label(
                                "splash.action.complete",
                                systemImage: "arrow.right"
                            )
                            .transition(.blurReplace)
                        }
                    }
                    .animation(.smooth, value: isLoading)
                    .fontWeight(.semibold)
                    .fontDesign(.rounded)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.orange)
                    .foregroundColor(.white)
                    .cornerRadius(24)
                }
                .disabled(currentStatus == "")
                .padding()
            }
        }
        .background(Color(.systemGroupedBackground))
        .interactiveDismissDisabled(true)
    }

    private func onDismiss() async {
        isLoading = true

        try? await Task.sleep(nanoseconds: 1_000_000_000)
        dismiss()
    }
}

#Preview {
    OnboardingView()
}
