import CoreAudio
import Foundation

/// Maps one `AudioAppID` to the several Core Audio process objects an app
/// plays through, so the user gets one slider per app. This mapping is the
/// seam that keeps `AudioObjectID` out of the layers above.
final class ProcessRegistry {
    private var byAppID: [AudioAppID: [AudioObjectID]] = [:]
    private let lock = NSLock()

    func record(_ id: AudioAppID, objectIDs: [AudioObjectID]) {
        lock.lock(); defer { lock.unlock() }
        byAppID[id] = objectIDs
    }

    func objectIDs(for id: AudioAppID) -> [AudioObjectID] {
        lock.lock(); defer { lock.unlock() }
        return byAppID[id] ?? []
    }
}
