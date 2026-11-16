import Foundation
import SwiftData

/// What the school credit form produces.
nonisolated struct SchoolCreditDraft: Equatable, Sendable {
    let school: School
    let month: YearMonth
    let hours: Int
}

/// Creates, changes and deletes school credits. Every write is saved on its
/// own, so a failure never discards other edits.
@MainActor
struct SchoolCreditService {
    enum ValidationError: LocalizedError, Equatable {
        case hoursOutOfRange(ClosedRange<Int>)

        var errorDescription: String? {
            switch self {
            case .hoursOutOfRange(let range):
                String(
                    localized: "schoolCredit.error.hoursOutOfRange",
                    defaultValue: "Choose between \(range.lowerBound) and \(range.upperBound) hours.",
                    comment: "School credit hours out of range. Arguments: lowest and highest allowed."
                )
            }
        }
    }

    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    @discardableResult
    func add(_ draft: SchoolCreditDraft) throws -> SchoolCredit {
        try validate(draft)
        let credit = SchoolCredit(schoolID: draft.school.rawValue, month: draft.month, hours: draft.hours)
        try context.performIsolatedChange { context.insert(credit) }
        return credit
    }

    func update(_ credit: SchoolCredit, with draft: SchoolCreditDraft) throws {
        try validate(draft)
        try context.performIsolatedChange {
            credit.schoolID = draft.school.rawValue
            credit.year = draft.month.year
            credit.month = draft.month.month
            credit.hours = draft.hours
        }
    }

    func delete(_ credit: SchoolCredit) throws {
        try context.performIsolatedChange { context.delete(credit) }
    }

    private func validate(_ draft: SchoolCreditDraft) throws {
        guard draft.school.hoursRange.contains(draft.hours) else {
            throw ValidationError.hoursOutOfRange(draft.school.hoursRange)
        }
    }
}
