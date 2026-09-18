import Foundation
@testable import MixBar

/// Stand-ins for the driven ports. The core never touches Core Audio, so the
/// whole of its behaviour is reachable without an audio device.
final class FakeCatalog: AudioApplicationCatalog {
    var applications: [AudioApplication] = []
    func currentApplications() -> [AudioApplication] { applications }
}

final class FakeEngine: AudioMixingEngine {
    /// Every gain map the core has asked for, in order.
    private(set) var applied: [[AudioAppID: Float]] = []
    private(set) var didShutDown = false
    var peaks: [AudioAppID: Float] = [:]
    var failure: String?

    var latest: [AudioAppID: Float] { applied.last ?? [:] }

    func apply(gains: [AudioAppID: Float]) { applied.append(gains) }
    func takePeak(for id: AudioAppID) -> Float { peaks[id] ?? 0 }
    func shutdown() { didShutDown = true }
}

final class FakeOutputs: AudioOutputDirectory {
    var outputs: [AudioOutput] = [AudioOutput(id: "speakers", name: "Speakers")]
    var selected: AudioOutput?
    func availableOutputs() -> [AudioOutput] { outputs }
    func currentOutput() -> AudioOutput? { selected ?? outputs.first }
    func selectOutput(_ output: AudioOutput) throws { selected = output }
}

final class FakeStore: MixSettingsStore {
    var stored = StoredMixes()
    private(set) var saveCount = 0
    func load() -> StoredMixes { stored }
    func save(_ settings: StoredMixes) { stored = settings; saveCount += 1 }
}

func app(
    _ bundleID: String,
    name: String? = nil,
    playing: Bool = true
) -> AudioApplication {
    AudioApplication(
        id: .bundle(bundleID),
        name: name ?? bundleID,
        bundleID: bundleID,
        processIdentifier: 1,
        isPlaying: playing
    )
}
