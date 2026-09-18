import AudioToolbox
import CoreAudio
import Foundation

// The render thread. Nothing here may allocate, lock or touch a Swift
// reference: a retain is a priority inversion and an audible glitch.

/// Hand-allocated, so the IO block never touches Swift reference counting.
struct RealtimeState {
    static let maxTaps = 32

    let gain: UnsafeMutablePointer<Float>
    let peak: UnsafeMutablePointer<Float>
    let count: UnsafeMutablePointer<Int32>

    static func allocate() -> RealtimeState {
        let gain = UnsafeMutablePointer<Float>.allocate(capacity: maxTaps)
        let peak = UnsafeMutablePointer<Float>.allocate(capacity: maxTaps)
        let count = UnsafeMutablePointer<Int32>.allocate(capacity: 1)
        gain.initialize(repeating: 1, count: maxTaps)
        peak.initialize(repeating: 0, count: maxTaps)
        count.initialize(to: 0)
        return RealtimeState(gain: gain, peak: peak, count: count)
    }

    func deallocate() {
        gain.deallocate()
        peak.deallocate()
        count.deallocate()
    }
}

/// Devices come in two layouts: one interleaved buffer of N channels, or N
/// buffers of one channel each.
private struct OutputLayout {
    let left: UnsafeMutablePointer<Float>
    let right: UnsafeMutablePointer<Float>?
    let channels: Int
    let isInterleaved: Bool
    let frames: Int

    init?(_ output: UnsafeMutableAudioBufferListPointer) {
        guard !output.isEmpty, let first = output[0].mData else { return nil }
        channels = Int(output[0].mNumberChannels)
        isInterleaved = output.count == 1 && output[0].mNumberChannels >= 2
        left = first.assumingMemoryBound(to: Float.self)
        right = isInterleaved
            ? nil
            : (output.count > 1 ? output[1].mData?.assumingMemoryBound(to: Float.self) : nil)
        frames = isInterleaved
            ? Int(output[0].mDataByteSize) / (MemoryLayout<Float>.size * max(channels, 1))
            : Int(output[0].mDataByteSize) / MemoryLayout<Float>.size
    }
}

func renderMix(
    input inInputData: UnsafePointer<AudioBufferList>,
    output outOutputData: UnsafeMutablePointer<AudioBufferList>,
    state rt: RealtimeState
) {
    let input = UnsafeMutableAudioBufferListPointer(UnsafeMutablePointer(mutating: inInputData))
    let output = UnsafeMutableAudioBufferListPointer(outOutputData)

    // The HAL sums other IOProcs with ours, so clearing here silences only us.
    for buffer in output {
        if let data = buffer.mData { memset(data, 0, Int(buffer.mDataByteSize)) }
    }

    guard let layout = OutputLayout(output) else { return }

    let active = min(Int(rt.count.pointee), input.count)
    for index in 0..<active {
        let gain = rt.gain[index]
        // Muted: we hold the tap, so the app is already silent at source.
        if gain == 0 { continue }
        guard let data = input[index].mData else { continue }

        // Tap format is interleaved stereo Float32: 8 bytes per frame.
        let frames = min(Int(input[index].mDataByteSize) / 8, layout.frames)
        let peak = mixTap(
            source: data.assumingMemoryBound(to: Float.self),
            frames: frames,
            gain: gain,
            into: layout)
        if peak > rt.peak[index] { rt.peak[index] = peak }
    }
}

private func mixTap(
    source: UnsafeMutablePointer<Float>,
    frames: Int,
    gain: Float,
    into layout: OutputLayout
) -> Float {
    var peak: Float = 0
    for frame in 0..<frames {
        let l = source[frame * 2] * gain
        let r = source[frame * 2 + 1] * gain
        if layout.isInterleaved {
            layout.left[frame * layout.channels] += l
            if layout.channels > 1 { layout.left[frame * layout.channels + 1] += r }
        } else {
            layout.left[frame] += l
            layout.right?[frame] += r
        }
        let magnitude = max(abs(l), abs(r))
        if magnitude > peak { peak = magnitude }
    }
    return peak
}
