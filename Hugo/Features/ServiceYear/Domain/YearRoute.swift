import SwiftData

/// The screens the Service Year tab pushes. Each route carries an identifier
/// only; the page is rebuilt from the database when it is pushed.
nonisolated enum YearRoute: Hashable {
    /// The year's totals page, by its start year (`TheocraticYear.ID`).
    case yearDetail(TheocraticYear.ID)
    case month(YearMonth)
    case entry(PersistentIdentifier)
}
