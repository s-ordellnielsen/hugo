import Foundation
import Testing

@testable import Hugo

struct OverseerDetailsTests {
    private let english = Locale(identifier: "en_US")

    @Test
    func aFirstNameAndPhoneNumberAreEnoughToSave() {
        #expect(OverseerDetails(firstName: "Anna", phoneNumber: "+45 12 34 56 78").canSave)
    }

    @Test
    func detailsWithoutAFirstNameOrPhoneNumberCannotBeSaved() {
        #expect(!OverseerDetails(lastName: "Berg", phoneNumber: "12345678").canSave)
        #expect(!OverseerDetails(firstName: "Anna", lastName: "Berg").canSave)
        #expect(!OverseerDetails(firstName: "  ", phoneNumber: " \n").canSave)
    }

    @Test
    func trimmingRemovesSpacesAtTheEnds() {
        let details = OverseerDetails(firstName: " Anna ", lastName: "Berg\n", phoneNumber: " 12345678 ")

        #expect(details.trimmed == OverseerDetails(firstName: "Anna", lastName: "Berg", phoneNumber: "12345678"))
    }

    @Test
    func theFullNameJoinsTheFirstAndLastName() {
        #expect(OverseerDetails(firstName: " Anna", lastName: "Berg ").fullName(locale: english) == "Anna Berg")
    }

    @Test
    func theFullNameIsTheFirstNameWhenThereIsNoLastName() {
        #expect(OverseerDetails(firstName: "Anna").fullName(locale: english) == "Anna")
    }

    @Test
    func editingASavedOverseerKeepsTheNameParts() {
        let details = OverseerDetails(
            savedFullName: "Anna Berg", firstName: "Anna", lastName: "Berg", phoneNumber: "12345678")

        #expect(details == OverseerDetails(firstName: "Anna", lastName: "Berg", phoneNumber: "12345678"))
    }

    @Test
    func editingAnOverseerSavedWithOnlyAFullNameStartsWithItAsTheFirstName() {
        let details = OverseerDetails(
            savedFullName: "Anna Berg", firstName: "", lastName: "", phoneNumber: "12345678")

        #expect(details == OverseerDetails(firstName: "Anna Berg", phoneNumber: "12345678"))
    }
}
