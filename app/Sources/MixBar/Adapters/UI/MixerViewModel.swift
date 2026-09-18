import AppKit
import Combine
import Foundation

/// Driving adapter: owns the timers, so the core need not know when to poll.
@MainActor
final class MixerViewModel: ObservableObject {
    @Published private(set) var snapshot = MixerSnapshot()
    @Published private(set) var levels: [AudioAppID: Float] = [:]

    // Published, not forwarding: as pass-throughs the view never learned they
    // changed, so switching layout re-rendered nothing.
    @Published var showIdleApps: Bool = false {
        didSet {
            guard showIdleApps != mixer.showIdleApps else { return }
            mixer.showIdleApps = showIdleApps
            reload()
        }
    }

    @Published var layout: MixerLayout = .comfortable {
        didSet {
            guard layout != mixer.layout else { return }
            mixer.layout = layout
            reload()
        }
    }

    private let mixer: MixerControlling
    private var pollTimer: Timer?
    private var meterTimer: Timer?

    init(mixer: MixerControlling) {
        self.mixer = mixer
        DebugLog.write { "viewModel init \(ObjectIdentifier(self))" }
        showIdleApps = mixer.showIdleApps
        layout = mixer.layout
        reload()

        // .common: an open popover puts the run loop into event tracking,
        // where a default-mode timer stops firing and the list freezes.
        let timer = Timer(timeInterval: 1.5, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.reload() }
        }
        RunLoop.main.add(timer, forMode: .common)
        pollTimer = timer
    }

    deinit {
        DebugLog.write { "viewModel DEINIT \(ObjectIdentifier(self))" }
        pollTimer?.invalidate()
        meterTimer?.invalidate()
    }

    func setVolume(_ value: Float, for id: AudioAppID) {
        mixer.setVolume(Volume(value), for: id)
        reload()
    }

    func toggleMute(for id: AudioAppID) {
        mixer.toggleMute(for: id)
        reload()
    }

    func resetAll() {
        mixer.resetAll()
        reload()
    }

    func selectOutput(_ output: AudioOutput) {
        mixer.selectOutput(output)
        reload()
    }

    /// Meters run only while the popover is open.
    func startMetering() {
        guard meterTimer == nil else { return }
        let timer = Timer(timeInterval: 1.0 / 15, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.levels = self.mixer.levels()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        meterTimer = timer
    }

    func stopMetering() {
        meterTimer?.invalidate()
        meterTimer = nil
        levels = [:]
    }

    func shutdown() {
        stopMetering()
        pollTimer?.invalidate()
        pollTimer = nil
        mixer.shutdown()
    }

    /// Taps are gated by `kTCCServiceAudioCapture`, which System Settings shows
    /// as `Privacy_AudioCapture`, and it is not Microphone: a different permission.
    func openPrivacySettings() {
        let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AudioCapture")
        if let url { NSWorkspace.shared.open(url) }
    }

    func icon(for application: AudioApplication) -> NSImage? {
        NSRunningApplication(processIdentifier: application.processIdentifier)?.icon
    }

    private func reload() {
        snapshot = mixer.refresh()
        DebugLog.write { [snapshot] in
            let rows = snapshot.rows
                .map { "\($0.application.name) [\($0.application.bundleID ?? "?")]" }
                .joined(separator: ", ")
            return "rows: \(rows.isEmpty ? "(none)" : rows)"
        }
    }
}
