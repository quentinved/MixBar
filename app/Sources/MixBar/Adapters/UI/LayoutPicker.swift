import SwiftUI

/// Inline segmented control for choosing the layout.
///
/// Deliberately not a `Picker` inside the `…` menu: a nested menu inside a
/// MenuBarExtra panel is unreliable, and this is a setting worth seeing rather
/// than hunting for.
struct LayoutPicker: View {
    @Binding var selection: MixerLayout

    private func symbol(for layout: MixerLayout) -> String {
        switch layout {
        case .compact: return "list.bullet"
        case .comfortable: return "rectangle.grid.1x2"
        case .mixer: return "slider.vertical.3"
        }
    }

    var body: some View {
        HStack(spacing: 1) {
            ForEach(MixerLayout.allCases, id: \.self) { layout in
                let isSelected = selection == layout
                Button {
                    selection = layout
                } label: {
                    Image(systemName: symbol(for: layout))
                        .font(.system(size: 10, weight: .medium))
                        .frame(width: 24, height: 18)
                        .foregroundStyle(isSelected ? Color.white : Color.secondary)
                        .background(
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .fill(isSelected
                                    ? AnyShapeStyle(Brand.fill)
                                    : AnyShapeStyle(Color.clear)))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(layout.title)
            }
        }
        .padding(2)
        .background(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(Color.primary.opacity(0.06)))
    }
}
