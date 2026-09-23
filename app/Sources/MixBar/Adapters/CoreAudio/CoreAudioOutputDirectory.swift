import CoreAudio
import Foundation

/// Lists and switches the system default output device.
final class CoreAudioOutputDirectory: AudioOutputDirectory {
    private let observer = PropertyObserver()

    init() {
        observer.listen(
            to: AudioObjectID(kAudioObjectSystemObject),
            for: [kAudioHardwarePropertyDefaultOutputDevice, kAudioHardwarePropertyDevices])
    }

    /// The mixing device wraps its output, so a switch must reach the engine now.
    func observeChanges(_ handler: @escaping () -> Void) {
        observer.observe(handler)
    }

    func availableOutputs() -> [AudioOutput] {
        guard let devices = try? AudioHardwareSystem.shared.devices else { return [] }
        return devices.compactMap { device in
            guard Self.hasOutputChannels(device.id),
                  Self.isSelectable(device) else { return nil }
            return Self.output(for: device)
        }
    }

    func currentOutput() -> AudioOutput? {
        guard let device = try? AudioHardwareSystem.shared.defaultOutputDevice else { return nil }
        return Self.output(for: device)
    }

    func selectOutput(_ output: AudioOutput) throws {
        guard let device = try AudioHardwareSystem.shared.device(forUID: output.id) else { return }
        try AudioHardwareSystem.shared.setDefaultOutputDevice(device)
    }

    private static func output(for device: AudioHardwareDevice) -> AudioOutput? {
        guard let uid = try? device.uid else { return nil }
        let name = (try? device.name) ?? uid
        return AudioOutput(id: uid, name: name, kind: kind(of: device, named: name))
    }

    /// A device that cannot become the default output would be a dead row in
    /// the picker: choosing it changes nothing. Hidden devices are ours and
    /// other apps' plumbing, and macOS does not list them either.
    private static func isSelectable(_ device: AudioHardwareDevice) -> Bool {
        ((try? device.canBeDefaultOutputDevice) ?? true) && !((try? device.isHidden) ?? false)
    }

    private static func kind(
        of device: AudioHardwareDevice, named name: String
    ) -> AudioOutput.Kind {
        switch (try? device.transportType) ?? kAudioDeviceTransportTypeUnknown {
        case kAudioDeviceTransportTypeBuiltIn:
            // The headphone jack is a built-in device; only the name tells them apart.
            return name.localizedCaseInsensitiveContains("headphone") ? .headphones : .builtIn
        case kAudioDeviceTransportTypeBluetooth, kAudioDeviceTransportTypeBluetoothLE:
            return .bluetooth
        case kAudioDeviceTransportTypeAirPlay:
            return .airPlay
        case kAudioDeviceTransportTypeHDMI, kAudioDeviceTransportTypeDisplayPort:
            return .display
        case kAudioDeviceTransportTypeVirtual, kAudioDeviceTransportTypeAggregate:
            return .virtual
        default:
            return .external
        }
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
