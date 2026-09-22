import Testing
@testable import MixBar

@Suite("Output devices")
struct AudioOutputTests {
    @Test("Devices are sectioned by kind, nearest thing first")
    func sectionsFollowKindOrder() {
        let sections = AudioOutput.sections(of: [
            AudioOutput(id: "blackhole", name: "BlackHole 2ch", kind: .virtual),
            AudioOutput(id: "airpods", name: "AirPods Pro", kind: .bluetooth),
            AudioOutput(id: "speakers", name: "MacBook Pro Speakers", kind: .builtIn),
        ])

        #expect(sections.map(\.kind) == [.builtIn, .bluetooth, .virtual])
    }

    @Test("A section keeps every device of its kind, in the given order")
    func sectionsKeepTheirDevices() {
        let sections = AudioOutput.sections(of: [
            AudioOutput(id: "scarlett", name: "Scarlett 2i2", kind: .external),
            AudioOutput(id: "speakers", name: "MacBook Pro Speakers", kind: .builtIn),
            AudioOutput(id: "dac", name: "USB DAC", kind: .external),
        ])

        #expect(sections.count == 2)
        #expect(sections.last?.outputs.map(\.name) == ["Scarlett 2i2", "USB DAC"])
    }

    @Test("Kinds nobody owns get no empty section")
    func emptyKindsAreDropped() {
        let sections = AudioOutput.sections(of: [
            AudioOutput(id: "speakers", name: "MacBook Pro Speakers", kind: .builtIn),
        ])

        #expect(sections.map(\.kind) == [.builtIn])
    }

    @Test("An unknown transport is described as an external device")
    func unknownTransportsAreExternal() {
        #expect(AudioOutput(id: "mystery", name: "Mystery Box").kind == .external)
    }
}
