import Foundation

/// Everything a UI needs to draw the mixer, in one immutable value.
struct MixerSnapshot: Equatable, Sendable {
    struct Row: Identifiable, Equatable, Sendable {
        let application: AudioApplication
        let mix: AppMix

        var id: AudioAppID { application.id }

        /// Only a routed app has a tap to read a level from.
        var isMetered: Bool { !mix.isDefault }
    }

    var rows: [Row] = []
    var outputs: [AudioOutput] = []
    var currentOutput: AudioOutput?
    var failure: String?
}

/// Stored per-app settings, as handed to and from a settings store.
struct StoredMixes: Equatable, Sendable {
    var mixes: [String: AppMix] = [:]
    var showIdleApps: Bool = false
    var layout: MixerLayout = .comfortable
}
