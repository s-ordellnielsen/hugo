//
//  PublisherStatusOptionRow.swift
//  Hugo
//
//  Created by Sebastian Nielsen on 07/08/2026.
//

import SwiftUI

struct PublisherStatusOptionRow: View {
    enum Style {
        case list
        case card
    }

    let status: PublisherStatus
    let isSelected: Bool
    let style: Style
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            switch style {
            case .list:
                rowContent
                    .frame(maxWidth: .infinity, alignment: .leading)

            case .card:
                rowContent
                    .padding(.horizontal, HugoLayout.Spacing.card)
                    .padding(.vertical, HugoLayout.Spacing.spacious)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(.rect(cornerRadius: HugoLayout.CornerRadius.card))
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var rowContent: some View {
        HStack(alignment: .center, spacing: HugoLayout.Spacing.regular) {
            VStack(alignment: .leading, spacing: HugoLayout.Spacing.tight) {
                Text(status.nameKey)

                Text(status.goalDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: HugoLayout.Spacing.regular)

            Checkmark(checked: isSelected)
        }
        .contentShape(Rectangle())
    }
}
