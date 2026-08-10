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
            .foregroundStyle(selectedStatus == nil ? Color.secondary : Color.hugoAccent)

            VStack(spacing: 8) {
                Text(selectedStatus?.nameKey ?? "publisher.status.empty")
                    .font(.title)
                    .fontWeight(.bold)
                    .contentTransition(.opacity)
                    .animation(.easeInOut(duration: 0.2), value: currentStatus)

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
