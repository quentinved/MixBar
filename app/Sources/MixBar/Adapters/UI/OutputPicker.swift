import SwiftUI

/// The output device chooser.
///
/// Styled as an obvious control, not a line of text: without the border and
/// the hover lift it read as a label, and nobody realised it could be changed.
struct OutputPicker: View {
    let outputs: [AudioOutput]
    let current: AudioOutput?
    let onSelect: (AudioOutput) -> Void

    @State private var isHovering = false

    var body: some View {
        Menu {
            // Grouped and captioned: a flat list of device names says nothing
            // about which entry is the speakers and which is a virtual driver.
            ForEach(AudioOutput.sections(of: outputs)) { section in
                Section(section.kind.title) {
                    ForEach(section.outputs) { output in
                        Button { onSelect(output) } label: {
                            Label(output.name, systemImage: symbol(for: output))
                        }
                    }
                }
            }
        } label: {
            well
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .disabled(outputs.isEmpty)
        .onHover { isHovering = $0 }
        .help("Where every app's sound goes")
    }

    private var well: some View {
        HStack(spacing: 7) {
            // The speaker macOS wears in its own menu bar; the device's own
            // glyph put a laptop beside "MacBook Pro Speakers".
            Image(systemName: current == nil ? "speaker.slash.fill" : "speaker.wave.2.fill")
                .font(.system(size: 11))
                .frame(width: 14)
                .foregroundStyle(Brand.start)

            Text(current?.name ?? "No output")
                .font(.system(size: 12, weight: .medium))
                .lineLimit(1)

            Spacer(minLength: 4)

            Image(systemName: "chevron.down")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.primary.opacity(isHovering ? 0.10 : 0.06)))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Color.primary.opacity(isHovering ? 0.20 : 0.12), lineWidth: 1))
        .contentShape(Rectangle())
    }

    /// The chosen device wears a checkmark instead of its icon: that is how a
    /// macOS menu marks a selection, and its section already names the kind.
    private func symbol(for output: AudioOutput) -> String {
        guard output.id != current?.id else { return "checkmark" }
        return Self.symbol(for: output.kind)
    }

    private static func symbol(for kind: AudioOutput.Kind) -> String {
        switch kind {
        case .builtIn: return "laptopcomputer"
        case .headphones: return "headphones"
        case .bluetooth: return "wave.3.right"
        case .airPlay: return "airplayaudio"
        case .display: return "display"
        case .external: return "hifispeaker.fill"
        case .virtual: return "waveform"
        }
    }
}
