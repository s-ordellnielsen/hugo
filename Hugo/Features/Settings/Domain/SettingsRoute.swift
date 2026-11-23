/// The screens the Settings tab pushes from its root page. Each push is a value
/// link, so the tab's path can hold it and reselecting the tab can pop it.
nonisolated enum SettingsRoute: Hashable {
    case publisherStatus
    case report
    case categories
    case general
    case plannerTarget
    case cloudSync
    case privacyPolicy
    case termsOfUse
    #if SHOW_DEBUG_MENU
        case debug
    #endif
}

/// The two screens `ReportSettingsView` pushes. Its own route type, registered on
/// that page, so the page also works in the sheet from the submit screen, which
/// has no Settings stack.
nonisolated enum ReportSettingsRoute: Hashable {
    case overseer
    case greetingTemplate
}
