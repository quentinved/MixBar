import SwiftUI

struct MixerView: View {
    @ObservedObject var viewModel: MixerViewModel

    // Mirrored into @State: a .window MenuBarExtra hosts its content in a
    // detached panel that does not reliably see @ObservedObject changes.
    @State private var snapshot = MixerSnapshot()
    @State private var levels: [AudioAppID: Float] = [:]
    @State private var layout: MixerLayout = .comfortable
    @State private var showIdleApps = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            titleBar
            outputPicker

            Divider().opacity(0.5)

            if let failure = snapshot.failure {
                errorBanner(failure)
            }

            if snapshot.rows.isEmpty {
                emptyState
            } else if layout == .mixer {
                deskLayout
            } else {
                listLayout
            }
        }
        .frame(width: layout == .mixer ? deskWidth : 320)
        .onReceive(viewModel.$snapshot) { snapshot = $0 }
        .onReceive(viewModel.$levels) { levels = $0 }
        .onReceive(viewModel.$layout) { layout = $0 }
        .onReceive(viewModel.$showIdleApps) { showIdleApps = $0 }
        .onAppear {
            snapshot = viewModel.snapshot
            layout = viewModel.layout
            showIdleApps = viewModel.showIdleApps
            viewModel.startMetering()
        }
        .onDisappear { viewModel.stopMetering() }
    }

    // MARK: - Layouts

    private func controls(for row: MixerSnapshot.Row) -> RowControls {
        RowControls(
            icon: viewModel.icon(for: row.application),
            level: levels[row.id] ?? 0,
            onVolume: { viewModel.setVolume($0, for: row.id) },
            onMute: { viewModel.toggleMute(for: row.id) })
    }

    private var listLayout: some View {
        ScrollView {
            VStack(spacing: layout == .compact ? 0 : 2) {
                ForEach(snapshot.rows) { row in
                    if layout == .compact {
                        CompactRow(row: row, controls: controls(for: row))
                    } else {
                        ComfortableRow(row: row, controls: controls(for: row))
                    }
                }
            }
            .padding(8)
        }
        .frame(maxHeight: 420)
        .scrollIndicators(.never)
    }

    private var deskLayout: some View {
        ScrollView(.horizontal) {
            HStack(alignment: .top, spacing: 0) {
                ForEach(snapshot.rows) { row in
                    ChannelStrip(row: row, controls: controls(for: row))
                }
            }
            .padding(12)
        }
        .frame(height: 232)
        .scrollIndicators(.never)
    }

    /// Capped so a dozen noisy apps cannot grow the panel off the screen.
    private var deskWidth: CGFloat {
        min(max(CGFloat(snapshot.rows.count) * 62 + 24, 260), 560)
    }

    // MARK: - Chrome

    private var titleBar: some View {
        HStack {
            Text("MixBar")
                .font(.system(size: 13, weight: .semibold))
                .fixedSize()

            Spacer()

            LayoutPicker(selection: Binding(
                get: { layout },
                set: { viewModel.layout = $0 }))

            Menu {
                // A Toggle or Picker in a menu in this panel does not commit.
                Button {
                    viewModel.showIdleApps.toggle()
                } label: {
                    if showIdleApps {
                        Label("Show idle apps", systemImage: "checkmark")
                    } else {
                        Text("Show idle apps")
                    }
                }
                Button("Reset all volumes") { viewModel.resetAll() }
                Divider()
                Button("Audio permission…") { viewModel.openPrivacySettings() }
                Divider()
                Button("Quit MixBar") { NSApplication.shared.terminate(nil) }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
        }
        .padding(.horizontal, 12)
        .padding(.top, 10)
        .padding(.bottom, 9)
    }

    private var outputPicker: some View {
        OutputPicker(
            outputs: snapshot.outputs,
            current: snapshot.currentOutput,
            onSelect: { viewModel.selectOutput($0) })
            .padding(.horizontal, 12)
            .padding(.bottom, 10)
    }

    private func errorBanner(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 7) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .font(.system(size: 11))
            Text(text)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(Color.orange.opacity(0.1))
    }

    private var emptyState: some View {
        VStack(spacing: 7) {
            Image(systemName: "speaker.wave.2")
                .font(.system(size: 22, weight: .light))
                .foregroundStyle(.tertiary)
            Text("Nothing playing")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
            Text("Apps show up here when they make a sound.")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
            Button("Not seeing an app?") { viewModel.openPrivacySettings() }
                .buttonStyle(.link)
                .font(.system(size: 11))
                .padding(.top, 1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
    }
}
