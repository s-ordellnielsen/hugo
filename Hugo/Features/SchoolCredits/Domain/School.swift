import Foundation

/// A school whose attendance gives a fixed credit of hours toward the yearly
/// goal, such as Pioneer Service School. `SchoolCredit.schoolID` stores the
/// raw value. To add a school, add a case and fill in every switch.
nonisolated enum School: String, CaseIterable, Identifiable, Sendable {
    case pioneerServiceSchool = "pioneer-service-school"

    var id: String { rawValue }

    /// The most hours one school credit may hold.
    var creditHours: Int {
        switch self {
        case .pioneerServiceSchool: 30
        }
    }

    /// The hours one school credit may hold: at least 1, at most `creditHours`.
    var hoursRange: ClosedRange<Int> { 1...creditHours }

    /// `PublisherStatus.id`s that may add a credit for this school.
    var publisherStatusIDs: Set<String> {
        switch self {
        case .pioneerServiceSchool: ["regular-pioneer"]
        }
    }

    /// The school's name in `locale`'s language.
    func name(locale: Locale = .current) -> String {
        switch self {
        case .pioneerServiceSchool:
            String(
                localized: LocalizedStringResource(
                    "school.pioneerServiceSchool.name", defaultValue: "Pioneer Service School", locale: locale,
                    comment: "Name of the school for regular pioneers, shown on the Year page and in reports."
                ))
        }
    }

    /// The name for a stored school id, or a generic name when this build
    /// doesn't know the id (a school added by a newer build on another device).
    static func name(forID id: String, locale: Locale = .current) -> String {
        if let school = School(rawValue: id) {
            return school.name(locale: locale)
        }
        return String(
            localized: LocalizedStringResource(
                "school.unknown.name", defaultValue: "School credit", locale: locale,
                comment: "Label for a school credit whose school this version of the app doesn't know."))
    }

    /// The schools a user with publisher status `statusID` may add credit for.
    static func available(forStatusID statusID: String) -> [School] {
        allCases.filter { $0.publisherStatusIDs.contains(statusID) }
    }
}
