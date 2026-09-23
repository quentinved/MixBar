import Testing
@testable import MixBar

/// How the mix follows apps as they pause, quit and change underneath it.
@Suite("Mixer lifecycle")
struct MixerLifecycleTests {
    private func makeService(
        catalog: FakeCatalog, engine: FakeEngine = FakeEngine()
    ) -> MixerService {
        MixerService(
            catalog: catalog, engine: engine, outputs: FakeOutputs(), store: FakeStore())
    }

    /// Dropping a paused app from the mix rebuilt the whole mixer, and every
    /// other adjusted app played at full volume until the rebuild finished.
    @Test("Pausing an adjusted app keeps it in the mixer, marked as not playing")
    func pausingKeepsTheAppRouted() {
        let catalog = FakeCatalog()
        let engine = FakeEngine()
        let spotify = AudioAppID.bundle("com.spotify.client")
        let discord = AudioAppID.bundle("com.hnc.Discord")
        catalog.applications = [app(spotify.raw), app(discord.raw)]
        let service = makeService(catalog: catalog, engine: engine)
        service.refresh()
        service.setVolume(Volume(0.3), for: spotify)
        service.setVolume(Volume(0.2), for: discord)

        catalog.applications = [app(spotify.raw, playing: false), app(discord.raw)]
        service.refresh()

        #expect(engine.latest == [spotify: 0.3, discord: 0.2])
        #expect(engine.playing == [discord])
    }

    @Test("An app that quits leaves the mixer")
    func quittingUnroutes() {
        let catalog = FakeCatalog()
        let engine = FakeEngine()
        catalog.applications = [app("com.spotify.client")]
        let service = makeService(catalog: catalog, engine: engine)
        service.refresh()
        service.setVolume(Volume(0.3), for: .bundle("com.spotify.client"))

        catalog.applications = []
        service.refresh()

        #expect(engine.latest.isEmpty)
        #expect(engine.playing.isEmpty)
    }

    @Test("A change in the audio system reaches the UI without waiting for a poll")
    func catalogChangesReachTheUI() {
        let catalog = FakeCatalog()
        let service = makeService(catalog: catalog)
        var notified = 0
        service.observeChanges { notified += 1 }

        catalog.onChange?()

        #expect(notified == 1)
    }
}
