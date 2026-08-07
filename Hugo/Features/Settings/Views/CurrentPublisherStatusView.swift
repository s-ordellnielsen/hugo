//
//  CurrentPublisherStatusView.swift
//  Hugo
//
//  Created by Sebastian Nielsen on 07/08/2026.
//

import SwiftUI

struct CurrentPublisherStatusView: View {
    var currentStatus: String

    private var selectedStatus: PublisherStatus? {
        PublisherStatus.status(for: currentStatus)
    }

    var body: some View {
        VStack(spacing: 16) {
            Image(
                systemName: PublisherStatus.status(for: currentStatus) != nil
                    ? "person.crop.circle.badge.checkmark" : "person.crop.circle"
            )
            .font(.system(size: 64))
            .contentTransition(.symbolEffect(.replace.magic(fallback: .downUp.byLayer)))
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(.tint)

            VStack(spacing: 8) {
                ZStack {
                    if let status = selectedStatus {
                        Text(status.nameKey)
                            .id(status.id)
                            .transition(
                                .asymmetric(
                                    insertion:
                                        .opacity
                                        .combined(with: .push(from: .bottom))
                                        .combined(with: .scale(scale: 0.9)),
                                    removal:
                                        .opacity
                                        .combined(with: .push(from: .bottom))
                                        .combined(with: .scale(scale: 0.9))
                                ))
                    } else {
                        Text("publisher.status.empty")
                            .transition(
                                .asymmetric(
                                    insertion:
                                        .opacity
                                        .combined(with: .push(from: .bottom))
                                        .combined(with: .scale(scale: 0.9)),
                                    removal:
                                        .opacity
                                        .combined(with: .push(from: .bottom))
                                        .combined(with: .scale(scale: 0.9))
                                ))
                    }
                }
                .frame(maxWidth: .infinity)
                .font(.title)
                .fontDesign(.rounded)
				.fontWeight(.bold)
                .animation(.bouncy(duration: 0.4), value: currentStatus)

                Text("account.page.publisherselect.current")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .fontWeight(.semibold)
        .listRowBackground(Color(.clear))
    }
}

#Preview {
    PublisherStatusSelectionView()
}
