import CoreAudio
import Foundation

/// Finds and removes leftover taps and aggregate devices.
///
/// A process killed with SIGKILL never runs its teardown, so whatever it
/// registered with coreaudiod can outlive it and stay in the audio path.
enum Cleanup {
    static func run(destroy: Bool) {
        let system = AudioHardwareSystem.shared

        let taps = (try? system.taps) ?? []
        print("taps visible to us: \(taps.count)")
        for tap in taps {
            let uid = (try? tap.uid) ?? "?"
            let name = (try? tap.description.name) ?? "?"
            print("  tap \(uid) name=\(name)")
            if destroy {
                do { try system.destroyProcessTap(tap); print("    destroyed") }
                catch { print("    could not destroy: \(error)") }
            }
        }

        let devices = (try? system.devices) ?? []
        var found = 0
        for device in devices {
            let name = (try? device.name) ?? ""
            guard name.localizedCaseInsensitiveContains("Sounds Manager")
                || name.localizedCaseInsensitiveContains("SoundsManager") else { continue }
            found += 1
            print("leftover device: \(name) id=\(device.id)")
            if destroy {
                let status = AudioHardwareDestroyAggregateDevice(device.id)
                print("    destroy status=\(status)")
            }
        }
        if found == 0 { print("no leftover aggregate devices visible") }
    }
}
