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
        // --demo swaps every driven port for a scripted one, so the app runs
        // with no device, no permission and nothing playing. It is how the
        // screenshots are taken; a normal launch never reaches it.
        let arguments = CommandLine.arguments
        if arguments.contains("--demo") || Screenshot.requestedPose(arguments) != nil {
            return DemoComposition.mixer()
        }

        let registry = ProcessRegistry()
        return MixerService(
            catalog: CoreAudioApplicationCatalog(registry: registry),
            engine: CoreAudioMixingEngine(registry: registry),
            outputs: CoreAudioOutputDirectory(),
            store: UserDefaultsSettingsStore()
        )
    }()
}

/// Entry point, so `--shoot` can run a plain AppKit render instead of the
/// menu-bar app, which has no window to photograph until someone clicks it.
@main
enum Launcher {
    static func main() {
        if let pose = Screenshot.requestedPose(CommandLine.arguments) {
            Screenshot.run(pose)
            return
        }
        MixBarApp.main()
    }
}

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
