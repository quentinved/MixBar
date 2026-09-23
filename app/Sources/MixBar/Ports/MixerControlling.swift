import Foundation

/// Driving port: the only surface a UI is allowed to touch.
protocol MixerControlling: AnyObject {
    /// Re-read the world and recompute what should be playing through us.
    @discardableResult
    func refresh() -> MixerSnapshot

    func setVolume(_ volume: Volume, for id: AudioAppID)
    func toggleMute(for id: AudioAppID)
    func resetAll()

    func selectOutput(_ output: AudioOutput)

    var showIdleApps: Bool { get set }

    /// Presentational, but persisted, so the core owns it like any setting.
    var layout: MixerLayout { get set }

    func levels() -> [AudioAppID: Float]

    /// Called on the main queue when the world changed and `refresh` is due.
    func observeChanges(_ handler: @escaping () -> Void)

    func shutdown()
}
