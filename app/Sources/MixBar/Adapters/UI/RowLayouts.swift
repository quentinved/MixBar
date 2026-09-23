import SwiftUI

// One view per `MixerLayout` case. They share their parts, so the three cannot
// drift into three slightly different-looking apps.

/// Compact: one line per app, for seeing everything at once.
struct CompactRow: View {
    let row: MixerSnapshot.Row
    let controls: RowControls

    var body: some View {
        HStack(spacing: 8) {
            AppIcon(image: controls.icon, size: 18, isMuted: row.mix.isMuted)

            Text(row.application.name)
                .font(.system(size: 11, weight: .medium))
                .lineLimit(1)
                .truncationMode(.tail)
                .foregroundStyle(row.mix.isMuted ? .secondary : .primary)
                // Fixed, so the sliders line up into a column instead of
                // stepping in and out with the length of each app's name.
                .frame(width: 78, alignment: .leading)

            VolumeSlider(
                volume: row.mix.volume.value,
                level: controls.level,
                isMuted: row.mix.isMuted,
                onChange: controls.onVolume,
                thickness: 3,
                showsKnob: false)
                .accessibilityLabel("\(row.application.name) volume")

            Text("\(row.mix.percent)%")
                .font(.system(size: 10, weight: .medium))
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(width: 30, alignment: .trailing)

            MuteButton(isMuted: row.mix.isMuted, size: 9, action: controls.onMute)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 6)
        .rowChrome(cornerRadius: 7, isPlaying: row.application.isPlaying)
    }
}

/// Comfortable: icon, name and a full-width slider. The default.
struct ComfortableRow: View {
    let row: MixerSnapshot.Row
    let controls: RowControls

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            AppIcon(image: controls.icon, size: 29, isMuted: row.mix.isMuted)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text(row.application.name)
                        .font(.system(size: 12, weight: .medium))
                        .lineLimit(1)
                        .foregroundStyle(row.mix.isMuted ? .secondary : .primary)

                    Spacer(minLength: 4)

                    Text("\(row.mix.percent)%")
                        .font(.system(size: 10, weight: .medium))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        // Reserve the space so the row does not shift while dragging.
                        .frame(width: 30, alignment: .trailing)

                    MuteButton(isMuted: row.mix.isMuted, size: 10, action: controls.onMute)
                }

                VolumeSlider(
                    volume: row.mix.volume.value,
                    level: controls.level,
                    isMuted: row.mix.isMuted,
                    onChange: controls.onVolume)
                    .accessibilityLabel("\(row.application.name) volume")
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .rowChrome(cornerRadius: 9, isPlaying: row.application.isPlaying)
    }
}

/// Mixer: a vertical channel strip per app, the way a mixing desk reads, and the
/// layout the app's own icon depicts.
struct ChannelStrip: View {
    let row: MixerSnapshot.Row
    let controls: RowControls

    var body: some View {
        VStack(spacing: 7) {
            AppIcon(image: controls.icon, size: 26, isMuted: row.mix.isMuted)

            ChannelFader(
                volume: row.mix.volume.value,
                level: controls.level,
                isMuted: row.mix.isMuted,
                onChange: controls.onVolume)
                .frame(width: 26, height: 112)
                .accessibilityLabel("\(row.application.name) volume")

            Text("\(row.mix.percent)")
                .font(.system(size: 10, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(.secondary)

            MuteButton(isMuted: row.mix.isMuted, size: 9, action: controls.onMute)

            Text(row.application.name)
                .font(.system(size: 9))
                .lineLimit(1)
                .truncationMode(.tail)
                .foregroundStyle(.secondary)
                .frame(width: 54)
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 8)
        .frame(width: 62)
        .rowChrome(cornerRadius: 9, isPlaying: row.application.isPlaying)
    }
}
