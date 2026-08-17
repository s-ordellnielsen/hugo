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
        VStack(spacing: HugoLayout.Spacing.spacious) {
            Image(
                systemName: PublisherStatus.status(for: currentStatus) != nil
                    ? "person.crop.circle.badge.checkmark" : "person.crop.circle"
            )
            .font(.system(size: HugoLayout.Size.prominentSymbol))
            .contentTransition(.symbolEffect(.replace.magic(fallback: .downUp.byLayer)))
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(selectedStatus == nil ? Color.secondary : Color.hugoAccent)

            VStack(spacing: HugoLayout.Spacing.compact) {
                Text(selectedStatus?.nameKey ?? "publisher.status.empty")
                    .font(.system(.title, design: .serif, weight: .bold))
                    .contentTransition(.opacity)
                    .motion(Motion.presence, value: currentStatus)

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
