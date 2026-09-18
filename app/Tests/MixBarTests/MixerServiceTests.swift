import Testing
import Foundation
@testable import MixBar

@Suite("Mixer rules")
struct MixerServiceTests {
    private func makeService(
        catalog: FakeCatalog = FakeCatalog(),
        engine: FakeEngine = FakeEngine(),
        outputs: FakeOutputs = FakeOutputs(),
        store: FakeStore = FakeStore()
    ) -> MixerService {
        MixerService(catalog: catalog, engine: engine, outputs: outputs, store: store)
    }

    @Test("Volume is clamped to a usable range")
    func volumeClamps() {
        #expect(Volume(-3).value == 0)
        #expect(Volume(7).value == 1)
        #expect(Volume(0.42).value == 0.42)
    }

    /// The bug that made the whole system crackle: every playing app was routed
    /// through the mixer, putting an aggregate device in front of the output
    /// even when there was nothing to adjust.
    @Test("An app at default volume is never routed through the mixer")
    func untouchedAppsStayOutOfTheAudioPath() {
        let catalog = FakeCatalog()
        let engine = FakeEngine()
        catalog.applications = [app("com.spotify.client"), app("com.apple.Music")]
        let service = makeService(catalog: catalog, engine: engine)

        service.refresh()

        // Not merely empty now: the engine was never asked to route anything.
        let everRouted = engine.applied.contains { !$0.isEmpty }
        #expect(engine.latest.isEmpty)
        #expect(!everRouted)
    }

    @Test("Only the adjusted app enters the audio path")
    func adjustingOneAppRoutesOnlyThatApp() {
        let catalog = FakeCatalog()
        let engine = FakeEngine()
        catalog.applications = [app("com.spotify.client"), app("com.apple.Music")]
        let service = makeService(catalog: catalog, engine: engine)
        service.refresh()

        service.setVolume(Volume(0.3), for: .bundle("com.spotify.client"))

        #expect(engine.latest == [.bundle("com.spotify.client"): 0.3])
    }

    @Test("Returning to full volume leaves the audio path again")
    func restoringFullVolumeUnroutes() {
        let catalog = FakeCatalog()
        let engine = FakeEngine()
        catalog.applications = [app("com.spotify.client")]
        let service = makeService(catalog: catalog, engine: engine)
        service.refresh()

        service.setVolume(Volume(0.2), for: .bundle("com.spotify.client"))
        #expect(!engine.latest.isEmpty)

        service.setVolume(Volume(1), for: .bundle("com.spotify.client"))
        #expect(engine.latest.isEmpty)
    }

    @Test("Muting drives the gain to silence and remembers the slider")
    func mutingKeepsTheVolumeForLater() {
        let catalog = FakeCatalog()
        let engine = FakeEngine()
        catalog.applications = [app("com.spotify.client")]
        let service = makeService(catalog: catalog, engine: engine)
        service.refresh()
        let spotify = AudioAppID.bundle("com.spotify.client")

        service.setVolume(Volume(0.6), for: spotify)
        service.toggleMute(for: spotify)
        #expect(engine.latest[spotify] == 0)

        service.toggleMute(for: spotify)
        #expect(engine.latest[spotify] == 0.6)
    }

    @Test("Raising the slider off zero also unmutes")
    func slidingUpUnmutes() {
        let catalog = FakeCatalog()
        let engine = FakeEngine()
        catalog.applications = [app("com.spotify.client")]
        let service = makeService(catalog: catalog, engine: engine)
        service.refresh()
        let spotify = AudioAppID.bundle("com.spotify.client")

        service.toggleMute(for: spotify)
        service.setVolume(Volume(0.5), for: spotify)

        #expect(engine.latest[spotify] == 0.5)
    }

    @Test("A muted app stays listed so it can be unmuted")
    func mutedAppRemainsVisibleEvenWhenSilent() {
        let catalog = FakeCatalog()
        catalog.applications = [app("com.spotify.client", playing: false)]
        let service = makeService(catalog: catalog)
        let spotify = AudioAppID.bundle("com.spotify.client")

        service.toggleMute(for: spotify)
        let snapshot = service.refresh()

        #expect(snapshot.rows.map(\.id) == [spotify])
    }

    /// Daemons that hold a permanently silent output stream gave the user
    /// sliders that could not possibly do anything.
    @Test("Permanently silent system processes are not listed")
    func silentSystemProcessesAreHidden() {
        let catalog = FakeCatalog()
        catalog.applications = [
            app("com.apple.TelephonyUtilities"),
            app("com.spotify.client"),
        ]
        let service = makeService(catalog: catalog)

        let snapshot = service.refresh()

        #expect(snapshot.rows.map(\.id) == [.bundle("com.spotify.client")])
    }

    @Test("Idle apps are hidden until asked for")
    func idleAppsAreOptional() {
        let catalog = FakeCatalog()
        catalog.applications = [app("com.apple.Music", playing: false)]
        let service = makeService(catalog: catalog)

        #expect(service.refresh().rows.isEmpty)

        service.showIdleApps = true
        #expect(service.refresh().rows.count == 1)
    }

    @Test("The chosen layout survives a restart")
    func layoutRoundTrips() {
        let store = FakeStore()
        let first = makeService(store: store)
        #expect(first.layout == .comfortable)

        first.layout = .mixer

        let second = MixerService(
            catalog: FakeCatalog(), engine: FakeEngine(),
            outputs: FakeOutputs(), store: store)
        #expect(second.layout == .mixer)
    }

    @Test("Settings survive a restart")
    func settingsRoundTrip() {
        let store = FakeStore()
        let catalog = FakeCatalog()
        catalog.applications = [app("com.spotify.client")]
        let spotify = AudioAppID.bundle("com.spotify.client")

        let first = makeService(catalog: catalog, store: store)
        first.setVolume(Volume(0.25), for: spotify)

        let engine = FakeEngine()
        let second = MixerService(
            catalog: catalog, engine: engine, outputs: FakeOutputs(), store: store)
        second.refresh()

        #expect(engine.latest[spotify] == 0.25)
    }

    @Test("Defaults are not persisted as clutter")
    func defaultMixesAreNotStored() {
        let store = FakeStore()
        let catalog = FakeCatalog()
        catalog.applications = [app("com.spotify.client")]
        let service = makeService(catalog: catalog, store: store)
        let spotify = AudioAppID.bundle("com.spotify.client")

        service.setVolume(Volume(0.4), for: spotify)
        #expect(store.stored.mixes.count == 1)

        service.setVolume(Volume(1), for: spotify)
        #expect(store.stored.mixes.isEmpty)
    }

    @Test("Resetting clears every adjustment")
    func resetClearsEverything() {
        let catalog = FakeCatalog()
        let engine = FakeEngine()
        catalog.applications = [app("com.spotify.client"), app("com.apple.Music")]
        let service = makeService(catalog: catalog, engine: engine)

        service.setVolume(Volume(0.1), for: .bundle("com.spotify.client"))
        service.toggleMute(for: .bundle("com.apple.Music"))
        service.resetAll()

        #expect(engine.latest.isEmpty)
    }

    /// Orphaned taps outliving the process is what forced a coreaudiod restart.
    @Test("Shutdown releases the audio resources")
    func shutdownLeavesTheAudioPath() {
        let engine = FakeEngine()
        let service = makeService(engine: engine)

        service.shutdown()

        #expect(engine.didShutDown)
    }

    @Test("Switching output rebuilds the mixer")
    func switchingOutputReappliesGains() {
        let catalog = FakeCatalog()
        let engine = FakeEngine()
        let outputs = FakeOutputs()
        outputs.outputs = [
            AudioOutput(id: "speakers", name: "Speakers"),
            AudioOutput(id: "headphones", name: "Headphones"),
        ]
        catalog.applications = [app("com.spotify.client")]
        let service = makeService(catalog: catalog, engine: engine, outputs: outputs)
        service.refresh()

        service.selectOutput(outputs.outputs[1])

        #expect(outputs.selected?.id == "headphones")
        #expect(engine.applied.count >= 2)
    }

    @Test("Playing apps sort above idle ones, then alphabetically")
    func rowsAreOrderedForScanning() {
        let catalog = FakeCatalog()
        catalog.applications = [
            app("com.zed", name: "Zed"),
            app("com.arc", name: "Arc", playing: false),
            app("com.music", name: "Music"),
        ]
        let service = makeService(catalog: catalog)
        service.showIdleApps = true

        let names = service.refresh().rows.map(\.application.name)

        #expect(names == ["Music", "Zed", "Arc"])
    }

    @Test("The snapshot carries the output devices and the current one")
    func snapshotDescribesTheOutputs() {
        let outputs = FakeOutputs()
        outputs.outputs = [
            AudioOutput(id: "speakers", name: "Speakers"),
            AudioOutput(id: "headphones", name: "Headphones"),
        ]
        outputs.selected = outputs.outputs[1]

        let snapshot = makeService(outputs: outputs).refresh()

        #expect(snapshot.outputs == outputs.outputs)
        #expect(snapshot.currentOutput?.id == "headphones")
    }

    /// A tap that will not start is invisible otherwise: the render callback runs
    /// and every buffer is zeros, so the reason has to reach the user.
    @Test("An engine that cannot start says so in the snapshot")
    func engineFailureReachesTheUI() {
        let engine = FakeEngine()
        engine.failure = "Could not create an audio tap."
        let service = makeService(engine: engine)

        #expect(service.refresh().failure == "Could not create an audio tap.")
    }

    @Test("A meter falls back towards zero instead of snapping")
    func metersDecayRatherThanDrop() {
        let catalog = FakeCatalog()
        let engine = FakeEngine()
        catalog.applications = [app("com.spotify.client")]
        let service = makeService(catalog: catalog, engine: engine)
        service.refresh()
        let spotify = AudioAppID.bundle("com.spotify.client")

        engine.peaks = [spotify: 1]
        #expect(service.levels()[spotify] == 1)

        // Silence from here: the bar has to come down over several frames.
        engine.peaks = [:]
        let first = service.levels()[spotify] ?? 0
        let second = service.levels()[spotify] ?? 0

        #expect(first > 0 && first < 1)
        #expect(second < first)
    }

    @Test("An app that stops playing has no meter to read")
    func idleAppsAreNotMetered() {
        let catalog = FakeCatalog()
        let engine = FakeEngine()
        catalog.applications = [app("com.spotify.client", playing: false)]
        let service = makeService(catalog: catalog, engine: engine)
        service.refresh()

        engine.peaks = [.bundle("com.spotify.client"): 1]

        #expect(service.levels().isEmpty)
    }
}
