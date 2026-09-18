import AppKit
import CoreAudio
import Foundation

/// Discovers audio processes and groups them into the apps a user recognises.
final class CoreAudioApplicationCatalog: AudioApplicationCatalog {
    private let registry: ProcessRegistry
    private let ownProcessIdentifier = ProcessInfo.processInfo.processIdentifier

    init(registry: ProcessRegistry) {
        self.registry = registry
    }

    private struct Entry {
        let objectID: AudioObjectID
        let bundleID: String
        let isPlaying: Bool
        let owner: NSRunningApplication?
        let ownerPID: pid_t
    }

    func currentApplications() -> [AudioApplication] {
        groupedByOwner().compactMap { key, entries in
            guard let first = entries.first else { return nil }

            // The tap spans the whole group, so the engine needs every process.
            registry.record(key, objectIDs: entries.map(\.objectID))

            return AudioApplication(
                id: key,
                name: first.owner?.localizedName ?? Self.name(fromBundleID: first.bundleID),
                bundleID: key.raw,
                processIdentifier: first.ownerPID,
                isPlaying: entries.contains { $0.isPlaying }
            )
        }
    }

    private func groupedByOwner() -> [AudioAppID: [Entry]] {
        guard let processes = try? AudioHardwareSystem.shared.processes else { return [:] }

        var groups: [AudioAppID: [Entry]] = [:]
        for process in processes {
            guard let entry = entry(for: process) else { continue }

            // Every helper lands on the owning app's row.
            let key = entry.owner?.bundleIdentifier.map(AudioAppID.bundle)
                ?? AudioAppID.bundle(entry.bundleID)
            groups[key, default: []].append(entry)
        }
        return groups
    }

    private func entry(for process: AudioHardwareProcess) -> Entry? {
        guard let pid = try? process.pid else { return nil }

        // Tapping ourselves would mute our output and feed the mix back in.
        guard pid != ownProcessIdentifier else { return nil }

        let bundleID = (try? process.bundleID) ?? ""
        guard !bundleID.isEmpty else { return nil }

        let isPlaying = (try? process.isRunningOutput) ?? false
        let owner = Self.owningApplication(of: pid)

        // The rest of the list is daemons holding a silent stream open.
        guard owner != nil || isPlaying else { return nil }

        return Entry(
            objectID: process.id,
            bundleID: bundleID,
            isPlaying: isPlaying,
            owner: owner?.app,
            ownerPID: owner?.pid ?? pid
        )
    }

    /// Browsers and Electron apps play from unnamed children: Netflix in Arc
    /// comes from `company.thebrowser.browser.helper`, not from Arc.
    private static func owningApplication(
        of pid: pid_t
    ) -> (app: NSRunningApplication, pid: pid_t)? {
        var current = pid
        // Bounded: a cycle must not hang a lookup that runs every refresh.
        for _ in 0..<6 {
            if let app = NSRunningApplication(processIdentifier: current),
               app.activationPolicy == .regular,
               app.localizedName != nil {
                return (app, current)
            }
            guard let parent = parentProcess(of: current), parent > 1 else { return nil }
            current = parent
        }
        return nil
    }

    private static func parentProcess(of pid: pid_t) -> pid_t? {
        var info = kinfo_proc()
        var size = MemoryLayout<kinfo_proc>.stride
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, pid]
        guard sysctl(&mib, 4, &info, &size, nil, 0) == 0, size > 0 else { return nil }
        return info.kp_eproc.e_ppid
    }

    private static func name(fromBundleID bundleID: String) -> String {
        guard let last = bundleID.split(separator: ".").last else { return bundleID }
        return String(last).replacingOccurrences(of: "-", with: " ").capitalized
    }
}
