import AppKit
import Combine
import Foundation
import ServiceManagement

/// Driving adapter: owns the timers, so the core need not know when to poll.
@MainActor
final class MixerViewModel: ObservableObject {
    @Published private(set) var snapshot = MixerSnapshot()
    @Published private(set) var levels: [AudioAppID: Float] = [:]

    // Published, not forwarded: as pass-throughs the view never re-rendered.
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

    @Published private(set) var opensAtLogin = false

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

        mixer.observeChanges { [weak self] in
            Task { @MainActor in self?.reload() }
        }
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

    /// Read from the system, never stored, so it matches the Login Items pane.
    func refreshOpensAtLogin() {
        opensAtLogin = SMAppService.mainApp.status == .enabled
    }

    func toggleOpensAtLogin() {
        let service = SMAppService.mainApp
        do {
            if service.status == .enabled {
                try service.unregister()
            } else {
                try service.register()
            }
        } catch {
            DebugLog.write { "login item: \(error)" }
        }
        if service.status == .requiresApproval {
            SMAppService.openSystemSettingsLoginItems()
        }
        refreshOpensAtLogin()
    }

    /// Audio capture, not Microphone: a different permission.
    func openPrivacySettings() {
        open("x-apple.systempreferences:com.apple.preference.security?Privacy_AudioCapture")
    }

    /// A page, not a request: the app makes no network calls.
    func checkForUpdates() {
        open("https://github.com/quentinved/MixBar/releases/latest")
    }

    func reportBug() {
        open("https://github.com/quentinved/MixBar/issues/new?template=bug_report.yml")
    }

    /// The version is the detail bug reports leave out.
    func emailDeveloper() {
        let subject = "MixBar \(version) bug report"
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "MixBar"
        open("mailto:contact@quentinvedrenne.com?subject=\(subject)")
    }

    let version = Bundle.main
        .object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown"

    private func open(_ string: String) {
        guard let url = URL(string: string) else { return }
        NSWorkspace.shared.open(url)
    }

    /// Falls back to the bundle for rows whose process is gone, as under --demo.
    func icon(for application: AudioApplication) -> NSImage? {
        if let running = NSRunningApplication(
            processIdentifier: application.processIdentifier)?.icon {
            return running
        }
        guard let bundleID = application.bundleID,
              let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)
        else { return nil }
        let icon = NSWorkspace.shared.icon(forFile: url.path)
        // The default 32pt image scales up into mush on a Retina screen.
        icon.size = NSSize(width: 128, height: 128)
        return icon
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
