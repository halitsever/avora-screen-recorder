import SwiftUI
import ZoomEngine

struct EditorView: View {
    @ObservedObject var model: EditorModel

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            HStack(spacing: 0) {
                VStack(spacing: 12) {
                    PlayerView(player: model.player)
                        .background(Color.black.opacity(0.25))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    transport
                }
                .padding(18)
                Divider().overlay(Color.white.opacity(0.06))
                ZoomInspector(model: model)
                    .frame(width: 270)
            }
            Divider().overlay(Color.white.opacity(0.06))
            ZoomTimelineView(model: model)
                .frame(height: model.waveform == nil ? 150 : 200)
                .padding(.horizontal, 18).padding(.vertical, 12)
        }
        .background(Brand.ink)
        .foregroundStyle(Color(white: 0.93))
        .tint(Brand.orange)
        .preferredColorScheme(.dark)
        .alert("Avora", isPresented: Binding(get: { model.errorMessage != nil }, set: { if !$0 { model.errorMessage = nil } })) {
            Button("OK") { model.errorMessage = nil }
        } message: {
            Text(model.errorMessage ?? "")
        }
    }

    private var toolbar: some View {
        HStack(spacing: 10) {
            Text(model.title).font(.system(size: 13, weight: .medium)).foregroundStyle(.secondary)
            Spacer()
            Button("Reset Zooms") { model.resetZooms() }
                .help("Throw away your edits and go back to the zooms made from your clicks")
            if let progress = model.exportProgress {
                ProgressView(value: progress).frame(width: 120)
                Text("Exporting \(Int(progress * 100))%").font(.system(size: 12)).monospacedDigit()
            } else {
                Button("Export") { Task { await model.export() } }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut("e", modifiers: .command)
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 46)
    }

    private var transport: some View {
        HStack(spacing: 12) {
            Button { model.togglePlay() } label: {
                Image(systemName: model.isPlaying ? "pause.fill" : "play.fill").frame(width: 14)
            }
            .buttonStyle(.bordered)
            .help("Play or pause (Space)")
            Text("\(clock(model.time)) / \(clock(model.duration))")
                .font(.system(size: 12, design: .monospaced)).foregroundStyle(.secondary)
            Spacer()
            if let index = model.timeline.index(at: model.time) {
                Text(String(format: "zoom %.1f×", model.timeline.segments[index].scale))
                    .font(.system(size: 12, design: .monospaced)).foregroundStyle(.secondary)
            }
        }
    }
}

func clock(_ seconds: Double) -> String {
    let whole = Int(seconds)
    return String(format: "%d:%02d.%02d", whole / 60, whole % 60, Int((seconds - Double(whole)) * 100))
}

private struct ZoomInspector: View {
    @ObservedObject var model: EditorModel
    @State private var still: CGImage?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            if let index = model.selection, let segment = model.selected {
                Text("ZOOM \(index + 1) OF \(model.timeline.segments.count)")
                    .font(.system(size: 11, weight: .semibold)).tracking(0.6).foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Focus")
                    Picker("Focus", selection: Binding(
                        get: { segment.focus == nil },
                        set: { model.setFocus($0 ? nil : CGPoint(x: 0.5, y: 0.5)) }
                    )) {
                        Text("Auto").tag(true)
                        Text("Manual").tag(false)
                    }
                    .pickerStyle(.segmented).labelsHidden()
                    if let focus = segment.focus {
                        FocusPicker(image: still, focus: focus) { model.setFocus($0) }
                            .task(id: segment.start) { still = await model.still(at: segment.start + 0.05) }
                        Text("Drag the dot to where the camera should look.").font(.caption).foregroundStyle(.secondary)
                    } else {
                        Text("Follows your clicks and the cursor.").font(.caption).foregroundStyle(.secondary)
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Level")
                        Spacer()
                        Text(String(format: "%.1f×", segment.scale)).monospacedDigit().foregroundStyle(.secondary)
                    }
                    Slider(value: Binding(get: { segment.scale }, set: { model.setLevel(($0 * 10).rounded() / 10) }), in: 1...4)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Timing")
                    Text("\(clock(segment.start)) to \(clock(segment.end))")
                        .font(.system(size: 12, design: .monospaced)).foregroundStyle(.secondary)
                }

                Button("Remove Zoom", role: .destructive) { model.removeSelected() }
            } else {
                Text("Select a zoom on the timeline to change it, or double-click an empty spot to add one.")
                    .font(.callout).foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 6) {
                    shortcut("Space", "Play or pause")
                    shortcut("1-9", "Zoom level 1.0× to 2.6×")
                    shortcut("⌫", "Remove the selected zoom")
                    shortcut("⌘E", "Export")
                }
                .font(.caption)
            }
            Spacer()
        }
        .padding(16)
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private func shortcut(_ keys: String, _ what: String) -> some View {
        HStack {
            Text(keys).font(.system(size: 11, design: .monospaced)).padding(.horizontal, 5).padding(.vertical, 1)
                .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 4))
            Text(what).foregroundStyle(.secondary)
        }
    }
}

/// A still of the recording with a dot for the manual focus point, in fractions of the frame.
private struct FocusPicker: View {
    let image: CGImage?
    let focus: CGPoint
    let change: (CGPoint) -> Void

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            ZStack(alignment: .topLeading) {
                if let image {
                    Image(decorative: image, scale: 1).resizable()
                } else {
                    Rectangle().fill(.white.opacity(0.05))
                }
                Circle().strokeBorder(.white, lineWidth: 2).background(Circle().fill(Brand.orange))
                    .frame(width: 14, height: 14)
                    .shadow(radius: 2)
                    .position(x: focus.x * size.width, y: focus.y * size.height)
            }
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0).onEnded { value in
                change(CGPoint(x: min(max(value.location.x / size.width, 0), 1), y: min(max(value.location.y / size.height, 0), 1)))
            })
        }
        .aspectRatio(model: image)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

private extension View {
    func aspectRatio(model image: CGImage?) -> some View {
        aspectRatio(image.map { CGFloat($0.width) / CGFloat($0.height) } ?? 16 / 10, contentMode: .fit)
    }
}

private struct ZoomTimelineView: View {
    @ObservedObject var model: EditorModel
    @State private var dragOrigin: (start: Double, end: Double)?

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let x = { (t: Double) in CGFloat(t / max(model.duration, 0.001)) * width }
            let t = { (x: CGFloat) in Double(x / width) * model.duration }

            VStack(alignment: .leading, spacing: 6) {
                ruler(width: width, x: x)
                    .contentShape(Rectangle())
                    .gesture(DragGesture(minimumDistance: 0).onChanged { model.seek(to: t($0.location.x)) })
                Text("Zooms").font(.system(size: 11)).foregroundStyle(.secondary)
                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 8).fill(.white.opacity(0.035))
                        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.white.opacity(0.08)))
                        .contentShape(Rectangle())
                        .gesture(
                            SpatialTapGesture(count: 2).onEnded { model.addZoom(at: t($0.location.x)) }
                                .exclusively(before: SpatialTapGesture().onEnded {
                                    model.selection = nil
                                    model.seek(to: t($0.location.x))
                                })
                        )
                    ForEach(Array(model.timeline.segments.enumerated()), id: \.offset) { index, segment in
                        block(index, segment, x: x, t: t)
                    }
                    ForEach(model.clickTimes, id: \.self) { click in
                        Rectangle().fill(.white.opacity(0.85)).frame(width: 7, height: 7).rotationEffect(.degrees(45))
                            .position(x: x(click), y: 44)
                            .allowsHitTesting(false)
                    }
                }
                .frame(height: 56)
                if let waveform = model.waveform {
                    Text("Audio").font(.system(size: 11)).foregroundStyle(.secondary)
                    WaveformView(peaks: waveform)
                        .frame(height: 30)
                        .contentShape(Rectangle())
                        .gesture(DragGesture(minimumDistance: 0).onChanged { model.seek(to: t($0.location.x)) })
                }
                Spacer(minLength: 0)
            }
            .overlay(alignment: .topLeading) {
                Rectangle().fill(.white).frame(width: 2).shadow(color: .white.opacity(0.6), radius: 4)
                    .offset(x: x(model.time) - 1)
                    .allowsHitTesting(false)
            }
        }
    }

    private func ruler(width: CGFloat, x: @escaping (Double) -> CGFloat) -> some View {
        let step = [1.0, 2, 5, 10, 15, 30, 60, 120].first { model.duration / $0 <= 12 } ?? 300
        return ZStack(alignment: .topLeading) {
            Color.clear
            ForEach(Array(stride(from: 0.0, through: model.duration, by: step)), id: \.self) { mark in
                Text(mark < 60 ? "\(Int(mark))s" : "\(Int(mark) / 60):\(String(format: "%02d", Int(mark) % 60))")
                    .font(.system(size: 10, design: .monospaced)).foregroundStyle(.secondary)
                    .offset(x: x(mark))
            }
        }
        .frame(height: 16)
    }

    private func block(_ index: Int, _ segment: ZoomSegment, x: (Double) -> CGFloat, t: @escaping (CGFloat) -> Double) -> some View {
        let selected = model.selection == index
        let left = x(segment.start), blockWidth = max(x(segment.end) - x(segment.start), 6)
        return ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 7)
                .fill(LinearGradient(colors: [Brand.orange.opacity(0.75), Brand.orange.opacity(0.5)], startPoint: .top, endPoint: .bottom))
                .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(selected ? .white : Color(rgb: 0xFFD3A1).opacity(0.5), lineWidth: selected ? 2 : 1))
            if blockWidth > 70 {
                HStack(spacing: 5) {
                    Text(String(format: "%.1f×", segment.scale)).font(.system(size: 12, weight: .semibold))
                    Text(segment.focus == nil ? "auto" : "manual").font(.system(size: 11)).opacity(0.75)
                }
                .padding(.leading, 12)
                .lineLimit(1)
            }
            HStack {
                handle(index, isStart: true, t: t)
                Spacer(minLength: 0)
                handle(index, isStart: false, t: t)
            }
        }
        .frame(width: blockWidth, height: 44)
        .offset(x: left, y: 6)
        .contentShape(Rectangle())
        .onTapGesture { model.selection = index }
        .gesture(DragGesture(minimumDistance: 3)
            .onChanged { value in
                model.selection = index
                let origin = dragOrigin ?? (segment.start, segment.end)
                dragOrigin = origin
                model.move(index, to: origin.start + t(value.translation.width))
            }
            .onEnded { _ in
                dragOrigin = nil
                model.finishDrag()
            })
        .help("Drag to move, drag an edge to resize")
    }

    private func handle(_ index: Int, isStart: Bool, t: @escaping (CGFloat) -> Double) -> some View {
        RoundedRectangle(cornerRadius: 2).fill(.white.opacity(0.85))
            .frame(width: 4, height: 24)
            .padding(.horizontal, 4)
            .frame(width: 12, height: 44)
            .contentShape(Rectangle())
            .onHover { inside in (inside ? NSCursor.resizeLeftRight : NSCursor.arrow).set() }
            .gesture(DragGesture(minimumDistance: 1)
                .onChanged { value in
                    model.selection = index
                    let segment = model.timeline.segments[index]
                    let origin = dragOrigin ?? (segment.start, segment.end)
                    dragOrigin = origin
                    if isStart {
                        model.setStart(index, to: origin.start + t(value.translation.width))
                    } else {
                        model.setEnd(index, to: origin.end + t(value.translation.width))
                    }
                }
                .onEnded { _ in
                    dragOrigin = nil
                    model.finishDrag()
                })
    }
}

/// Bars for the loudest moment in each slice of the mix, mirrored around the middle and scaled
/// to the loudest one so quiet recordings still read.
private struct WaveformView: View {
    let peaks: [Float]

    var body: some View {
        Canvas { context, size in
            guard !peaks.isEmpty else { return }
            let step = size.width / CGFloat(peaks.count)
            let loudest = CGFloat(max(peaks.max() ?? 1, 0.05))
            var bars = Path()
            for (index, peak) in peaks.enumerated() {
                let height = max(CGFloat(peak) / loudest * size.height, 1)
                bars.addRect(CGRect(x: CGFloat(index) * step, y: (size.height - height) / 2, width: max(step - 0.5, 0.5), height: height))
            }
            context.fill(bars, with: .color(Color(rgb: 0xFFD3A1).opacity(0.55)))
        }
        .background(RoundedRectangle(cornerRadius: 8).fill(.white.opacity(0.035)))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
