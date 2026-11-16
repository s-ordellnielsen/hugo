import SwiftUI

/// One line of a month's breakdown, such as a category, a school or Bible
/// studies, with its value on the trailing edge.
struct MonthBreakdownRow: View {
    let title: Text
    let systemImage: String
    let value: String

    var body: some View {
        HStack {
            Label {
                title
            } icon: {
                Image(systemName: systemImage)
            }

            Spacer()

            Text(value)
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    List {
        MonthBreakdownRow(title: Text(verbatim: "Field Service"), systemImage: "figure.walk", value: "12 h")
        MonthBreakdownRow(title: Text("report.bible-studies"), systemImage: "book", value: "3")
    }
}
