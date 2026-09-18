import Foundation

/// Identity across restarts: bundle ID, not pid, so a volume set for Spotify
/// still applies after it quits and comes back.
struct AudioAppID: Hashable, Sendable {
    let raw: String

    static func bundle(_ id: String) -> AudioAppID { AudioAppID(raw: id) }
    static func process(_ pid: Int32) -> AudioAppID { AudioAppID(raw: "pid:\(pid)") }
}

/// An app capable of playing audio. Free of CoreAudio and AppKit types.
struct AudioApplication: Identifiable, Equatable, Sendable {
    let id: AudioAppID
    let name: String
    let bundleID: String?

    /// The nearest ancestor that is a real app: the processes making the noise
    /// are often anonymous helpers, grouped behind this one.
    let processIdentifier: Int32

    let isPlaying: Bool
}

/// A destination audio can be sent to.
struct AudioOutput: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
}
