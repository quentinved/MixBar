import AudioToolbox
import CoreAudio
import Foundation

/// Values shared with the real-time render thread.
///
/// These live in manually allocated memory rather than as properties on a class
/// so the IO block never touches Swift reference counting. Reads and writes are
/// plain, non-atomic loads and stores of single words: torn values are possible
/// in theory but harmless here (a meter flickers, a gain change lands one cycle
/// late). Anything that must not tear belongs in an atomic.
private struct RealtimeState {
    let gain: UnsafeMutablePointer<Float>
    let peak: UnsafeMutablePointer<Float>
    let mismatch: UnsafeMutablePointer<UInt32>

    static func allocate() -> RealtimeState {
        let g = UnsafeMutablePointer<Float>.allocate(capacity: 1)
        let p = UnsafeMutablePointer<Float>.allocate(capacity: 1)
        let m = UnsafeMutablePointer<UInt32>.allocate(capacity: 1)
        g.initialize(to: 1); p.initialize(to: 0); m.initialize(to: 0)
        return RealtimeState(gain: g, peak: p, mismatch: m)
    }

    func deallocate() {
        gain.deallocate(); peak.deallocate(); mismatch.deallocate()
    }
}

enum TapError: Error, CustomStringConvertible {
    case noSuchProcess(pid_t)
    case tapNotCreated
    case aggregateNotCreated
    case noDefaultOutput

    var description: String {
        switch self {
        case .noSuchProcess(let pid):
            return "Core Audio has no process object for pid \(pid). The app must have opened an audio device at least once."
        case .tapNotCreated:
            return "AudioHardwareCreateProcessTap returned no tap."
        case .aggregateNotCreated:
            return "AudioHardwareCreateAggregateDevice returned no device."
        case .noDefaultOutput:
            return "No default output device."
        }
    }
}

/// Taps one process, mutes its direct output, and re-renders it through a
/// private aggregate device with a gain applied.
///
/// This is the whole per-app-volume mechanism in miniature: if this works, the
/// mixer is a matter of doing it N times and summing.
final class TapSession {
    private let system = AudioHardwareSystem.shared
    private let rt = RealtimeState.allocate()

    private var tap: AudioHardwareTap?
    private var aggregate: AudioHardwareAggregateDevice?
    private var ioProcID: AudioDeviceIOProcID?

    var gain: Float {
        get { rt.gain.pointee }
        set { rt.gain.pointee = newValue }
    }

    /// Peak sample seen since the last read, consumed destructively so the
    /// meter decays instead of latching at the loudest moment ever.
    func readPeak() -> Float {
        let value = rt.peak.pointee
        rt.peak.pointee = 0
        return value
    }

    var sawFormatMismatch: Bool { rt.mismatch.pointee != 0 }

    func start(pid: pid_t, gain: Float) throws {
        self.gain = gain

        guard let process = try system.process(for: pid) else {
            throw TapError.noSuchProcess(pid)
        }

        // A private tap does not appear in other apps' device lists.
        // .mutedWhenTapped is the important part: it silences the app's normal
        // path to the speakers only while we are reading, so we become the only
        // thing rendering its audio and our gain is the app's real volume.
        let description = CATapDescription(stereoMixdownOfProcesses: [process.id])
        description.name = "SoundsManager Spike Tap"
        description.isPrivate = true
        description.isExclusive = false
        description.muteBehavior = .mutedWhenTapped

        guard let tap = try system.makeProcessTap(description: description) else {
            throw TapError.tapNotCreated
        }
        self.tap = tap
        let tapUID = try tap.uid

        guard let output = try system.defaultOutputDevice else {
            throw TapError.noDefaultOutput
        }
        let outputUID = try output.uid

        // The aggregate pairs the real output device with the tap, so a single
        // IO cycle hands us the app's audio as input and the speakers as output.
        let composition: [String: Any] = [
            kAudioAggregateDeviceNameKey: "SoundsManager Spike",
            kAudioAggregateDeviceUIDKey: UUID().uuidString,
            kAudioAggregateDeviceMainSubDeviceKey: outputUID,
            kAudioAggregateDeviceIsPrivateKey: true,
            kAudioAggregateDeviceIsStackedKey: false,
            kAudioAggregateDeviceTapAutoStartKey: true,
            kAudioAggregateDeviceSubDeviceListKey: [
                [kAudioSubDeviceUIDKey: outputUID]
            ],
            kAudioAggregateDeviceTapListKey: [
                [
                    kAudioSubTapUIDKey: tapUID,
                    kAudioSubTapDriftCompensationKey: true,
                ]
            ],
        ]

        guard let aggregate = try system.makeAggregateDevice(description: composition) else {
            throw TapError.aggregateNotCreated
        }
        self.aggregate = aggregate

        // Capture the raw pointers, not self: the block must not retain or
        // release anything once it is running on the render thread.
        let rt = self.rt
        var procID: AudioDeviceIOProcID?
        let status = AudioDeviceCreateIOProcIDWithBlock(&procID, aggregate.id, nil) {
            _, inInputData, _, outOutputData, _ in
            let input = UnsafeMutableAudioBufferListPointer(
                UnsafeMutablePointer(mutating: inInputData))
            let output = UnsafeMutableAudioBufferListPointer(outOutputData)

            // Other IOProcs on this device are summed with ours by the HAL, so
            // silence here means silence from us, not from everyone.
            for buffer in output {
                if let data = buffer.mData {
                    memset(data, 0, Int(buffer.mDataByteSize))
                }
            }

            if input.count != output.count { rt.mismatch.pointee = 1 }

            let gain = rt.gain.pointee
            var peak: Float = 0
            let pairs = min(input.count, output.count)

            for index in 0..<pairs {
                guard let source = input[index].mData,
                      let destination = output[index].mData else { continue }
                let bytes = min(input[index].mDataByteSize, output[index].mDataByteSize)
                if input[index].mDataByteSize != output[index].mDataByteSize {
                    rt.mismatch.pointee = 1
                }
                let count = Int(bytes) / MemoryLayout<Float>.size
                let src = source.assumingMemoryBound(to: Float.self)
                let dst = destination.assumingMemoryBound(to: Float.self)
                for frame in 0..<count {
                    let value = src[frame] * gain
                    dst[frame] = value
                    let magnitude = abs(value)
                    if magnitude > peak { peak = magnitude }
                }
            }

            if peak > rt.peak.pointee { rt.peak.pointee = peak }
        }
        guard status == noErr, let procID else {
            throw AudioHardwareError(status)
        }
        self.ioProcID = procID

        try aggregate.start(IOProcID: procID)
    }

    func stop() {
        if let aggregate, let ioProcID {
            try? aggregate.stop(IOProcID: ioProcID)
            AudioDeviceDestroyIOProcID(aggregate.id, ioProcID)
        }
        // Order matters: the aggregate references the tap, so it goes first.
        if let aggregate { try? system.destroyAggregateDevice(aggregate) }
        if let tap { try? system.destroyProcessTap(tap) }
        aggregate = nil
        tap = nil
        ioProcID = nil
    }

    deinit {
        rt.deallocate()
    }
}
