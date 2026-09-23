import AppKit
import SwiftUI

/// Taps and aggregate devices registered with coreaudiod outlive the process:
/// unremoved, they sit in the audio path until coreaudiod is restarted.
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var termination: DispatchSourceSignal?

    /// SIGTERM skips `applicationWillTerminate` unless turned into a normal quit.
    func applicationDidFinishLaunching(_ notification: Notification) {
        signal(SIGTERM, SIG_IGN)
        let source = DispatchSource.makeSignalSource(signal: SIGTERM, queue: .main)
        source.setEventHandler { NSApp.terminate(nil) }
        source.resume()
        termination = source
    }

    func applicationWillTerminate(_ notification: Notification) {
        Composition.mixer.shutdown()
    }
}

/// Composition root. A stored static, not `App.init()`: SwiftUI re-initialises
/// the App, which built a second graph polling behind the observed one.
enum Composition {
    static let mixer: MixerControlling = {
        // --demo swaps every driven port for a scripted one, for screenshots.
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
        } label: {
            Image(systemName: "slider.vertical.3")
        }
        // .window gives a real popover that can hold sliders; .menu cannot.
        .menuBarExtraStyle(.window)
    }
}
