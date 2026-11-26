import CoreTransferable
import Foundation
import UniformTypeIdentifiers

/// What dragging a Planner day carries: the ids of the day's plans and the day
/// they come from. Ids, not models, so the drop reads fresh rows.
nonisolated struct PlanMoveRequest: Codable, Equatable, Sendable, Transferable {
    let planIDs: [UUID]
    let sourceDay: CalendarDay

    /// The plans on `day`, or nil when it has none. Logged time (unplanned
    /// bars) never moves. Items whose id is not a plan's UUID are skipped.
    init?(day: PlannerDay) {
        let ids = day.bars
            .filter { $0.kind == .plan }
            .flatMap(\.items)
            .compactMap { UUID(uuidString: $0.id) }
        guard !ids.isEmpty else { return nil }
        self.init(planIDs: ids, sourceDay: day.id)
    }

    init(planIDs: [UUID], sourceDay: CalendarDay) {
        self.planIDs = planIDs
        self.sourceDay = sourceDay
    }

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .json)
            .visibility(.ownProcess)
    }
}
