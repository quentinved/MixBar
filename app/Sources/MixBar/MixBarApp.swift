import AppKit
import SwiftUI

/// Taps and aggregate devices registered with coreaudiod outlive the process:
/// unremoved, they sit in the audio path until coreaudiod is restarted.
final class AppDelegate: NSObject, NSApplicationDelegate {
    var onTerminate: (() -> Void)?

    func applicationWillTerminate(_ notification: Notification) {
        onTerminate?()
    }
}

/// Composition root. A stored static, not `App.init()`: SwiftUI re-initialises
/// the App, which built a second graph polling behind the observed one.
enum Composition {
    static let mixer: MixerControlling = {
        let registry = ProcessRegistry()
        return MixerService(
            catalog: CoreAudioApplicationCatalog(registry: registry),
            engine: CoreAudioMixingEngine(registry: registry),
            outputs: CoreAudioOutputDirectory(),
            store: UserDefaultsSettingsStore()
        )
    }()
}

@main
struct MixBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    @StateObject private var viewModel = MixerViewModel(mixer: Composition.mixer)

    var body: some Scene {
        MenuBarExtra {
            MixerView(viewModel: viewModel)
                .onAppear { delegate.onTerminate = { [viewModel] in viewModel.shutdown() } }
        } label: {
            Image(systemName: "slider.vertical.3")
        }
        // .window gives a real popover that can hold sliders; .menu cannot.
        .menuBarExtraStyle(.window)
    }
}
