import Foundation
import Testing

@testable import Hugo

@MainActor
struct SettingsSyncServiceTests {
    private final class FakeCloudStore: CloudSettingsStore {
        var values: [String: Any] = [:]
        private(set) var writeCount = 0

        func object(forKey key: String) -> Any? { values[key] }

        func set(_ value: Any?, forKey key: String) {
            writeCount += 1
            values[key] = value
        }

        func synchronize() -> Bool { true }
    }

    private let defaults = UserDefaults(suiteName: "SettingsSyncServiceTests-\(UUID().uuidString)")!
    private let cloud = FakeCloudStore()

    private var service: SettingsSyncService {
        SettingsSyncService(defaults: defaults, cloud: cloud)
    }

    @Test
    func startTakesTheCloudValueOverTheDevicesValue() {
        defaults.set("Old Name", forKey: UserDefaultsKeys.overseerFullName)
        cloud.values[UserDefaultsKeys.overseerFullName] = "New Name"

        service.start()

        #expect(defaults.string(forKey: UserDefaultsKeys.overseerFullName) == "New Name")
        #expect(cloud.writeCount == 0)
    }

    @Test
    func startSendsSettingsOnlyThisDeviceHas() {
        defaults.set("+45 12 34 56 78", forKey: UserDefaultsKeys.overseerPhoneNumber)
        defaults.set(5, forKey: UserDefaultsKeys.durationMinuteInterval)

        service.start()

        #expect(cloud.values[UserDefaultsKeys.overseerPhoneNumber] as? String == "+45 12 34 56 78")
        #expect(cloud.values[UserDefaultsKeys.durationMinuteInterval] as? Int == 5)
    }

    @Test
    func untouchedSettingsAreNotSent() {
        service.start()

        #expect(cloud.values.isEmpty)
    }

    @Test
    func deviceOnlySettingsNeverSync() {
        defaults.set("regular-pioneer", forKey: UserDefaultsKeys.publisherStatus)
        defaults.set(false, forKey: UserDefaultsKeys.isOnboarding)
        defaults.set(true, forKey: UserDefaultsKeys.hasRunInitialSetup)
        defaults.set("byCategory", forKey: UserDefaultsKeys.overviewListStyle)
        cloud.values[UserDefaultsKeys.publisherStatus] = "publisher"

        service.start()

        #expect(cloud.values.count == 1)
        #expect(defaults.string(forKey: UserDefaultsKeys.publisherStatus) == "regular-pioneer")
    }

    @Test
    func aChangeOnThisDeviceIsSent() {
        service.start()
        defaults.set("Hej {first}!", forKey: UserDefaultsKeys.overseerGreetingTemplate)

        service.pushToCloud()

        #expect(cloud.values[UserDefaultsKeys.overseerGreetingTemplate] as? String == "Hej {first}!")
    }

    @Test
    func aChangeFromAnotherDeviceIsWrittenToUserDefaults() {
        service.start()
        cloud.values[UserDefaultsKeys.plannerExtraHours] = 3

        service.pullFromCloud()

        #expect(defaults.integer(forKey: UserDefaultsKeys.plannerExtraHours) == 3)
    }

    @Test
    func equalValuesAreNotWrittenAgain() {
        defaults.set("Jens", forKey: UserDefaultsKeys.overseerFirstName)
        cloud.values[UserDefaultsKeys.overseerFirstName] = "Jens"

        service.start()
        service.pushToCloud()
        service.pullFromCloud()

        #expect(cloud.writeCount == 0)
    }
}
