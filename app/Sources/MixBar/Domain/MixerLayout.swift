import Foundation

/// How the mixer arranges its rows. A stored user preference, so it lives in
/// the domain alongside the other settings rather than in the view.
enum MixerLayout: String, CaseIterable, Sendable {
    /// One line per app. Fits the most apps on screen.
    case compact
    /// Icon, name and a full-width slider. The default.
    case comfortable
    /// Vertical faders side by side, like a mixing desk.
    case mixer

    var title: String {
        switch self {
        case .compact: return "Compact"
        case .comfortable: return "Comfortable"
        case .mixer: return "Mixer"
        }
    }
}
