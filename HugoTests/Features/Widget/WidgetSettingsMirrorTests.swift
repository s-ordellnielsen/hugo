import Foundation
import Testing

@testable import Hugo

@MainActor
struct WidgetSettingsMirrorTests {
    /// Two fresh suites per test, removed at the end.
    private final class Suites {
        let sourceName = UUID().uuidString
        let suiteName = UUID().uuidString
        let source: UserDefaults
        let suite: UserDefaults

        init() {
            source = UserDefaults(suiteName: sourceName)!
            suite = UserDefaults(suiteName: suiteName)!
        }

        func remove() {
            source.removePersistentDomain(forName: sourceName)
            suite.removePersistentDomain(forName: suiteName)
        }
    }

    @Test
    func roundTripCarriesTheThreeValues() throws {
        let suites = Suites()
        defer { suites.remove() }
        suites.source.set("regular-pioneer", forKey: UserDefaultsKeys.publisherStatus)
        suites.source.set(5, forKey: UserDefaultsKeys.plannerExtraHours)
        suites.source.set(true, forKey: UserDefaultsKeys.bufferInOverview)

        let mirror = WidgetSettingsMirror(source: suites.source, suite: suites.suite)

        #expect(mirror.write())
        #expect(
            WidgetSettingsMirror.read(from: suites.suite)
                == WidgetSettings(
                    publisherStatusID: "regular-pioneer", bufferHours: 5,
                    storeSchemaVersion: WidgetSettings.schemaVersionString()))
    }

    @Test
    func unchangedValuesWriteNothingAndChangesFollow() throws {
        let suites = Suites()
        defer { suites.remove() }
        suites.source.set("publisher", forKey: UserDefaultsKeys.publisherStatus)
        let mirror = WidgetSettingsMirror(source: suites.source, suite: suites.suite)
        #expect(mirror.write())

        #expect(!mirror.write())

        suites.source.set(3, forKey: UserDefaultsKeys.plannerExtraHours)
        suites.source.set(true, forKey: UserDefaultsKeys.bufferInOverview)
        #expect(mirror.write())
        #expect(WidgetSettingsMirror.read(from: suites.suite)?.bufferHours == 3)
    }

    @Test
    func bufferSwitchOffStoresZeroHours() throws {
        let suites = Suites()
        defer { suites.remove() }
        suites.source.set(5, forKey: UserDefaultsKeys.plannerExtraHours)
        let mirror = WidgetSettingsMirror(source: suites.source, suite: suites.suite)

        suites.source.set(false, forKey: UserDefaultsKeys.bufferInOverview)
        mirror.write()
        #expect(WidgetSettingsMirror.read(from: suites.suite)?.bufferHours == 0)

        suites.source.set(true, forKey: UserDefaultsKeys.bufferInOverview)
        mirror.write()
        #expect(WidgetSettingsMirror.read(from: suites.suite)?.bufferHours == 5)
    }

    @Test
    func nilSuiteWritesNothing() throws {
        let suites = Suites()
        defer { suites.remove() }
        let mirror = WidgetSettingsMirror(source: suites.source, suite: nil)

        #expect(!mirror.write())
        #expect(WidgetSettingsMirror.read(from: nil) == nil)
    }
}
