import SwiftUI

/// A vertical fader, for the mixing-desk layout.
///
/// Same reading as the horizontal slider: the fill is the volume you set, the
/// brighter glow inside it is what is actually playing.
struct ChannelFader: View {
    let volume: Float
    let level: Float
    let isMuted: Bool
    let onChange: (Float) -> Void

    @State private var isDragging = false

    private let width: CGFloat = 5
    private let knob: CGFloat = 13

    var body: some View {
        GeometryReader { geometry in
            let height = geometry.size.height
            let filled = height * CGFloat(isMuted ? 0 : volume)
            let lit = min(height * CGFloat(isMuted ? 0 : level), filled)

            ZStack(alignment: .bottom) {
                Capsule()
                    .fill(Color.primary.opacity(0.09))
                    .frame(width: width)

                Capsule()
                    .fill(isMuted ? AnyShapeStyle(Color.secondary.opacity(0.35))
                                  : AnyShapeStyle(Brand.verticalFill))
                    .frame(width: width, height: filled)

                Capsule()
                    .fill(Color.white.opacity(0.45))
                    .frame(width: width, height: lit)
                    .blendMode(.plusLighter)
                    .animation(.linear(duration: 0.08), value: lit)

                Circle()
                    .fill(.white)
                    .shadow(color: .black.opacity(0.25), radius: 1.5, y: 1)
                    .frame(width: knob, height: knob)
                    .offset(y: -max(0, filled - knob / 2))
                    .opacity(isMuted ? 0.4 : 1)
                    .scaleEffect(isDragging ? 1.15 : 1)
                    .animation(.spring(response: 0.2, dampingFraction: 0.7), value: isDragging)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        isDragging = true
                        // Screen coordinates grow downward; a fader does not.
                        let fraction = 1 - (value.location.y / height)
                        onChange(Float(min(max(fraction, 0), 1)))
                    }
                    .onEnded { _ in isDragging = false }
            )
        }
        .adjustableVolume(volume, isMuted: isMuted, onChange: onChange)
    }
}
