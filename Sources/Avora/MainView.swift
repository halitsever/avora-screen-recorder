import SwiftUI

struct MainView: View {
    @ObservedObject var controller: RecordingController
    @ObservedObject var preferences: Preferences
    let openVideos: () -> Void
    /// Space kept free at the top for the window buttons.
    var titlebarHeight: CGFloat = 32

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 9), count: 6)

    var body: some View {
        VStack(spacing: 0) {
            header
            VStack(alignment: .leading, spacing: 0) {
                PreviewStage(preset: preferences.background)
                HStack {
                    Text("BACKGROUND").font(.system(size: 11, weight: .semibold)).tracking(0.8)
                        .foregroundStyle(.white.opacity(0.5))
                    Spacer()
                    Text(preferences.background.name).font(.system(size: 12, weight: .medium))
                }
                .padding(.top, 16).padding(.bottom, 9)
                LazyVGrid(columns: columns, spacing: 9) {
                    ForEach(BackgroundPreset.all) { preset in
                        Swatch(preset: preset, isSelected: preset.id == preferences.backgroundID) {
                            preferences.backgroundID = preset.id
                        }
                    }
                }
                HStack {
                    Button("Open Videos Folder", action: openVideos).buttonStyle(GhostButtonStyle())
                    Spacer()
                    RecordControl(controller: controller)
                }
                .padding(.top, 18)
            }
            .padding(16)
        }
        .frame(width: 640)
        .background(Brand.ink)
        .foregroundStyle(Color(white: 0.93))
        .preferredColorScheme(.dark)
    }

    /// Sits under the window buttons and lines up with the content's left edge.
    private var header: some View {
        HStack(spacing: 8) {
            if let mark = Brand.mark {
                Image(nsImage: mark).resizable().frame(width: 24, height: 24)
                    // The mark image has a transparent margin; this puts the orange edge on the content line.
                    .padding(.leading, -24 * 35 / 256)
            }
            Text("avora").font(Brand.wordmarkFont(size: 20))
            Spacer()
            StatusPill(state: controller.state)
        }
        .frame(height: 34)
        .padding(.horizontal, 16)
        .padding(.top, titlebarHeight)
    }
}

private struct PreviewStage: View {
    let preset: BackgroundPreset

    var body: some View {
        ZStack {
            Image(nsImage: BackgroundThumbnails.image(for: preset, size: CGSize(width: 608, height: 380)))
                .resizable()
            GeometryReader { proxy in
                let size = proxy.size
                ZStack(alignment: .topLeading) {
                    Color(white: 0.96)
                    Color(white: 0.89).frame(height: size.height * 0.82 * 0.08)
                    RoundedRectangle(cornerRadius: 4).fill(.white)
                        .shadow(color: .black.opacity(0.15), radius: 4, y: 1)
                        .frame(width: size.width * 0.82 * 0.52, height: size.height * 0.82 * 0.6)
                        .offset(x: size.width * 0.82 * 0.09, y: size.height * 0.82 * 0.18)
                    RoundedRectangle(cornerRadius: 4).fill(Color(rgb: 0x26262C))
                        .frame(width: size.width * 0.82 * 0.46, height: size.height * 0.82 * 0.54)
                        .offset(x: size.width * 0.82 * 0.45, y: size.height * 0.82 * 0.32)
                }
                .frame(width: size.width * 0.82, height: size.height * 0.82)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .compositingGroup()
                .shadow(color: .black.opacity(0.4), radius: 15, y: 7)
                .frame(width: size.width, height: size.height)
            }
        }
        .aspectRatio(16 / 10, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .animation(.easeOut(duration: 0.2), value: preset.id)
    }
}

private struct Swatch: View {
    let preset: BackgroundPreset
    let isSelected: Bool
    let select: () -> Void

    var body: some View {
        Button(action: select) {
            Image(nsImage: BackgroundThumbnails.image(for: preset, size: CGSize(width: 90, height: 62)))
                .resizable()
                .aspectRatio(1.45, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.white.opacity(0.12), lineWidth: 0.5))
                .padding(3)
                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(isSelected ? Brand.orange : .clear, lineWidth: 2))
        }
        .buttonStyle(.plain)
        .help(preset.name)
        .accessibilityLabel(preset.name)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct StatusPill: View {
    let state: RecordingController.State

    var body: some View {
        Text(label)
            .font(.system(size: 11.5))
            .foregroundStyle(.white.opacity(0.72))
            .padding(.horizontal, 10).padding(.vertical, 4)
            .background(.white.opacity(0.06), in: Capsule())
    }

    private var label: String {
        switch state {
        case .idle: "Ready · \(NSScreen.main?.localizedName ?? "Display")"
        case .starting: "Starting"
        case .recording: "Recording"
        case .rendering: "Rendering"
        }
    }
}

private struct RecordControl: View {
    @ObservedObject var controller: RecordingController

    var body: some View {
        switch controller.state {
        case .idle:
            Button { Task { await controller.toggle() } } label: {
                HStack(spacing: 9) {
                    Circle().fill(.white).frame(width: 10, height: 10)
                    Text("Start Recording")
                    Text("⌘R").opacity(0.75).font(.system(size: 11))
                }
            }
            .buttonStyle(PrimaryButtonStyle(fill: Brand.orange, text: .white))
            .keyboardShortcut("r", modifiers: .command)

        case .starting:
            Button("Starting…") {}.buttonStyle(PrimaryButtonStyle(fill: Brand.orange.opacity(0.5), text: .white)).disabled(true)

        case .recording(let since):
            Button { Task { await controller.toggle() } } label: {
                HStack(spacing: 9) {
                    RoundedRectangle(cornerRadius: 2).fill(Brand.ink).frame(width: 10, height: 10)
                    TimelineView(.periodic(from: since, by: 1)) { context in
                        Text("Stop · \(elapsed(since, context.date))").monospacedDigit()
                    }
                }
            }
            .buttonStyle(PrimaryButtonStyle(fill: Color(white: 0.93), text: Brand.ink))
            .keyboardShortcut("r", modifiers: .command)

        case .rendering(let progress):
            HStack(spacing: 10) {
                ProgressView(value: progress).progressViewStyle(.linear).tint(Brand.orange).frame(width: 140)
                Text("Rendering \(Int(progress * 100))%").font(.system(size: 12.5)).monospacedDigit()
            }
            .frame(height: 38)
        }
    }

    private func elapsed(_ since: Date, _ now: Date) -> String {
        let seconds = max(Int(now.timeIntervalSince(since)), 0)
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}

private struct PrimaryButtonStyle: ButtonStyle {
    let fill: Color
    let text: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13.5, weight: .semibold))
            .foregroundStyle(text)
            .padding(.horizontal, 18).frame(height: 38)
            .background(fill.opacity(configuration.isPressed ? 0.85 : 1), in: RoundedRectangle(cornerRadius: 9))
            .shadow(color: fill.opacity(0.35), radius: 8, y: 4)
    }
}

private struct GhostButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .padding(.horizontal, 14).frame(height: 34)
            .background(.white.opacity(configuration.isPressed ? 0.12 : 0.07), in: RoundedRectangle(cornerRadius: 9))
    }
}
