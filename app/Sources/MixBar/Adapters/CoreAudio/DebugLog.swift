import Foundation

/// Development-only trace to a file: os_log from an ad-hoc-signed app never
/// reaches `log show`, and launching via `open` discards stderr.
enum DebugLog {
    /// Off unless asked for:
    ///   defaults write com.quentinvedrenne.MixBar debugLogging -bool true
    static let isEnabled: Bool =
        UserDefaults.standard.bool(forKey: "debugLogging")
        || ProcessInfo.processInfo.environment["MIXBAR_DEBUG"] == "1"

    static let url = URL(fileURLWithPath: NSHomeDirectory())
        .appendingPathComponent("Library/Logs/MixBar.log")

    private static let queue = DispatchQueue(label: "com.quentinvedrenne.MixBar.log")
    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()

    /// Takes a closure, not a string: these sit on a 1.5s timer, so a disabled
    /// log must not pay for the message it will never write.
    static func write(_ message: () -> String) {
        guard isEnabled else { return }
        append(message())
    }

    private static func append(_ message: String) {
        let line = "\(formatter.string(from: Date())) \(message)\n"
        queue.async {
            guard let data = line.data(using: .utf8) else { return }
            if let handle = try? FileHandle(forWritingTo: url) {
                defer { try? handle.close() }
                _ = try? handle.seekToEnd()
                try? handle.write(contentsOf: data)
            } else {
                try? data.write(to: url)
            }
        }
    }
}
