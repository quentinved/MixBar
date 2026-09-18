import Foundation

/// Persists per-app mixes, keyed by bundle ID so a volume survives a relaunch.
final class UserDefaultsSettingsStore: MixSettingsStore {
    private enum Keys {
        static let mixes = "appMixes"
        static let showIdle = "showIdleApps"
        static let layout = "layout"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> StoredMixes {
        var mixes: [String: AppMix] = [:]
        if let raw = defaults.dictionary(forKey: Keys.mixes) as? [String: [String: Any]] {
            for (key, value) in raw {
                // Via NSNumber: a plist round-trip can hand back an Int, and a
                // hand-edited one a String.
                let volume = (value["volume"] as? NSNumber)?.floatValue
                    ?? (value["volume"] as? String).flatMap(Float.init)
                let muted = (value["muted"] as? NSNumber)?.boolValue ?? false
                mixes[key] = AppMix(volume: volume.map(Volume.init) ?? .full, isMuted: muted)
            }
        }
        let layout = defaults.string(forKey: Keys.layout).flatMap(MixerLayout.init(rawValue:))
        return StoredMixes(
            mixes: mixes,
            showIdleApps: defaults.bool(forKey: Keys.showIdle),
            layout: layout ?? .comfortable)
    }

    func save(_ settings: StoredMixes) {
        let raw = settings.mixes.mapValues { mix in
            ["volume": Double(mix.volume.value), "muted": mix.isMuted] as [String: Any]
        }
        defaults.set(raw, forKey: Keys.mixes)
        defaults.set(settings.showIdleApps, forKey: Keys.showIdle)
        defaults.set(settings.layout.rawValue, forKey: Keys.layout)
    }
}
