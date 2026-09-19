import Foundation

/// A scripted roster: one app as the demo should portray it, plus the shape of
/// the meter it drives.
private struct DemoApp {
    let bundleID: String
    let name: String
    let isPlaying: Bool
    let mix: AppMix

    /// Peak at full gain, 0...1.
    let loudness: Float

    /// Radians per second of the meter's slow swell, and where it starts, so
    /// eight bars breathe independently instead of pulsing in unison.
    let tempo: Float
    let phase: Float
}

private enum DemoRoster {
    /// Real bundle IDs, because the icons are looked up from them: a demo that
    /// renders `app.dashed` eight times is not worth screenshotting.
    static let apps: [DemoApp] = [
        DemoApp(
            bundleID: "com.spotify.client", name: "Spotify", isPlaying: true,
            mix: AppMix(volume: Volume(0.62), isMuted: false),
            loudness: 0.94, tempo: 3.1, phase: 0.0),
        DemoApp(
            bundleID: "company.thebrowser.Browser", name: "Arc", isPlaying: true,
            mix: AppMix(),
            loudness: 0.71, tempo: 2.3, phase: 1.1),
        DemoApp(
            bundleID: "com.apple.Music", name: "Music", isPlaying: true,
            mix: AppMix(volume: Volume(0.78), isMuted: false),
            loudness: 0.86, tempo: 2.7, phase: 0.6),
        DemoApp(
            bundleID: "com.hnc.Discord", name: "Discord", isPlaying: true,
            mix: AppMix(volume: Volume(0.34), isMuted: false),
            loudness: 0.58, tempo: 4.7, phase: 2.4),
        DemoApp(
            bundleID: "org.videolan.vlc", name: "VLC", isPlaying: true,
            mix: AppMix(volume: Volume(0.88), isMuted: false),
            loudness: 0.80, tempo: 2.1, phase: 4.0),
        DemoApp(
            bundleID: "com.microsoft.teams2", name: "Microsoft Teams", isPlaying: true,
            mix: AppMix(volume: Volume(0.70), isMuted: true),
            loudness: 0.64, tempo: 3.3, phase: 1.9),
        // Idle, but with a volume set: the row that shows MixBar remembers an
        // app between launches.
        DemoApp(
            bundleID: "com.apple.podcasts", name: "Podcasts", isPlaying: false,
            mix: AppMix(volume: Volume(0.30), isMuted: false),
            loudness: 0, tempo: 1, phase: 0),
    ]

    static let byID: [AudioAppID: DemoApp] = Dictionary(
        uniqueKeysWithValues: apps.map { (AudioAppID.bundle($0.bundleID), $0) })
}

final class DemoApplicationCatalog: AudioApplicationCatalog {
    func currentApplications() -> [AudioApplication] {
        DemoRoster.apps.map {
            AudioApplication(
                id: .bundle($0.bundleID),
                name: $0.name,
                bundleID: $0.bundleID,
                // No such process: the icon resolves from the bundle ID instead.
                processIdentifier: 0,
                isPlaying: $0.isPlaying)
        }
    }
}

/// Synthesises meters from the clock, so the bars move like audio rather than
/// sitting frozen at whatever the last frame happened to be.
final class DemoMixingEngine: AudioMixingEngine {
    var failure: String?

    private let start = Date()
    private var gains: [AudioAppID: Float] = [:]

    func apply(gains: [AudioAppID: Float]) {
        self.gains = gains
    }

    func takePeak(for id: AudioAppID) -> Float {
        guard let app = DemoRoster.byID[id], app.isPlaying else { return 0 }

        let elapsed = Float(Date().timeIntervalSince(start))
        let swell = 0.58 + 0.42 * sin(elapsed * app.tempo + app.phase)
        let flutter = 0.84 + 0.16 * sin(elapsed * app.tempo * 5.3 + app.phase * 2)

        let level = app.loudness * swell * flutter * (gains[id] ?? 1)
        return min(max(level, 0), 1)
    }

    func shutdown() {}
}

final class DemoOutputDirectory: AudioOutputDirectory {
    private static let all = [
        AudioOutput(id: "builtin", name: "MacBook Pro Speakers"),
        AudioOutput(id: "airpods", name: "AirPods Pro"),
        AudioOutput(id: "display", name: "Studio Display"),
    ]

    private var selected = DemoOutputDirectory.all[0]

    func availableOutputs() -> [AudioOutput] { Self.all }
    func currentOutput() -> AudioOutput? { selected }
    func selectOutput(_ output: AudioOutput) throws { selected = output }
}

/// In memory only: a demo launch must not overwrite the real settings of
/// whoever is running it.
final class DemoSettingsStore: MixSettingsStore {
    private var settings = StoredMixes(
        mixes: Dictionary(
            uniqueKeysWithValues: DemoRoster.apps
                .filter { !$0.mix.isDefault }
                .map { ($0.bundleID, $0.mix) }),
        showIdleApps: false,
        layout: .comfortable)

    func load() -> StoredMixes { settings }
    func save(_ settings: StoredMixes) { self.settings = settings }
}

enum DemoComposition {
    static func mixer() -> MixerControlling {
        MixerService(
            catalog: DemoApplicationCatalog(),
            engine: DemoMixingEngine(),
            outputs: DemoOutputDirectory(),
            store: DemoSettingsStore())
    }
}
