import Foundation

/// What a category kind means, in plain sentences for the kind picker: where
/// the time goes on the report, how it counts toward the yearly goal, and
/// whether its entries can have Bible studies. `TrackerType.main` is a Field
/// Service category and `.separate` a Credit category (see CONTEXT.md).
nonisolated struct CategoryKindFact: Identifiable, Equatable, Sendable {
    enum Topic: Sendable {
        case report
        case goal
        case bibleStudies
    }

    let topic: Topic
    let text: String

    var id: Topic { topic }

    var systemImage: String {
        switch topic {
        case .report: "doc.text"
        case .goal: "target"
        case .bibleStudies: "book"
        }
    }

    /// The facts for `kind` in this order: report, goal, Bible studies. The
    /// goal fact is left out when `status` is nil or has no yearly goal.
    static func facts(
        for kind: TrackerType, status: PublisherStatus?, locale: Locale = .current
    ) -> [CategoryKindFact] {
        var facts = [CategoryKindFact(topic: .report, text: reportText(for: kind, locale: locale))]
        if let rule = status?.yearlyGoalRule {
            facts.append(CategoryKindFact(topic: .goal, text: goalText(for: kind, rule: rule, locale: locale)))
        }
        facts.append(CategoryKindFact(topic: .bibleStudies, text: studiesText(for: kind, locale: locale)))
        return facts
    }

    /// The symbol on the kind's card.
    static func systemImage(for kind: TrackerType) -> String {
        switch kind {
        case .main: "figure.walk"
        case .separate: "hammer"
        }
    }

    /// The example line on the kind's card.
    static func example(for kind: TrackerType, locale: Locale = .current) -> String {
        switch kind {
        case .main:
            String(
                localized: LocalizedStringResource(
                    "category.kind.main.example",
                    defaultValue: "For example house to house, return visits and public witnessing.",
                    locale: locale,
                    comment: "Example line on the Field Service card in the category type picker."))
        case .separate:
            String(
                localized: LocalizedStringResource(
                    "category.kind.separate.example",
                    defaultValue: "For example LDC or Bethel.",
                    locale: locale,
                    comment: "Example line on the Credit card in the category type picker."))
        }
    }

    private static func reportText(for kind: TrackerType, locale: Locale) -> String {
        switch kind {
        case .main:
            String(
                localized: LocalizedStringResource(
                    "category.kind.fact.main.report",
                    defaultValue: "Added together and sent as one line on your report.",
                    locale: locale,
                    comment: "Category type picker, Field Service: where the time goes on the report."))
        case .separate:
            String(
                localized: LocalizedStringResource(
                    "category.kind.fact.separate.report",
                    defaultValue: "Sent on its own line on your report, with the category's name.",
                    locale: locale,
                    comment: "Category type picker, Credit: where the time goes on the report."))
        }
    }

    private static func goalText(for kind: TrackerType, rule: YearlyGoalRule, locale: Locale) -> String {
        switch kind {
        case .main:
            return String(
                localized: LocalizedStringResource(
                    "category.kind.fact.main.goal",
                    defaultValue: "Counts in full toward your yearly goal.",
                    locale: locale,
                    comment: "Category type picker, Field Service: how the time counts toward the yearly goal."))
        case .separate:
            let limit = ServiceDurationFormatter.hoursString(
                from: rule.monthlyGoalSeconds + rule.separateAllowanceSeconds, locale: locale)
            let allowance = ServiceDurationFormatter.hoursString(from: rule.separateAllowanceSeconds, locale: locale)
            return String(
                localized: LocalizedStringResource(
                    "category.kind.fact.separate.goal",
                    defaultValue:
                        "Counts toward your yearly goal until the month reaches \(limit): your monthly goal plus \(allowance).",
                    locale: locale,
                    comment:
                        "Category type picker, Credit: how the time counts toward the yearly goal. The first argument is the monthly goal plus the credit allowance, such as 55 hours; the second is the allowance, such as 5 hours."
                ))
        }
    }

    private static func studiesText(for kind: TrackerType, locale: Locale) -> String {
        switch kind {
        case .main:
            String(
                localized: LocalizedStringResource(
                    "category.kind.fact.main.studies",
                    defaultValue: "You can add Bible studies to entries in this category.",
                    locale: locale,
                    comment: "Category type picker, Field Service: Bible studies are allowed."))
        case .separate:
            String(
                localized: LocalizedStringResource(
                    "category.kind.fact.separate.studies",
                    defaultValue: "You can't add Bible studies to entries in this category.",
                    locale: locale,
                    comment: "Category type picker, Credit: Bible studies are not allowed."))
        }
    }
}
