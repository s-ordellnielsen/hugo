import SwiftUI

extension View {
    /// Lets a submitted month be dragged into another app, which receives the
    /// numbers that were sent (see `ReportComposer.reportedText`). Does nothing
    /// for a month that is not submitted. Put it on the card inside a
    /// `NavigationLink`'s label, never around the link, so a month becoming
    /// submitted does not change the link's identity.
    func monthReportDragSource(_ month: ServiceMonth) -> some View {
        modifier(MonthReportDragSource(month: month))
    }
}

private struct MonthReportDragSource: ViewModifier {
    let month: ServiceMonth

    private var text: String? {
        guard month.isSubmitted, let report = month.submittedReport else { return nil }
        return ReportComposer.reportedText(for: report, month: month.id)
    }

    func body(content: Content) -> some View {
        if let text {
            content.draggable(text) {
                Label(month.displayName, systemImage: "doc.text")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, HugoLayout.Spacing.regular)
                    .padding(.vertical, HugoLayout.Spacing.compact)
                    .background(.regularMaterial, in: .capsule)
            }
        } else {
            content
        }
    }
}
