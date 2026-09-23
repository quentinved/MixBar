import Foundation

// Driven ports: what the core needs from the outside world, faked in tests.

protocol AudioApplicationCatalog: AnyObject {
    func currentApplications() -> [AudioApplication]

    /// Called on the main queue when an app starts or stops making sound.
    func observeChanges(_ handler: @escaping () -> Void)
}

/// Applies per-app gain to live audio, by whatever means the adapter needs.
protocol AudioMixingEngine: AnyObject {
    /// Apps absent from `gains` are left alone. Those absent from `playing`
    /// are paused, and kept ready so resuming one costs no rebuild.
    func apply(gains: [AudioAppID: Float], playing: Set<AudioAppID>)

    /// Peak since the last call, consumed destructively so meters decay.
    func takePeak(for id: AudioAppID) -> Float

    /// Set when the engine could not start; surfaced to the user verbatim.
    var failure: String? { get }

    func shutdown()
}

protocol AudioOutputDirectory: AnyObject {
    func availableOutputs() -> [AudioOutput]
    func currentOutput() -> AudioOutput?
    func selectOutput(_ output: AudioOutput) throws

    /// Called on the main queue when a device appears, leaves or becomes the default.
    func observeChanges(_ handler: @escaping () -> Void)
}

protocol MixSettingsStore: AnyObject {
    func load() -> StoredMixes
    func save(_ settings: StoredMixes)
}
