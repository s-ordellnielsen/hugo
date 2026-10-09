import Foundation

nonisolated enum ReportingLineCalculator {
    static func lines(from entries: [Entry], calendar: Calendar = .current) -> [ReportingLine] {
        let orderedEntries = entries.enumerated().sorted { lhs, rhs in
            if lhs.element.date == rhs.element.date {
                return lhs.offset < rhs.offset
            }
            return lhs.element.date < rhs.element.date
        }

        var mainSeconds: TimeInterval = 0
        var mainCarriedInSeconds: TimeInterval = 0
        var mainCarriedInFrom: Set<YearMonth> = []
        var separateLines: [String: SeparateLine] = [:]

        for (_, entry) in orderedEntries {
            let category: Category
            if let tracker = entry.tracker {
                category = Category(name: tracker.name, iconName: tracker.iconName, type: tracker.type)
            } else if let storedTracker = entry.storedTracker {
                category = Category(name: storedTracker.name, iconName: storedTracker.icon, type: storedTracker.type)
            } else {
                category = Category(name: "", iconName: "figure.walk", type: .main)
            }

            let sourceMonth: YearMonth?
            if let year = entry.sourceReportYear, let month = entry.sourceReportMonth {
                sourceMonth = YearMonth(year: year, month: month)
            } else {
                sourceMonth = nil
            }

            switch category.type {
            case .main:
                mainSeconds += entry.duration
                if let sourceMonth {
                    mainCarriedInSeconds += entry.duration
                    mainCarriedInFrom.insert(sourceMonth)
                }
            case .separate:
                var line = separateLines[category.name] ?? SeparateLine(iconName: category.iconName)
                line.actualSeconds += entry.duration
                if let sourceMonth {
                    line.carriedInSeconds += entry.duration
                    line.carriedInFrom.insert(sourceMonth)
                }
                separateLines[category.name] = line
            }
        }

        let mainLine = ReportingLine(
            id: "",
            type: .main,
            name: "",
            iconName: "figure.walk",
            actualSeconds: mainSeconds,
            carriedInSeconds: mainCarriedInSeconds,
            carriedInFrom: mainCarriedInFrom.sorted()
        )

        let sortedSeparateLines = separateLines.map { name, values in
            ReportingLine(
                id: name,
                type: .separate,
                name: name,
                iconName: values.iconName,
                actualSeconds: values.actualSeconds,
                carriedInSeconds: values.carriedInSeconds,
                carriedInFrom: values.carriedInFrom.sorted()
            )
        }.sorted {
            $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }

        return [mainLine] + sortedSeparateLines
    }

    static func compute(_ line: ReportingLine, rule: RoundingRule?) -> ReportingLineResult {
        let wholeHours = Int(line.actualSeconds / 3_600)
        let remainder = line.remainderSeconds

        guard remainder > 0 else {
            return ReportingLineResult(line: line, rule: nil, submittedHours: wholeHours, disposition: .none)
        }

        guard let rule else {
            return ReportingLineResult(
                line: line,
                rule: nil,
                submittedHours: wholeHours,
                disposition: .undecided(seconds: remainder)
            )
        }

        let submittedHours: Int
        let disposition: RemainderDisposition
        switch rule {
        case .up:
            submittedHours = wholeHours + 1
            disposition = .roundedUp(seconds: 3_600 - remainder)
        case .down:
            submittedHours = wholeHours
            disposition = .roundedDown(seconds: remainder)
        case .transfer:
            submittedHours = wholeHours
            disposition = .transferred(seconds: remainder)
        }

        return ReportingLineResult(line: line, rule: rule, submittedHours: submittedHours, disposition: disposition)
    }

    static func compute(_ lines: [ReportingLine], rules: [String: RoundingRule]) -> [ReportingLineResult] {
        lines.map { compute($0, rule: rules[$0.id]) }
    }

    static func isComplete(_ results: [ReportingLineResult]) -> Bool {
        results.allSatisfy { result in
            if case .undecided = result.disposition {
                return false
            }
            return true
        }
    }
}

private struct Category {
    let name: String
    let iconName: String
    let type: TrackerType
}

private struct SeparateLine {
    let iconName: String
    var actualSeconds: TimeInterval = 0
    var carriedInSeconds: TimeInterval = 0
    var carriedInFrom: Set<YearMonth> = []
}
