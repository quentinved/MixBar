import CoreAudio
import Darwin
import Dispatch
import Foundation

let usage = """
audiotap-spike — does per-app volume control actually work on this machine?

USAGE
  audiotap-spike list                     List processes Core Audio knows about
  audiotap-spike tap <pid> [--gain 0.3]   Tap one process and re-render it at <gain>
  audiotap-spike diag <pid> <pid>...      Compare tap and device buffer formats
  audiotap-spike cleanup [--destroy]      List orphaned taps and aggregate devices,
                                          and with --destroy, remove them

While tapping, the target app's own output is muted and this tool renders its
audio instead. If you hear the app get quieter, per-app volume works.

`cleanup` matters because taps and aggregate devices outlive the process that
made them: a crash or SIGKILL leaves them in the system audio path.
"""

func runList() throws {
    let processes = try ProcessList.all().sorted {
        ($0.isPlaying ? 0 : 1, $0.displayName) < ($1.isPlaying ? 0 : 1, $1.displayName)
    }
    guard !processes.isEmpty else {
        print("No audio processes found.")
        return
    }
    print(String(format: "%-8@ %-6@ %@", "PID" as NSString, "OUT" as NSString, "BUNDLE ID" as NSString))
    for process in processes {
        let playing = process.isPlaying ? "▶︎" : " "
        let bundle = process.bundleID.isEmpty ? "(none)" : process.bundleID
        print(String(format: "%-8d %-6@ %@", process.pid, playing as NSString, bundle as NSString))
    }
    print("\n▶︎ = currently playing audio. Tap one with: audiotap-spike tap <pid>")
}

func runTap(pid: pid_t, gain: Float) throws {
    let session = TapSession()
    try session.start(pid: pid, gain: gain)
    print("Tapping pid \(pid) at gain \(gain). Press Ctrl-C to stop.\n")

    // Core Audio keeps the tap alive as long as we do, but a crash would leave
    // the app muted, so tear down explicitly on Ctrl-C.
    signal(SIGINT, SIG_IGN)
    let interrupt = DispatchSource.makeSignalSource(signal: SIGINT, queue: .main)
    interrupt.setEventHandler {
        print("\n\nStopping…")
        session.stop()
        if session.sawFormatMismatch {
            print("NOTE: tap and device buffer layouts did not match; a real mixer needs a converter here.")
        }
        exit(0)
    }
    interrupt.resume()

    let meter = DispatchSource.makeTimerSource(queue: .main)
    meter.schedule(deadline: .now(), repeating: .milliseconds(100))
    meter.setEventHandler {
        let peak = session.readPeak()
        let filled = Int((min(peak, 1) * 40).rounded())
        let bar = String(repeating: "█", count: filled)
            + String(repeating: "·", count: 40 - filled)
        FileHandle.standardError.write(
            Data(String(format: "\r[%@] %.3f", bar as NSString, peak).utf8))
    }
    meter.resume()

    dispatchMain()
}

let arguments = Array(CommandLine.arguments.dropFirst())

do {
    switch arguments.first {
    case "list":
        try runList()

    case "tap":
        guard arguments.count >= 2, let pid = pid_t(arguments[1]) else {
            print(usage)
            exit(2)
        }
        var gain: Float = 0.3
        if let flag = arguments.firstIndex(of: "--gain"),
           arguments.count > flag + 1,
           let value = Float(arguments[flag + 1]) {
            gain = value
        }
        try runTap(pid: pid, gain: gain)

    case "diag":
        let pids = arguments.dropFirst().compactMap { pid_t($0) }
        guard pids.count >= 2 else { print("usage: audiotap-spike diag <pid> <pid>"); exit(2) }
        try Diagnose.run(pids: pids)

    case "cleanup":
        Cleanup.run(destroy: arguments.contains("--destroy"))

    default:
        print(usage)
    }
} catch let error as TapError {
    FileHandle.standardError.write(Data("error: \(error.description)\n".utf8))
    exit(1)
} catch {
    FileHandle.standardError.write(Data("error: \(error)\n".utf8))
    exit(1)
}
