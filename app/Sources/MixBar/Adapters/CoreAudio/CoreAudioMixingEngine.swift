import CoreAudio
import Foundation

/// Per-app gain: tap the app, mute it, re-render through one aggregate device.
final class CoreAudioMixingEngine: AudioMixingEngine {
    private let system = AudioHardwareSystem.shared
    private let registry: ProcessRegistry

    /// Two, so the next graph is primed while the current one plays.
    private let buffers: [RealtimeState]

    /// coreaudiod IPC: ~1.8s, and blocks on the first-run permission prompt.
    private let work = DispatchQueue(label: "com.quentinved.MixBar.engine")
    private var device: MixingDevice?

    private let state = NSLock()
    private var routed: [AudioAppID] = []
    private var tapped: [AudioAppID: Set<AudioObjectID>] = [:]
    private var outputUID: String?
    private var active: RealtimeState
    private var desiredGains: [AudioAppID: Float] = [:]
    private var desiredPlaying: Set<AudioAppID> = []
    private var requestedRendering = false
    private var rebuildScheduled = false
    private var storedFailure: String?

    var failure: String? { withState { storedFailure } }

    init(registry: ProcessRegistry) {
        self.registry = registry
        let first = RealtimeState.allocate()
        buffers = [first, RealtimeState.allocate()]
        active = first
    }

    deinit {
        device?.destroy()
        buffers.forEach { $0.deallocate() }
    }

    private func withState<T>(_ body: () -> T) -> T {
        state.lock()
        defer { state.unlock() }
        return body()
    }

    func apply(gains: [AudioAppID: Float], playing: Set<AudioAppID>) {
        let wanted = Self.routable(gains)
        let output = (try? system.defaultOutputDevice).flatMap { try? $0.uid }
        let processes = Dictionary(uniqueKeysWithValues: wanted.map {
            ($0, Set(registry.objectIDs(for: $0)))
        })

        let action = plan(
            wanted: wanted, gains: gains, playing: playing,
            output: output, processes: processes)
        switch action {
        case .nothing:
            return

        case .adjusted(let renderingChanged):
            DebugLog.write { "gain update: \(gains.map { "\($0.raw)=\($1)" }.sorted())" }
            if renderingChanged { work.async { [weak self] in self?.syncRendering() } }

        case .rebuild(let previous):
            DebugLog.write {
                "rebuilding: wanted=\(wanted.map(\.raw).joined(separator: ",")) "
                    + "routed=\(previous.map(\.raw).joined(separator: ","))"
            }
            work.async { [weak self] in self?.performRebuild() }
        }
    }

    func shutdown() {
        work.sync {
            device?.destroy()
            device = nil
            withState {
                routed = []
                tapped = [:]
                outputUID = nil
            }
        }
    }

    func takePeak(for id: AudioAppID) -> Float {
        guard let (rt, index) = withState({ routed.firstIndex(of: id).map { (active, $0) } })
        else { return 0 }
        let value = rt.peak[index]
        rt.peak[index] = 0
        return value
    }

    private enum Action {
        case nothing
        case adjusted(renderingChanged: Bool)
        case rebuild(previous: [AudioAppID])
    }

    private func plan(
        wanted: [AudioAppID],
        gains: [AudioAppID: Float],
        playing: Set<AudioAppID>,
        output: String?,
        processes: [AudioAppID: Set<AudioObjectID>]
    ) -> Action {
        withState { () -> Action in
            desiredGains = gains
            desiredPlaying = playing
            guard !wanted.isEmpty || !routed.isEmpty else { return .nothing }

            // A volume change is a few word writes; a rebuild interrupts audio.
            if wanted == routed, output == outputUID,
               !Self.hasUntappedProcesses(processes, tapped: tapped) {
                for (index, id) in routed.enumerated() {
                    active.gain[index] = gains[id] ?? 1
                }
                let rendering = !playing.isDisjoint(with: routed)
                defer { requestedRendering = rendering }
                return .adjusted(renderingChanged: rendering != requestedRendering)
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

    /// A process that joined after the tap was built plays around it, unmuted.
    static func hasUntappedProcesses(
        _ current: [AudioAppID: Set<AudioObjectID>],
        tapped: [AudioAppID: Set<AudioObjectID>]
    ) -> Bool {
        current.contains { id, processes in !processes.isSubset(of: tapped[id] ?? []) }
    }

    private func performRebuild() {
        let wanted = withState { Self.routable(desiredGains) }

        let previous = device
        var next: MixingDevice?
        if !wanted.isEmpty {
            do {
                next = try MixingDevice.build(apps: wanted, registry: registry, rt: spareBuffer)
                withState { storedFailure = nil }
            } catch {
                withState { storedFailure = "\(error)" }
            }
        }

        publish(next)
        device = next
        // Start before stopping the old: a doubled buffer beats a gap at full volume.
        syncRendering()
        previous?.destroy()
        DebugLog.write { "built \(next?.apps.count ?? 0) tap(s): \(wanted.map(\.raw))" }
    }

    private var spareBuffer: RealtimeState {
        device?.rt.gain == buffers[0].gain ? buffers[1] : buffers[0]
    }

    /// Primes from the latest gains: the slider kept moving during the build.
    private func publish(_ next: MixingDevice?) {
        withState {
            // Cleared only now, or a refresh during the build queues another.
            rebuildScheduled = false
            routed = next?.apps ?? []
            tapped = next?.processes ?? [:]
            outputUID = next?.outputUID
            requestedRendering = !desiredPlaying.isDisjoint(with: routed)
            guard let next else { return }

            active = next.rt
            for (index, id) in routed.enumerated() {
                active.gain[index] = desiredGains[id] ?? 1
                active.peak[index] = 0
            }
            active.count.pointee = Int32(routed.count)
        }
    }

    private func syncRendering() {
        let rendering = withState { requestedRendering }
        guard let device, device.isRendering != rendering else { return }
        do {
            try device.setRendering(rendering)
            DebugLog.write { rendering ? "rendering started" : "rendering paused" }
        } catch {
            withState { storedFailure = "\(error)" }
        }
    }
}
