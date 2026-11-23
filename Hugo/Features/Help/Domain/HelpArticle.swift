import Foundation

/// A help page that `HelpView` shows. The raw value is the Markdown file's
/// name without `.md`; each file ships in
/// `Hugo/Resources/Markdown/Help/Base.lproj` and `da.lproj`.
nonisolated enum HelpArticle: String, CaseIterable, Identifiable, Sendable {
    case targetThisMonth = "TargetThisMonth"
    case fieldServiceAndCredit = "FieldServiceAndCredit"
    case roundingRules = "RoundingRule"

    var id: String { rawValue }

    var resourceName: String { rawValue }

    var title: LocalizedStringResource {
        switch self {
        case .targetThisMonth:
            LocalizedStringResource(
                "help.article.targetThisMonth", defaultValue: "Your target this month",
                comment: "Help menu item and article title: how the time expected by today is worked out.")
        case .fieldServiceAndCredit:
            LocalizedStringResource(
                "help.article.fieldServiceAndCredit", defaultValue: "Field Service and Credit",
                comment: "Help menu item and article title: the two category types.")
        case .roundingRules:
            LocalizedStringResource(
                "help.article.roundingRules", defaultValue: "Rounding rules",
                comment: "Help menu item: the article about rounding a report line's minutes.")
        }
    }

    var systemImage: String {
        switch self {
        case .targetThisMonth: "target"
        case .fieldServiceAndCredit: "tag"
        case .roundingRules: "plusminus"
        }
    }

    // MARK: Articles per screen

    /// The Service Year tab and the year details screen.
    static let year: [HelpArticle] = [.targetThisMonth, .fieldServiceAndCredit]

    /// The Submit Report sheet: rounding first, because a line can't be sent
    /// without a rule; the types explain the report's lines.
    static let submitReport: [HelpArticle] = [.roundingRules, .fieldServiceAndCredit]

    /// Settings > Report.
    static let reportSettings: [HelpArticle] = [.roundingRules]

    /// Settings > Categories and the Add Category sheet.
    static let categories: [HelpArticle] = [.fieldServiceAndCredit]
}
