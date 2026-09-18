import CoreAudio
import Foundation

/// A hand-built `AudioBufferList`, because the render thread's contract is raw
/// buffers and a test has to speak the same thing to reach it at all.
final class BufferList {
    let list: UnsafeMutableAudioBufferListPointer

    private var storage: [UnsafeMutablePointer<Float>] = []

    /// - Parameter channels: channels *per buffer*. Devices present stereo
    ///   either as one buffer of two channels or as two buffers of one.
    init(_ buffers: [[Float]], channels: UInt32) {
        list = AudioBufferList.allocate(maximumBuffers: buffers.count)
        for (index, samples) in buffers.enumerated() {
            let memory = UnsafeMutablePointer<Float>.allocate(capacity: samples.count)
            memory.initialize(from: samples, count: samples.count)
            storage.append(memory)
            list[index] = AudioBuffer(
                mNumberChannels: channels,
                mDataByteSize: UInt32(samples.count * MemoryLayout<Float>.size),
                mData: UnsafeMutableRawPointer(memory))
        }
    }

    deinit {
        for pointer in storage { pointer.deallocate() }
        free(list.unsafeMutablePointer)
    }

    var pointer: UnsafeMutablePointer<AudioBufferList> { list.unsafeMutablePointer }

    func samples(_ index: Int) -> [Float] {
        storage.isEmpty ? [] : Array(
            UnsafeBufferPointer(
                start: storage[index],
                count: Int(list[index].mDataByteSize) / MemoryLayout<Float>.size))
    }
}

/// Interleaved stereo silence, `frames` long, ready to be rendered into.
func silentStereo(frames: Int) -> BufferList {
    BufferList([Array(repeating: 0, count: frames * 2)], channels: 2)
}
