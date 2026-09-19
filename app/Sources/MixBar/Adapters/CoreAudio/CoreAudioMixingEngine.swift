import AudioToolbox
import CoreAudio
import Foundation

/// Per-app gain: tap the app, mute it, re-render through one aggregate device.
final class CoreAudioMixingEngine: AudioMixingEngine {
    private let system = AudioHardwareSystem.shared
    private let registry: ProcessRegistry
    private let rt = RealtimeState.allocate()

    private var taps: [AudioHardwareTap] = []
    private var aggregate: AudioHardwareAggregateDevice?
    private var ioProcID: AudioDeviceIOProcID?

    /// coreaudiod IPC: ~1.8s, and blocks on the first-run permission prompt.
    private let work = DispatchQueue(label: "com.quentinved.MixBar.engine")

    private let state = NSLock()
    private var routed: [AudioAppID] = []
    private var outputUID: String?
    private var desiredGains: [AudioAppID: Float] = [:]
    private var rebuildScheduled = false
    private var storedFailure: String?

    var failure: String? { withState { storedFailure } }

    init(registry: ProcessRegistry) {
        self.registry = registry
    }

    deinit {
        teardown()
        rt.deallocate()
    }

    /// The only way to touch what `state` guards: no path can return holding it.
    private func withState<T>(_ body: () -> T) -> T {
        state.lock()
        defer { state.unlock() }
        return body()
    }

    // MARK: - AudioMixingEngine

    func apply(gains: [AudioAppID: Float]) {
        let wanted = Self.routable(gains)
        let output = (try? system.defaultOutputDevice).flatMap { try? $0.uid }

        switch plan(wanted: wanted, gains: gains, output: output) {
        case .nothing:
            return

        case .adjusted(let apps):
            DebugLog.write {
                let summary = apps.enumerated()
                    .map { "\($1.raw) gain=\(gains[$1] ?? 1) heard=\(self.rt.peak[$0])" }
                    .joined(separator: " | ")
                return "gain update: \(summary)"
            }

        case .rebuild(let previous):
            DebugLog.write {
                "rebuilding: wanted=\(wanted.map(\.raw).joined(separator: ",")) "
                    + "routed=\(previous.map(\.raw).joined(separator: ","))"
            }
            work.async { [weak self] in self?.performRebuild() }
        }
    }

    func shutdown() {
        work.sync { self.teardown() }
    }

    func takePeak(for id: AudioAppID) -> Float {
        guard let index = withState({ routed.firstIndex(of: id) }) else { return 0 }
        let value = rt.peak[index]
        rt.peak[index] = 0
        return value
    }

    // MARK: - Deciding what to do

    private enum Action {
        case nothing
        case adjusted([AudioAppID])
        case rebuild(previous: [AudioAppID])
    }

    /// Returns a decision rather than acting, so the queue hop happens unlocked.
    private func plan(
        wanted: [AudioAppID],
        gains: [AudioAppID: Float],
        output: String?
    ) -> Action {
        withState { () -> Action in
            desiredGains = gains
            guard !wanted.isEmpty || !routed.isEmpty else { return .nothing }

            // Rebuilding interrupts audio; a pure volume change is a few word writes.
            if wanted == routed, output == outputUID {
                for (index, id) in routed.enumerated() {
                    rt.gain[index] = gains[id] ?? 1
                }
                return .adjusted(routed)
            }

            guard !rebuildScheduled else { return .nothing }
            rebuildScheduled = true
            return .rebuild(previous: routed)
        }
    }

    /// A stable order: `plan` compares this against what is already routed.
    private static func routable(_ gains: [AudioAppID: Float]) -> [AudioAppID] {
        Array(gains.keys.sorted { $0.raw < $1.raw }.prefix(RealtimeState.maxTaps))
    }

    // MARK: - Core Audio

    private func performRebuild() {
        let gains = withState { () -> [AudioAppID: Float] in
            rebuildScheduled = false
            return desiredGains
        }

        teardown()
        let wanted = Self.routable(gains)
        guard !wanted.isEmpty else { return }

        do {
            try build(apps: wanted, gains: gains)
            withState { storedFailure = nil }
        } catch {
            withState { storedFailure = "\(error)" }
            teardown()
        }
    }

    private func build(apps: [AudioAppID], gains: [AudioAppID: Float]) throws {
        let (entries, accepted) = try makeTaps(for: apps)
        guard !entries.isEmpty else { return }

        let aggregate = try makeAggregateDevice(tapEntries: entries)
        self.aggregate = aggregate

        withState { routed = accepted }
        primeRealtimeState(accepted: accepted, gains: gains)

        try startRendering(on: aggregate)
        DebugLog.write {
            "built \(accepted.count) tap(s): \(accepted.map(\.raw).joined(separator: ", "))"
        }
    }

    private func makeTaps(
        for apps: [AudioAppID]
    ) throws -> (entries: [[String: Any]], accepted: [AudioAppID]) {
        var entries: [[String: Any]] = []
        var accepted: [AudioAppID] = []

        for id in apps {
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
            accepted.append(id)
            entries.append([
                kAudioSubTapUIDKey: try tap.uid,
                kAudioSubTapDriftCompensationKey: true,
            ])
        }
        return (entries, accepted)
    }

    private func makeAggregateDevice(
        tapEntries: [[String: Any]]
    ) throws -> AudioHardwareAggregateDevice {
        guard let output = try system.defaultOutputDevice else { throw MixerEngineError.noOutput }
        let uid = try output.uid
        withState { outputUID = uid }

        let composition: [String: Any] = [
            kAudioAggregateDeviceNameKey: "MixBar Mixer",
            kAudioAggregateDeviceUIDKey: UUID().uuidString,
            kAudioAggregateDeviceMainSubDeviceKey: uid,
            kAudioAggregateDeviceIsPrivateKey: true,
            kAudioAggregateDeviceIsStackedKey: false,
            kAudioAggregateDeviceTapAutoStartKey: true,
            kAudioAggregateDeviceSubDeviceListKey: [[kAudioSubDeviceUIDKey: uid]],
            kAudioAggregateDeviceTapListKey: tapEntries,
        ]
        guard let aggregate = try system.makeAggregateDevice(description: composition) else {
            throw MixerEngineError.aggregateNotCreated
        }
        return aggregate
    }

    private func primeRealtimeState(accepted: [AudioAppID], gains: [AudioAppID: Float]) {
        for (index, id) in accepted.enumerated() {
            rt.gain[index] = gains[id] ?? 1
            rt.peak[index] = 0
        }
        rt.count.pointee = Int32(accepted.count)
    }

    private func startRendering(on aggregate: AudioHardwareAggregateDevice) throws {
        // Capture pointers, never self: the render thread must not retain.
        let rt = self.rt
        let render: AudioDeviceIOBlock = { _, input, _, output, _ in
            renderMix(input: input, output: output, state: rt)
        }

        var procID: AudioDeviceIOProcID?
        let status = AudioDeviceCreateIOProcIDWithBlock(&procID, aggregate.id, nil, render)
        guard status == noErr, let procID else { throw MixerEngineError.renderNotStarted(status) }
        ioProcID = procID
        try aggregate.start(IOProcID: procID)
    }

    private func teardown() {
        if let aggregate, let ioProcID {
            try? aggregate.stop(IOProcID: ioProcID)
            AudioDeviceDestroyIOProcID(aggregate.id, ioProcID)
        }
        // The aggregate references the taps, so it has to go first.
        if let aggregate { try? system.destroyAggregateDevice(aggregate) }
        for tap in taps { try? system.destroyProcessTap(tap) }
        taps = []
        aggregate = nil
        ioProcID = nil
        rt.count.pointee = 0
        withState {
            routed = []
            outputUID = nil
        }
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
