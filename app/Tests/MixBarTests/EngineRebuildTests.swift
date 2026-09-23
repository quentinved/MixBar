import Testing
@testable import MixBar

/// When the engine must rebuild its taps although the same apps are routed. A
/// pure decision over process IDs, so it needs no device and no permission.
@Suite("Engine rebuilds")
struct EngineRebuildTests {
    private let arc = AudioAppID.bundle("company.thebrowser.Browser")

    @Test("A process that joins a routed app forces a rebuild")
    func newHelperForcesRebuild() {
        #expect(CoreAudioMixingEngine.hasUntappedProcesses(
            [arc: [10, 11]], tapped: [arc: [10]]))
    }

    @Test("A relaunched app, with new process IDs, forces a rebuild")
    func relaunchForcesRebuild() {
        #expect(CoreAudioMixingEngine.hasUntappedProcesses(
            [arc: [20]], tapped: [arc: [10]]))
    }

    @Test("A process that went away does not interrupt the audio")
    func departedHelperIsHarmless() {
        #expect(!CoreAudioMixingEngine.hasUntappedProcesses(
            [arc: [10]], tapped: [arc: [10, 11]]))
    }

    @Test("Unchanged processes leave the taps alone")
    func unchangedProcessesKeepTaps() {
        #expect(!CoreAudioMixingEngine.hasUntappedProcesses(
            [arc: [10, 11]], tapped: [arc: [11, 10]]))
    }
}
