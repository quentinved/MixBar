import CoreAudio
import Foundation

/// Core Audio property changes, coalesced into one call on the main queue: a
/// browser opening five streams is one refresh, not five.
final class PropertyObserver {
    private typealias Listener = (AudioObjectPropertyAddress, AudioObjectPropertyListenerBlock)

    private let queue = DispatchQueue(label: "com.quentinved.MixBar.observer")
    private var handler: (() -> Void)?
    private var isPending = false

    /// Touched only by the caller's thread; `handler` and `isPending` only on `queue`.
    private var listeners: [AudioObjectID: [Listener]] = [:]

    func observe(_ handler: @escaping () -> Void) {
        queue.sync { self.handler = handler }
    }

    func listen(to object: AudioObjectID, for selectors: [AudioObjectPropertySelector]) {
        guard listeners[object] == nil else { return }
        listeners[object] = selectors.compactMap { selector in
            var address = AudioObjectPropertyAddress(
                mSelector: selector,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain)
            let block: AudioObjectPropertyListenerBlock = { [weak self] _, _ in self?.changed() }
            let status = AudioObjectAddPropertyListenerBlock(object, &address, queue, block)
            return status == noErr ? (address, block) : nil
        }
    }

    /// Listens to exactly these objects: new ones are added, and the rest,
    /// usually processes that have exited, are dropped.
    func listen(toOnly objects: Set<AudioObjectID>, for selectors: [AudioObjectPropertySelector]) {
        for object in listeners.keys where !objects.contains(object) {
            stopListening(to: object)
        }
        for object in objects {
            listen(to: object, for: selectors)
        }
    }

    private func stopListening(to object: AudioObjectID) {
        for (address, block) in listeners.removeValue(forKey: object) ?? [] {
            var address = address
            // Fails once the object is gone, which is the usual case and fine.
            _ = AudioObjectRemovePropertyListenerBlock(object, &address, queue, block)
        }
    }

    private func changed() {
        guard !isPending else { return }
        isPending = true
        queue.asyncAfter(deadline: .now() + .milliseconds(50)) { [weak self] in
            guard let self else { return }
            isPending = false
            let handler = self.handler
            DispatchQueue.main.async { handler?() }
        }
    }
}
