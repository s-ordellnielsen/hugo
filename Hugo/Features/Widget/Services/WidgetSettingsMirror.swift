import Foundation

/// Copies `WidgetSettings` from the app's standard defaults into the App Group suite the widget reads.
struct WidgetSettingsMirror {
    private let source: UserDefaults
    private let suite: UserDefaults?

    init(source: UserDefaults = .standard, suite: UserDefaults?) {
        self.source = source
        self.suite = suite
    }

    /// The App Group suite named by `HugoAppGroupIdentifier`, or nil when it is not configured.
    static func appGroupSuite(bundle: Bundle = .main) -> UserDefaults? {
        guard
            let identifier = bundle.object(forInfoDictionaryKey: "HugoAppGroupIdentifier") as? String,
            !identifier.isEmpty
        else { return nil }
        return UserDefaults(suiteName: identifier)
    }

    /// Writes the settings to the suite. Returns true when the stored value changed.
    @discardableResult
    func write() -> Bool {
        guard let suite else { return false }
        let settings = WidgetSettings.current(defaults: source)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(settings) else { return false }
        if suite.data(forKey: UserDefaultsKeys.widgetSettings) == data { return false }
        suite.set(data, forKey: UserDefaultsKeys.widgetSettings)
        return true
    }

    static func read(from suite: UserDefaults?) -> WidgetSettings? {
        guard let data = suite?.data(forKey: UserDefaultsKeys.widgetSettings) else { return nil }
        return try? JSONDecoder().decode(WidgetSettings.self, from: data)
    }
}
