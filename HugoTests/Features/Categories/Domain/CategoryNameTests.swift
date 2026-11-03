import Testing

@testable import Hugo

struct CategoryNameTests {
    @Test
    func emptyEditReturnsOriginal() {
        #expect(CategoryName.committed(edited: "", original: "Bethel") == "Bethel")
    }

    @Test
    func whitespaceOnlyEditReturnsOriginal() {
        #expect(CategoryName.committed(edited: "  \n ", original: "Bethel") == "Bethel")
    }

    @Test
    func editIsTrimmed() {
        #expect(CategoryName.committed(edited: "  Bethel ", original: "Other") == "Bethel")
    }

    @Test
    func normalEditIsKept() {
        #expect(CategoryName.committed(edited: "Building", original: "Bethel") == "Building")
    }
}
