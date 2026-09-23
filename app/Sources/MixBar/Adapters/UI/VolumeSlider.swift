import SwiftUI

/// A volume slider whose track doubles as its meter: the fill is the volume
/// you set, the glow inside it is what is actually coming out.
struct VolumeSlider: View {
    let volume: Float
    let level: Float
    let isMuted: Bool
    let onChange: (Float) -> Void

    var thickness: CGFloat = 5
    var showsKnob: Bool = true

    @State private var isDragging = false
    @State private var isHovering = false

    private var knob: CGFloat { max(thickness + 6, 11) }
    private var hitHeight: CGFloat { max(knob, 14) }

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let filled = width * CGFloat(isMuted ? 0 : volume)
            // The meter is post-gain already, so it measures the full width.
            let lit = min(width * CGFloat(isMuted ? 0 : level), filled)

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.primary.opacity(0.09))
                    .frame(height: thickness)

                Capsule()
                    .fill(isMuted ? AnyShapeStyle(Color.secondary.opacity(0.35))
                                  : AnyShapeStyle(Brand.fill))
                    .frame(width: filled, height: thickness)

                Capsule()
                    .fill(Color.white.opacity(0.45))
                    .frame(width: lit, height: thickness)
                    .blendMode(.plusLighter)
                    .animation(.linear(duration: 0.08), value: lit)

                if showsKnob {
                    Circle()
                        .fill(.white)
                        .shadow(color: .black.opacity(0.25), radius: 1.5, y: 1)
                        .frame(width: knob, height: knob)
                        .offset(x: max(0, filled - knob / 2))
                        .opacity(isMuted ? 0.4 : 1)
                        .scaleEffect(isDragging ? 1.15 : 1)
                        .animation(.spring(response: 0.2, dampingFraction: 0.7), value: isDragging)
                } else {
                    Circle()
                        .fill(.white)
                        .shadow(color: .black.opacity(0.2), radius: 1, y: 0.5)
                        .frame(width: thickness + 4, height: thickness + 4)
                        .offset(x: max(0, filled - (thickness + 4) / 2))
                        .opacity((isHovering || isDragging) && !isMuted ? 1 : 0)
                        .animation(.easeOut(duration: 0.12), value: isHovering)
                }
            }
            .frame(height: hitHeight)
            // A thin track must still be easy to grab.
            .contentShape(Rectangle())
            .onHover { isHovering = $0 }
            .gesture(
                // minimumDistance 0 so a plain click jumps to that position.
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        isDragging = true
                        // A layout pass can hand us a zero width, and the NaN
                        // would spread into every frame below.
                        guard width > 0 else { return }
                        onChange(Float(min(max(value.location.x / width, 0), 1)))
                    }
                    .onEnded { _ in isDragging = false }
            )
        }
        .frame(height: hitHeight)
        .adjustableVolume(volume, isMuted: isMuted, onChange: onChange)
    }
}
