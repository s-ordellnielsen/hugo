import Foundation
import SwiftData
import Testing

@testable import Hugo

@MainActor
struct SchoolCreditServiceTests {
    private let october = YearMonth(year: 2026, month: 10)
    private let november = YearMonth(year: 2026, month: 11)

    @Test
    func addStoresSchoolMonthAndHours() throws {
        let container = try InMemoryModelContainer.make()
        let context = ModelContext(container)
        let service = SchoolCreditService(context: context)

        try service.add(SchoolCreditDraft(school: .pioneerServiceSchool, month: october, hours: 30))

        let credits = try context.fetch(FetchDescriptor<SchoolCredit>())
        #expect(credits.count == 1)
        let credit = try #require(credits.first)
        #expect(credit.schoolID == "pioneer-service-school")
        #expect(credit.yearMonth == october)
        #expect(credit.hours == 30)
    }

    @Test
    func addRejectsHoursOutsideTheQuota() throws {
        let container = try InMemoryModelContainer.make()
        let context = ModelContext(container)
        let service = SchoolCreditService(context: context)

        #expect(throws: SchoolCreditService.ValidationError.hoursOutOfRange(1...30)) {
            try service.add(SchoolCreditDraft(school: .pioneerServiceSchool, month: october, hours: 0))
        }
        #expect(throws: SchoolCreditService.ValidationError.hoursOutOfRange(1...30)) {
            try service.add(SchoolCreditDraft(school: .pioneerServiceSchool, month: october, hours: 31))
        }

        #expect(try context.fetch(FetchDescriptor<SchoolCredit>()).isEmpty)
    }

    @Test
    func updateChangesMonthAndHours() throws {
        let container = try InMemoryModelContainer.make()
        let context = ModelContext(container)
        let service = SchoolCreditService(context: context)
        let credit = try service.add(SchoolCreditDraft(school: .pioneerServiceSchool, month: october, hours: 30))

        try service.update(credit, with: SchoolCreditDraft(school: .pioneerServiceSchool, month: november, hours: 15))

        let fetched = try #require(try context.fetch(FetchDescriptor<SchoolCredit>()).first)
        #expect(fetched.yearMonth == november)
        #expect(fetched.hours == 15)
    }

    @Test
    func deleteRemovesTheCredit() throws {
        let container = try InMemoryModelContainer.make()
        let context = ModelContext(container)
        let service = SchoolCreditService(context: context)
        let credit = try service.add(SchoolCreditDraft(school: .pioneerServiceSchool, month: october, hours: 30))

        try service.delete(credit)

        #expect(try context.fetch(FetchDescriptor<SchoolCredit>()).isEmpty)
    }
}
