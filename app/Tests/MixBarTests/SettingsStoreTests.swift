import Foundation
import Testing
@testable import MixBar

@Suite("Settings storage")
struct SettingsStoreTests {
    /// A throwaway domain per test, removed afterwards, so the suite never reads
    /// or leaves behind anything in the real app's preferences.
    private func withDefaults(_ body: (UserDefaults) throws -> Void) throws {
        let suite = "MixBarTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        try body(defaults)
    }

    @Test("Everything written comes back unchanged")
    func settingsRoundTrip() throws {
        try withDefaults { defaults in
            let store = UserDefaultsSettingsStore(defaults: defaults)
            let written = StoredMixes(
                mixes: [
                    "com.spotify.client": AppMix(volume: Volume(0.25), isMuted: false),
                    "com.apple.Music": AppMix(volume: Volume(0.5), isMuted: true),
                ],
                showIdleApps: true,
                layout: .mixer)

            store.save(written)

            #expect(UserDefaultsSettingsStore(defaults: defaults).load() == written)
        }
    }

    @Test("A store with nothing in it loads the defaults")
    func emptyStoreLoadsDefaults() throws {
        try withDefaults { defaults in
            let loaded = UserDefaultsSettingsStore(defaults: defaults).load()

            #expect(loaded.mixes.isEmpty)
            #expect(!loaded.showIdleApps)
            #expect(loaded.layout == .comfortable)
        }
    }

    /// The reason the loader goes through `NSNumber`: a plist round-trip hands
    /// back a whole number as an `Int`, and a hand-edited file a `String`.
    @Test("A volume stored as an Int or a String still loads")
    func volumeSurvivesPlistCoercion() throws {
        try withDefaults { defaults in
            defaults.set([
                "com.int": ["volume": 1, "muted": false],
                "com.string": ["volume": "0.25", "muted": false],
                "com.double": ["volume": 0.5, "muted": true],
            ], forKey: "appMixes")

            let loaded = UserDefaultsSettingsStore(defaults: defaults).load()

            #expect(loaded.mixes["com.int"]?.volume.value == 1)
            #expect(loaded.mixes["com.string"]?.volume.value == 0.25)
            #expect(loaded.mixes["com.double"] == AppMix(volume: Volume(0.5), isMuted: true))
        }
    }

    @Test("Nonsense in the stored file does not lose the rest of the settings")
    func unreadableEntriesFallBackToDefaults() throws {
        try withDefaults { defaults in
            defaults.set(["com.broken": ["volume": "loud"]], forKey: "appMixes")
            defaults.set("kaleidoscope", forKey: "layout")

            let loaded = UserDefaultsSettingsStore(defaults: defaults).load()

            #expect(loaded.mixes["com.broken"] == AppMix())
            #expect(loaded.layout == .comfortable)
        }
    }

    /// Volumes are clamped on the way in, so an edited file cannot hand the
    /// render thread a gain above unity.
    @Test("An out-of-range stored volume is clamped on load")
    func storedVolumeIsClamped() throws {
        try withDefaults { defaults in
            defaults.set([
                "com.loud": ["volume": 4, "muted": false],
                "com.negative": ["volume": -2, "muted": false],
            ], forKey: "appMixes")

            let loaded = UserDefaultsSettingsStore(defaults: defaults).load()

            #expect(loaded.mixes["com.loud"]?.volume.value == 1)
            #expect(loaded.mixes["com.negative"]?.volume.value == 0)
        }
    }
}
