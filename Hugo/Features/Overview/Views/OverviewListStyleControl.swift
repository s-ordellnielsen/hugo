//
//  OverviewListStyleControl.swift
//  Hugo
//
//  Created by Sebastian Nielsen on 04/09/2026.
//

import SwiftUI

struct OverviewListStyleControl: View {
    @Binding var selection: OverviewListStyle
    @Environment(\.colorScheme) private var colorScheme

    @Namespace private var glassNamespace

    var body: some View {
        Picker("overview.list-style.label", selection: $selection) {
            ForEach([OverviewListStyle.byEntry, .byDate], id: \.self) { style in
                Image(systemName: style.iconName)
                    .accessibilityLabel(Text(style.accessibilityLabel))
                    .tag(style)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .fixedSize()
    }
}

#Preview {
    @Previewable @State var selection: OverviewListStyle = .byDate

    OverviewListStyleControl(selection: $selection)
}
