import Foundation
import Testing

@testable import Hugo

struct HelpArticleTests {
    private let screens: [[HelpArticle]] = [
        HelpArticle.year, HelpArticle.submitReport, HelpArticle.reportSettings, HelpArticle.categories,
    ]

    @Test
    func everyScreenListsAtLeastOneArticleWithoutRepeats() {
        for articles in screens {
            #expect(!articles.isEmpty)
            #expect(Set(articles).count == articles.count)
        }
    }

    @Test
    func everyArticleIsListedOnSomeScreen() {
        let listed = Set(screens.flatMap { $0 })
        #expect(listed == Set(HelpArticle.allCases))
    }

    @Test
    func screensListTheAgreedArticles() {
        #expect(HelpArticle.year == [.targetThisMonth, .fieldServiceAndCredit])
        #expect(HelpArticle.submitReport == [.roundingRules, .fieldServiceAndCredit])
        #expect(HelpArticle.reportSettings == [.roundingRules])
        #expect(HelpArticle.categories == [.fieldServiceAndCredit])
    }

    @Test
    func roundingKeepsItsExistingFile() {
        #expect(HelpArticle.roundingRules.resourceName == "RoundingRule")
    }
}
