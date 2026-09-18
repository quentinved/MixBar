import Foundation
import Testing
@testable import MixBar

/// The IOProc's arithmetic. It runs on the render thread in the real app, but it
/// is a free function over pointers, so it tests like any other pure function:
/// no device, no tap, no permission.
@Suite("Render thread")
struct RealtimeMixerTests {
    private func render(
        taps: [[Float]],
        gains: [Float],
        into output: BufferList
    ) -> RealtimeState {
        let state = RealtimeState.allocate()
        for (index, gain) in gains.enumerated() { state.gain[index] = gain }
        state.count.pointee = Int32(taps.count)

        let input = BufferList(taps, channels: 2)
        renderMix(input: input.pointer, output: output.pointer, state: state)
        return state
    }

    @Test("Gain scales both channels of a tap")
    func gainScalesEachChannel() {
        let output = silentStereo(frames: 2)
        // Two frames, interleaved: L R L R.
        let state = render(taps: [[1, 0.5, -1, -0.5]], gains: [0.5], into: output)
        defer { state.deallocate() }

        #expect(output.samples(0) == [0.5, 0.25, -0.5, -0.25])
    }

    @Test("Taps are summed together")
    func tapsAreMixed() {
        let output = silentStereo(frames: 1)
        let state = render(taps: [[0.25, 0.25], [0.5, 0.5]], gains: [1, 1], into: output)
        defer { state.deallocate() }

        #expect(output.samples(0) == [0.75, 0.75])
    }

    /// A gain of zero must cost nothing: we hold the tap, so the app is already
    /// silent at the source and there is no reason to touch its samples.
    @Test("A muted tap contributes nothing")
    func mutedTapIsSkipped() {
        let output = silentStereo(frames: 2)
        let state = render(taps: [[1, 1, 1, 1]], gains: [0], into: output)
        defer { state.deallocate() }

        #expect(output.samples(0).allSatisfy { $0 == 0 })
        #expect(state.peak[0] == 0)
    }

    /// The HAL sums every IOProc's output, so anything left in the buffer from
    /// another client would be mixed in on top of us.
    @Test("The output buffer is cleared before anything is written")
    func staleOutputIsCleared() {
        let output = BufferList([[9, 9, 9, 9]], channels: 2)
        let state = render(taps: [[0, 0, 0, 0]], gains: [0], into: output)
        defer { state.deallocate() }

        #expect(output.samples(0) == [0, 0, 0, 0])
    }

    /// Devices come in two layouts, and the planar one is the easy thing to get
    /// wrong: left and right have to be split across two separate buffers.
    @Test("Planar output splits the stereo tap across its two buffers")
    func planarOutputIsDeinterleaved() {
        let output = BufferList([[0], [0]], channels: 1)
        let state = render(taps: [[1, 0.25]], gains: [1], into: output)
        defer { state.deallocate() }

        #expect(output.samples(0) == [1])
        #expect(output.samples(1) == [0.25])
    }

    @Test("Peak is measured after gain, so a meter can never exceed its fill")
    func peakIsPostGain() {
        let output = silentStereo(frames: 2)
        let state = render(taps: [[1, 1, -0.5, -0.5]], gains: [0.5], into: output)
        defer { state.deallocate() }

        #expect(state.peak[0] == 0.5)
    }

    /// A tap shorter than the output buffer is normal, and reading past it would
    /// be an out-of-bounds read on the render thread.
    @Test("A tap shorter than the output is not read past its end")
    func shortTapDoesNotOverrun() {
        let output = silentStereo(frames: 4)
        let state = render(taps: [[1, 1]], gains: [1], into: output)
        defer { state.deallocate() }

        #expect(output.samples(0) == [1, 1, 0, 0, 0, 0, 0, 0])
    }

    /// `count` is written from the engine's queue while the render thread reads
    /// it, so it is the one value that bounds the loop.
    @Test("Only the taps the engine has published are read")
    func inactiveTapsAreIgnored() {
        let state = RealtimeState.allocate()
        defer { state.deallocate() }
        state.gain[0] = 1
        state.gain[1] = 1
        state.count.pointee = 1

        let output = silentStereo(frames: 1)
        let input = BufferList([[0.25, 0.25], [0.5, 0.5]], channels: 2)
        renderMix(input: input.pointer, output: output.pointer, state: state)

        #expect(output.samples(0) == [0.25, 0.25])
    }
}
