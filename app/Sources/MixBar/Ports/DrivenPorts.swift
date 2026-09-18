import Foundation

// Driven ports: what the core needs from the outside world, faked in tests.

protocol AudioApplicationCatalog: AnyObject {
    func currentApplications() -> [AudioApplication]
}

/// Applies per-app gain to live audio, by whatever means the adapter needs.
protocol AudioMixingEngine: AnyObject {
    /// Apps absent from the dictionary are left alone.
    func apply(gains: [AudioAppID: Float])

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
}

protocol MixSettingsStore: AnyObject {
    func load() -> StoredMixes
    func save(_ settings: StoredMixes)
}
