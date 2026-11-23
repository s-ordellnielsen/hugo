import SwiftUI
import Testing

@testable import Hugo

struct AdaptiveDetailTests {
    @Test
    func regularMapsToInspector() {
        #expect(DetailPresentation.presentation(for: .regular) == .inspector)
    }

    @Test
    func compactMapsToSheet() {
        #expect(DetailPresentation.presentation(for: .compact) == .sheet)
    }

    @Test
    func unknownMapsToSheet() {
        #expect(DetailPresentation.presentation(for: nil) == .sheet)
    }
}
