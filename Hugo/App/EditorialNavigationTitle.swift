import SwiftUI

struct EditorialNavigationTitle: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.system(.headline, design: .serif, weight: .bold))
            .lineLimit(1)
            .minimumScaleFactor(0.75)
    }
}
