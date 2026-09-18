import SwiftUI

/// The output device chooser.
///
/// Styled as an obvious control rather than a line of text: a bordered, filled
/// well that lifts on hover. Without the border it read as a label, and people
/// did not realise the device could be changed at all.
struct OutputPicker: View {
    let outputs: [AudioOutput]
    let current: AudioOutput?
    let onSelect: (AudioOutput) -> Void

    @State private var isHovering = false

    var body: some View {
        Menu {
            ForEach(outputs) { output in
                Button {
                    onSelect(output)
                } label: {
                    if output.id == current?.id {
                        Label(output.name, systemImage: "checkmark")
                    } else {
                        Text(output.name)
                    }
                }
            }
        } label: {
            HStack(spacing: 7) {
                Image(systemName: "hifispeaker.fill")
                    .font(.system(size: 11))
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
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .onHover { isHovering = $0 }
    }
}
