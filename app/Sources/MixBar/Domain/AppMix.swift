import Foundation

/// A volume level, always within 0...1.
struct Volume: Equatable, Sendable {
    static let full = Volume(1)

    let value: Float

    init(_ value: Float) {
        self.value = min(max(value, 0), 1)
    }
}

/// How one app should be mixed.
struct AppMix: Equatable, Sendable {
    var volume: Volume = .full
    var isMuted: Bool = false

    /// Muting wins over the slider, and the slider position is remembered so
    /// unmuting restores it.
    var gain: Float { isMuted ? 0 : volume.value }

    var isDefault: Bool { !isMuted && volume == .full }
}
