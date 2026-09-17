import Observation

enum SettingsTab: Hashable {
    case general
    case smartLists
    case advanced
}

/// Lets any view request that the Settings window open on a specific tab.
/// Set `pendingTab` before calling `openSettings()`; `SettingsView` consumes it.
@MainActor @Observable
final class SettingsRouter {
    static let shared = SettingsRouter()

    var pendingTab: SettingsTab?

    private init() {}
}
