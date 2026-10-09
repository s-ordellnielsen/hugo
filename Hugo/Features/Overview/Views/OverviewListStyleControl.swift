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
        Picker("", selection: $selection) {
            Image(systemName: OverviewListStyle.byEntry.iconName)
                .tag(OverviewListStyle.byEntry)
            Image(systemName: OverviewListStyle.byDate.iconName)
                .tag(OverviewListStyle.byDate)
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
