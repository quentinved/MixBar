import AudioToolbox
import CoreAudio
import Foundation

/// One mixing graph: a tap per app, the aggregate joining them to the output,
/// and the IOProc. Built and destroyed whole, on the engine's work queue only.
final class MixingDevice {
    private(set) var apps: [AudioAppID] = []
    private(set) var processes: [AudioAppID: Set<AudioObjectID>] = [:]
    private(set) var outputUID = ""
    private(set) var isRendering = false
    let rt: RealtimeState

    private let system = AudioHardwareSystem.shared
    private var taps: [AudioHardwareTap] = []
    private var aggregate: AudioHardwareAggregateDevice?
    private var ioProcID: AudioDeviceIOProcID?
    private var tapEntries: [[String: Any]] = []

    private init(rt: RealtimeState) {
        self.rt = rt
    }

    /// Nil when none of the apps has a process left to tap.
    static func build(
        apps: [AudioAppID], registry: ProcessRegistry, rt: RealtimeState
    ) throws -> MixingDevice? {
        let device = MixingDevice(rt: rt)
        do {
            try device.makeTaps(for: apps, registry: registry)
            guard !device.apps.isEmpty else { return nil }
            try device.makeAggregateDevice()
            try device.makeIOProc()
            return device
        } catch {
            device.destroy()
            throw error
        }
    }

    /// Stopped while every routed app is paused: a running IOProc keeps the Mac awake.
    func setRendering(_ rendering: Bool) throws {
        guard rendering != isRendering, let aggregate, let ioProcID else { return }
        if rendering {
            try aggregate.start(IOProcID: ioProcID)
        } else {
            try aggregate.stop(IOProcID: ioProcID)
        }
        isRendering = rendering
    }

    func destroy() {
        if let aggregate, let ioProcID {
            if isRendering { try? aggregate.stop(IOProcID: ioProcID) }
            AudioDeviceDestroyIOProcID(aggregate.id, ioProcID)
        }
        // The aggregate references the taps, so it has to go first.
        if let aggregate { try? system.destroyAggregateDevice(aggregate) }
        for tap in taps { try? system.destroyProcessTap(tap) }
        taps = []
        aggregate = nil
        ioProcID = nil
        isRendering = false
    }

    private func makeTaps(for wanted: [AudioAppID], registry: ProcessRegistry) throws {
        for id in wanted {
            let objectIDs = registry.objectIDs(for: id)
            guard !objectIDs.isEmpty else { continue }

            // One tap for all of them, or a browser moves audio to the next.
            let description = CATapDescription(stereoMixdownOfProcesses: objectIDs)
            description.name = "MixBar"
            description.isPrivate = true
            // The app is silent while we hold the tap, so our gain is its volume.
            description.muteBehavior = .mutedWhenTapped

            guard let tap = try system.makeProcessTap(description: description) else {
                throw MixerEngineError.tapNotCreated
            }
            taps.append(tap)
            apps.append(id)
            processes[id] = Set(objectIDs)
            tapEntries.append([
                kAudioSubTapUIDKey: try tap.uid,
                kAudioSubTapDriftCompensationKey: true,
            ])
        }
    }

    private func makeAggregateDevice() throws {
        guard let output = try system.defaultOutputDevice else { throw MixerEngineError.noOutput }
        outputUID = try output.uid

        let composition: [String: Any] = [
            kAudioAggregateDeviceNameKey: "MixBar Mixer",
            kAudioAggregateDeviceUIDKey: UUID().uuidString,
            kAudioAggregateDeviceMainSubDeviceKey: outputUID,
            kAudioAggregateDeviceIsPrivateKey: true,
            kAudioAggregateDeviceIsStackedKey: false,
            kAudioAggregateDeviceTapAutoStartKey: true,
            kAudioAggregateDeviceSubDeviceListKey: [[kAudioSubDeviceUIDKey: outputUID]],
            kAudioAggregateDeviceTapListKey: tapEntries,
        ]
        guard let aggregate = try system.makeAggregateDevice(description: composition) else {
            throw MixerEngineError.aggregateNotCreated
        }
        self.aggregate = aggregate
    }

    private func makeIOProc() throws {
        guard let aggregate else { throw MixerEngineError.aggregateNotCreated }
        // Capture pointers, never self: the render thread must not retain.
        let rt = self.rt
        let render: AudioDeviceIOBlock = { _, input, _, output, _ in
            renderMix(input: input, output: output, state: rt)
        }

        var procID: AudioDeviceIOProcID?
        let status = AudioDeviceCreateIOProcIDWithBlock(&procID, aggregate.id, nil, render)
        guard status == noErr, let procID else { throw MixerEngineError.renderNotStarted(status) }
        ioProcID = procID
    }
}

enum MixerEngineError: Error, CustomStringConvertible {
    case tapNotCreated
    case aggregateNotCreated
    case noOutput

    /// AudioHardwareError only became constructible in the macOS 26 SDK, and
    /// this has to build on the Xcode 16 the README asks for.
    case renderNotStarted(OSStatus)

    var description: String {
        switch self {
        case .tapNotCreated: return "Could not create an audio tap."
        case .aggregateNotCreated: return "Could not create the mixing device."
        case .noOutput: return "No default output device."
        case .renderNotStarted(let status):
            return "Could not start the mixer (status \(status))."
        }
    }
}
