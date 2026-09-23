import AppKit
import SwiftUI

/// The real popover view on the demo roster, in a window `screencapture` can
/// shoot: scripts cannot click the status item, and `cacheDisplay` loses the panel.
enum Screenshot {
    struct Pose {
        let layout: MixerLayout
        let isDark: Bool
    }

    static func requestedPose(_ arguments: [String]) -> Pose? {
        guard let flag = arguments.firstIndex(of: "--pose"),
              arguments.indices.contains(flag + 1),
              let layout = MixerLayout(rawValue: arguments[flag + 1])
        else { return nil }
        return Pose(layout: layout, isDark: arguments.contains("--dark"))
    }

    static func run(_ pose: Pose) {
        let application = NSApplication.shared
        application.setActivationPolicy(.accessory)

        Task { @MainActor in
            let window = makeWindow(for: pose)
            // Give the first poll and the meters a moment to fill the panel.
            try? await Task.sleep(for: .seconds(1.5))
            print("window \(window.windowNumber)")
            fflush(stdout)
        }
        application.run()
    }

    @MainActor
    private static func makeWindow(for pose: Pose) -> NSWindow {
        let viewModel = MixerViewModel(mixer: DemoComposition.mixer())
        viewModel.layout = pose.layout

        let appearance = NSAppearance(named: pose.isDark ? .darkAqua : .aqua)
        let hosting = NSHostingView(rootView: MixerView(viewModel: viewModel))
        hosting.appearance = appearance

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 240),
            styleMask: .borderless,
            backing: .buffered,
            defer: false)
        window.appearance = appearance
        window.isReleasedWhenClosed = false
        // Transparent window, coloured layer: it is the layer that can carry the
        // popover's corner radius, and the corners have to stay see-through.
        window.isOpaque = false
        window.backgroundColor = .clear
        window.contentView = hosting
        window.level = .floating

        window.center()
        window.orderFrontRegardless()
        window.setContentSize(hosting.fittingSize)
        style(hosting, for: pose)
        return window
    }

    @MainActor
    private static func style(_ view: NSView, for pose: Pose) {
        view.wantsLayer = true
        view.layer?.backgroundColor = panelColor(for: pose).cgColor
        view.layer?.cornerRadius = 10
        view.layer?.cornerCurve = .continuous
        view.layer?.masksToBounds = true
    }

    /// The colour the translucent material settles to over a neutral background.
    private static func panelColor(for pose: Pose) -> NSColor {
        pose.isDark
            ? NSColor(calibratedWhite: 0.14, alpha: 1)
            : NSColor(calibratedWhite: 0.97, alpha: 1)
    }
}
