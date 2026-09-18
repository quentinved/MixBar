import AudioToolbox
import CoreAudio
import Foundation

/// Answers one question: if a single aggregate device carries several taps,
/// do the input buffers arrive in tap-list order, and how are channels grouped?
///
/// The whole mixer design depends on the answer. Play a different amplitude in
/// each process and the per-buffer peaks reveal the mapping.
enum Diagnose {
    static func run(pids: [pid_t]) throws {
        let system = AudioHardwareSystem.shared
        var taps: [AudioHardwareTap] = []
        var tapEntries: [[String: Any]] = []

        for pid in pids {
            guard let process = try system.process(for: pid) else {
                throw TapError.noSuchProcess(pid)
            }
            let description = CATapDescription(stereoMixdownOfProcesses: [process.id])
            description.name = "Diag tap \(pid)"
            description.isPrivate = true
            description.muteBehavior = .mutedWhenTapped
            guard let tap = try system.makeProcessTap(description: description) else {
                throw TapError.tapNotCreated
            }
            taps.append(tap)
            let format = try tap.format
            print("tap pid \(pid): uid=\(try tap.uid)")
            print("  format: \(format.mChannelsPerFrame)ch @ \(format.mSampleRate)Hz "
                + "flags=0x\(String(format.mFormatFlags, radix: 16)) "
                + "bytesPerFrame=\(format.mBytesPerFrame)")
            tapEntries.append([
                kAudioSubTapUIDKey: try tap.uid,
                kAudioSubTapDriftCompensationKey: true,
            ])
        }

        guard let output = try system.defaultOutputDevice else { throw TapError.noDefaultOutput }
        let outputUID = try output.uid

        let composition: [String: Any] = [
            kAudioAggregateDeviceNameKey: "SoundsManager Diag",
            kAudioAggregateDeviceUIDKey: UUID().uuidString,
            kAudioAggregateDeviceMainSubDeviceKey: outputUID,
            kAudioAggregateDeviceIsPrivateKey: true,
            kAudioAggregateDeviceIsStackedKey: false,
            kAudioAggregateDeviceTapAutoStartKey: true,
            kAudioAggregateDeviceSubDeviceListKey: [[kAudioSubDeviceUIDKey: outputUID]],
            kAudioAggregateDeviceTapListKey: tapEntries,
        ]
        guard let aggregate = try system.makeAggregateDevice(description: composition) else {
            throw TapError.aggregateNotCreated
        }
        defer {
            try? system.destroyAggregateDevice(aggregate)
            for tap in taps { try? system.destroyProcessTap(tap) }
        }

        print("\ninput stream configuration:")
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreamConfiguration,
            mScope: kAudioObjectPropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain)
        var size: UInt32 = 0
        AudioObjectGetPropertyDataSize(aggregate.id, &address, 0, nil, &size)
        let raw = UnsafeMutableRawPointer.allocate(
            byteCount: Int(size), alignment: MemoryLayout<AudioBufferList>.alignment)
        defer { raw.deallocate() }
        AudioObjectGetPropertyData(aggregate.id, &address, 0, nil, &size, raw)
        let list = UnsafeMutableAudioBufferListPointer(
            raw.assumingMemoryBound(to: AudioBufferList.self))
        for (index, buffer) in list.enumerated() {
            print("  buffer[\(index)]: \(buffer.mNumberChannels)ch")
        }

        // Per-buffer peaks, so different amplitudes per app expose the ordering.
        let count = list.count
        let peaks = UnsafeMutablePointer<Float>.allocate(capacity: max(count, 1))
        peaks.initialize(repeating: 0, count: max(count, 1))
        defer { peaks.deallocate() }

        var procID: AudioDeviceIOProcID?
        let status = AudioDeviceCreateIOProcIDWithBlock(&procID, aggregate.id, nil) {
            _, inInputData, _, outOutputData, _ in
            let input = UnsafeMutableAudioBufferListPointer(
                UnsafeMutablePointer(mutating: inInputData))
            let output = UnsafeMutableAudioBufferListPointer(outOutputData)
            for buffer in output {
                if let data = buffer.mData { memset(data, 0, Int(buffer.mDataByteSize)) }
            }
            for index in 0..<min(input.count, count) {
                guard let data = input[index].mData else { continue }
                let samples = Int(input[index].mDataByteSize) / MemoryLayout<Float>.size
                let pointer = data.assumingMemoryBound(to: Float.self)
                var peak: Float = 0
                for sample in 0..<samples {
                    let magnitude = abs(pointer[sample])
                    if magnitude > peak { peak = magnitude }
                }
                if peak > peaks[index] { peaks[index] = peak }
            }
        }
        guard status == noErr, let procID else { throw AudioHardwareError(status) }
        try aggregate.start(IOProcID: procID)
        Thread.sleep(forTimeInterval: 4)
        try? aggregate.stop(IOProcID: procID)
        AudioDeviceDestroyIOProcID(aggregate.id, procID)

        print("\npeak per input buffer over 4s:")
        for index in 0..<count {
            print(String(format: "  buffer[%d] peak %.4f", index, peaks[index]))
        }
    }
}
