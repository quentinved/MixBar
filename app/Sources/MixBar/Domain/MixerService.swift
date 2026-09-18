import Foundation

/// The core: the mixing rules. No Core Audio, no UserDefaults, no SwiftUI.
final class MixerService: MixerControlling {
    private let catalog: AudioApplicationCatalog
    private let engine: AudioMixingEngine
    private let outputs: AudioOutputDirectory
    private let store: MixSettingsStore

    private var mixes: [AudioAppID: AppMix]
    private var applications: [AudioApplication] = []
    private var meters: [AudioAppID: Float] = [:]

    var showIdleApps: Bool {
        didSet {
            guard showIdleApps != oldValue else { return }
            persist()
        }
    }

    var layout: MixerLayout {
        didSet {
            guard layout != oldValue else { return }
            persist()
        }
    }

    init(
        catalog: AudioApplicationCatalog,
        engine: AudioMixingEngine,
        outputs: AudioOutputDirectory,
        store: MixSettingsStore
    ) {
        self.catalog = catalog
        self.engine = engine
        self.outputs = outputs
        self.store = store

        let stored = store.load()
        self.mixes = Dictionary(
            uniqueKeysWithValues: stored.mixes.map { (AudioAppID(raw: $0.key), $0.value) })
        self.showIdleApps = stored.showIdleApps
        self.layout = stored.layout
    }

    // MARK: - MixerControlling

    @discardableResult
    func refresh() -> MixerSnapshot {
        applications = catalog.currentApplications()
        engine.apply(gains: gainsForRoutedApps())

        let visible = showIdleApps ? applications : applications.filter(isWorthShowing)
        let rows = visible
            .sorted(by: Self.playingFirstThenByName)
            .map { MixerSnapshot.Row(application: $0, mix: mix(for: $0.id)) }

        return MixerSnapshot(
            rows: rows,
            outputs: outputs.availableOutputs(),
            currentOutput: outputs.currentOutput(),
            failure: engine.failure
        )
    }

    func setVolume(_ volume: Volume, for id: AudioAppID) {
        var current = mix(for: id)
        current.volume = volume
        // Dragging the slider up is the natural way to say "unmute".
        if volume.value > 0 { current.isMuted = false }
        update(current, for: id)
    }

    func toggleMute(for id: AudioAppID) {
        var current = mix(for: id)
        current.isMuted.toggle()
        update(current, for: id)
    }

    func resetAll() {
        mixes.removeAll()
        persist()
        engine.apply(gains: gainsForRoutedApps())
    }

    func selectOutput(_ output: AudioOutput) {
        try? outputs.selectOutput(output)
        // The engine's mixing device wraps the old output, so it must rebuild.
        engine.apply(gains: gainsForRoutedApps())
    }

    func shutdown() {
        engine.shutdown()
    }

    func levels() -> [AudioAppID: Float] {
        sampleMeters()
        return meters
    }

    /// How much of the previous peak survives a quiet frame, so bars fall smoothly.
    private static let meterDecay: Float = 0.72

    private func sampleMeters() {
        var next: [AudioAppID: Float] = [:]
        for application in applications where application.isPlaying {
            let peak = engine.takePeak(for: application.id)
            let previous = meters[application.id] ?? 0
            next[application.id] = max(peak, previous * Self.meterDecay)
        }
        meters = next
    }

    /// Playing apps first: whatever you came to adjust is the thing making noise.
    private static func playingFirstThenByName(
        _ lhs: AudioApplication, _ rhs: AudioApplication
    ) -> Bool {
        (lhs.isPlaying ? 0 : 1, lhs.name.lowercased())
            < (rhs.isPlaying ? 0 : 1, rhs.name.lowercased())
    }

    /// Trusts `isRunningOutput`: proving an app is silent means tapping it.
    private func isWorthShowing(_ application: AudioApplication) -> Bool {
        if !mix(for: application.id).isDefault { return true }
        guard application.isPlaying else { return false }
        return !Self.alwaysSilent.contains(application.id.raw)
    }

    private static let alwaysSilent: Set<String> = [
        "com.apple.TelephonyUtilities",
        "com.apple.controlcenter",
        "com.apple.CoreSpeech",
        "com.apple.assistantd",
        "com.apple.Siri",
        "com.apple.SiriNCService",
        "com.apple.PowerChime",
        "com.apple.cmio.ContinuityCaptureAgent",
    ]

    // MARK: - Rules

    private func mix(for id: AudioAppID) -> AppMix {
        mixes[id] ?? AppMix()
    }

    private func update(_ mix: AppMix, for id: AudioAppID) {
        if mix.isDefault {
            mixes.removeValue(forKey: id)
        } else {
            mixes[id] = mix
        }
        persist()
        engine.apply(gains: gainsForRoutedApps())
    }

    /// Only apps the user actually moved: routing means muting and re-rendering,
    /// and doing that to every playing app crackled, even on silence.
    private func gainsForRoutedApps() -> [AudioAppID: Float] {
        var gains: [AudioAppID: Float] = [:]
        for application in applications where application.isPlaying {
            let mix = mix(for: application.id)
            guard !mix.isDefault else { continue }
            gains[application.id] = mix.gain
        }
        return gains
    }

    private func persist() {
        let raw = Dictionary(uniqueKeysWithValues: mixes.map { ($0.key.raw, $0.value) })
        store.save(StoredMixes(mixes: raw, showIdleApps: showIdleApps, layout: layout))
    }
}
