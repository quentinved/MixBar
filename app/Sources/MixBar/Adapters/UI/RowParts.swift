import SwiftUI

/// Per-row callbacks and data, so three layouts share one call site.
struct RowControls {
    let icon: NSImage?
    let level: Float
    let onVolume: (Float) -> Void
    let onMute: () -> Void
}

/// The app's own icon, or a placeholder for the apps AppKit cannot give one for.
struct AppIcon: View {
    let image: NSImage?
    let size: CGFloat
    let isMuted: Bool

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image).resizable()
            } else {
                Image(systemName: "app.dashed").resizable().foregroundStyle(.tertiary)
            }
        }
        .frame(width: size, height: size)
        // Drained of colour rather than hidden: a muted app still reads as itself.
        .saturation(isMuted ? 0 : 1)
        .opacity(isMuted ? 0.6 : 1)
    }
}

struct MuteButton: View {
    let isMuted: Bool
    let size: CGFloat
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                .font(.system(size: size))
                .foregroundStyle(isMuted ? Color.secondary : Brand.start)
                .frame(width: size + 4, height: size + 4)
        }
        .buttonStyle(.plain)
    }
}

extension AppMix {
    /// The gain as the row prints it.
    var percent: Int { Int((gain * 100).rounded()) }
}

extension View {
    /// Hover highlight, plus the dimming that marks an app as idle. Idle rows are
    /// greyed rather than hidden, so the list does not jump as apps stop playing.
    func rowChrome(cornerRadius: CGFloat, isPlaying: Bool) -> some View {
        modifier(RowChrome(cornerRadius: cornerRadius, isPlaying: isPlaying))
    }
}

private struct RowChrome: ViewModifier {
    let cornerRadius: CGFloat
    let isPlaying: Bool

    @State private var isHovering = false

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.primary.opacity(isHovering ? 0.05 : 0)))
            .onHover { isHovering = $0 }
            .opacity(isPlaying ? 1 : 0.55)
    }
}
