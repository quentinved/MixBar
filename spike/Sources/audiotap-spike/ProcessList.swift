import CoreAudio
import Foundation

/// A process that Core Audio knows about, as shown by `audiotap-spike list`.
struct AudioProcessInfo {
    let objectID: AudioObjectID
    let pid: pid_t
    let bundleID: String
    let isPlaying: Bool

    /// Best-effort display name. Core Audio only gives us a bundle ID, so fall
    /// back to asking the process table for an executable name.
    var displayName: String {
        if let last = bundleID.split(separator: ".").last, !last.isEmpty {
            return String(last)
        }
        return "pid \(pid)"
    }
}

enum ProcessList {
    static func all() throws -> [AudioProcessInfo] {
        try AudioHardwareSystem.shared.processes.compactMap { process in
            // Any of these can fail for a process that exits mid-enumeration.
            guard let pid = try? process.pid else { return nil }
            let bundleID = (try? process.bundleID) ?? nil
            let playing = (try? process.isRunningOutput) ?? false
            return AudioProcessInfo(
                objectID: process.id,
                pid: pid,
                bundleID: bundleID ?? "",
                isPlaying: playing
            )
        }
    }
}
