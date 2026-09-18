import CoreAudio
import Foundation

/// Lists and switches the system default output device.
final class CoreAudioOutputDirectory: AudioOutputDirectory {
    func availableOutputs() -> [AudioOutput] {
        guard let devices = try? AudioHardwareSystem.shared.devices else { return [] }
        return devices.compactMap { device in
            guard Self.hasOutputChannels(device.id), let uid = try? device.uid else { return nil }
            return AudioOutput(id: uid, name: (try? device.name) ?? uid)
        }
    }

    func currentOutput() -> AudioOutput? {
        guard let device = try? AudioHardwareSystem.shared.defaultOutputDevice,
              let uid = try? device.uid else { return nil }
        return AudioOutput(id: uid, name: (try? device.name) ?? uid)
    }

    func selectOutput(_ output: AudioOutput) throws {
        guard let device = try AudioHardwareSystem.shared.device(forUID: output.id) else { return }
        try AudioHardwareSystem.shared.setDefaultOutputDevice(device)
    }

    private static func hasOutputChannels(_ device: AudioObjectID) -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreamConfiguration,
            mScope: kAudioObjectPropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(device, &address, 0, nil, &size) == noErr,
              size > 0 else { return false }

        let raw = UnsafeMutableRawPointer.allocate(
            byteCount: Int(size), alignment: MemoryLayout<AudioBufferList>.alignment)
        defer { raw.deallocate() }
        guard AudioObjectGetPropertyData(device, &address, 0, nil, &size, raw) == noErr else {
            return false
        }
        let list = UnsafeMutableAudioBufferListPointer(
            raw.assumingMemoryBound(to: AudioBufferList.self))
        return list.contains { $0.mNumberChannels > 0 }
    }
}
