import Foundation
import Testing

@testable import Hugo

struct SchoolTests {
    @Test
    func pioneerServiceSchoolGivesThirtyHours() {
        #expect(School.pioneerServiceSchool.creditHours == 30)
        #expect(School.pioneerServiceSchool.hoursRange == 1...30)
    }

    @Test
    func onlyRegularPioneersSeePioneerServiceSchool() {
        #expect(School.available(forStatusID: "regular-pioneer") == [.pioneerServiceSchool])
        #expect(School.available(forStatusID: "publisher").isEmpty)
        #expect(School.available(forStatusID: "auxiliary-pioneer").isEmpty)
        #expect(School.available(forStatusID: "").isEmpty)
    }

    @Test
    func unknownSchoolIDGetsTheGenericName() {
        let english = Locale(identifier: "en")
        #expect(School.name(forID: "future-school", locale: english) == "School credit")
        #expect(School.name(forID: "pioneer-service-school", locale: english) == "Pioneer Service School")
    }
}
