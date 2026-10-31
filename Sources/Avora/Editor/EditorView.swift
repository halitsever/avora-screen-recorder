import SwiftUI
import ZoomEngine

struct EditorView: View {
    @ObservedObject var model: EditorModel
    @State private var cropping = false

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
                Inspector(model: model)
                    .frame(width: 270)
            }
            Divider().overlay(Color.white.opacity(0.06))
            TimelineView(model: model)
                .frame(height: (model.waveform == nil ? 298 : 348) + (model.hasCamera ? 52 : 0) + (model.hasCaptions ? 52 : 0)
                    + LaneView.height(.masks, rows: LaneView.rows(model.spans(in: .masks)).count) - 34)
                .padding(.horizontal, 18).padding(.vertical, 12)
        }
        .background(Brand.ink)
        .foregroundStyle(Color(white: 0.93))
        .tint(Brand.orange)
        .preferredColorScheme(.dark)
        .sheet(isPresented: $cropping) { CropSheet(model: model, isPresented: $cropping) }
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
            ControlGroup {
                Button { model.undo() } label: { Image(systemName: "arrow.uturn.backward") }
                    .disabled(!model.canUndo).help("Undo (⌘Z)")
                Button { model.redo() } label: { Image(systemName: "arrow.uturn.forward") }
                    .disabled(!model.canRedo).help("Redo (⇧⌘Z)")
            }
            .fixedSize()
            Button { Task { await model.generateCaptions() } } label: {
                if model.isTranscribing {
                    ProgressView().controlSize(.small)
                } else {
                    Label(model.hasCaptions ? "Redo Captions" : "Generate Captions", systemImage: "captions.bubble")
                }
            }
            .disabled(model.isTranscribing)
            .help("Turn what was said into captions, on this Mac")
            if !model.typing.isEmpty {
                Button { model.speedUpTyping() } label: { Label("Speed Up Typing", systemImage: "keyboard") }
                    .help("Play every stretch of steady typing at 3×")
            }
            if let progress = model.scanProgress {
                ProgressView(value: progress).frame(width: 80)
                Text("Scanning \(Int(progress * 100))%").font(.system(size: 12)).monospacedDigit()
            } else {
                Menu {
                    Button("Blur Private Info") { Task { await model.blurAutomatically(.text) } }
                    Button("Blur Faces") { Task { await model.blurAutomatically(.faces) } }
                } label: {
                    Label("Auto Blur", systemImage: "eye.slash")
                }
                .fixedSize()
                .help("Find email addresses, phone and card numbers, IBANs, keys or faces on screen and blur them")
            }
            Button { model.splitAtPlayhead() } label: { Label("Split", systemImage: "scissors") }
                .help("Split the clip at the playhead (S)")
            Button { cropping = true } label: { Label(model.crop == nil ? "Crop" : "Cropped", systemImage: "crop") }
                .help("Keep only part of the recording")
            Button("Reset Zooms") { model.resetZooms() }
                .help("Go back to the zooms made from your clicks")
            if let progress = model.exportProgress {
                ProgressView(value: progress).frame(width: 120)
                Text("Exporting \(Int(progress * 100))%").font(.system(size: 12)).monospacedDigit()
            } else {
                Menu {
                    Button("Export and Copy") { Task { await model.export(copy: true) } }
                    Divider()
                    Button("Copy Frame") { Task { await model.copyFrame() } }
                    Button("Save Frame…") { Task { await model.saveFrame() } }
                } label: {
                    Text("Export")
                } primaryAction: {
                    Task { await model.export(copy: false) }
                }
                .menuStyle(.borderedButton)
                .fixedSize()
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
            Text("\(clock(model.videoTime)) / \(clock(model.clips.outputDuration))")
                .font(.system(size: 12, design: .monospaced)).foregroundStyle(.secondary)
            Spacer()
            if let index = model.zooms.index(at: model.time) {
                Text(String(format: "zoom %.1f×", model.zooms.segments[index].scale))
                    .font(.system(size: 12, design: .monospaced)).foregroundStyle(.secondary)
            }
        }
    }
}

func clock(_ seconds: Double) -> String {
    let whole = Int(seconds)
    return String(format: "%d:%02d.%02d", whole / 60, whole % 60, Int((seconds - Double(whole)) * 100))
}

private struct Inspector: View {
    @ObservedObject var model: EditorModel
    @State private var still: CGImage?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            switch model.selection?.lane {
            case .clips?: clipDetails
            case .zooms?: zoomDetails
            case .cursor?: cursorDetails
            case .camera?: cameraDetails
            case .masks?: maskDetails
            case .captions?: captionDetails
            case nil: help
            }
            Spacer()
        }
        .padding(16)
        .frame(maxHeight: .infinity, alignment: .top)
    }

    @ViewBuilder private var zoomDetails: some View {
        if let index = model.selection?.index, let segment = model.selectedZoom {
            heading("ZOOM \(index + 1) OF \(model.zooms.segments.count)")

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
                    caption("Drag the dot to where the camera should look.")
                } else {
                    caption("Follows your clicks and the cursor.")
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

            timing(segment.start, segment.end)
            Button("Remove Zoom", role: .destructive) { model.removeSelected() }
        }
    }

    @ViewBuilder private var clipDetails: some View {
        if let index = model.selection?.index, let clip = model.selectedClip {
            heading("CLIP \(index + 1) OF \(model.clips.segments.count)")
            VStack(alignment: .leading, spacing: 8) {
                Text("Speed")
                Picker("Speed", selection: Binding(get: { clip.speed }, set: { model.setSpeed($0) })) {
                    ForEach(EditorModel.speeds, id: \.self) { Text(String(format: "%g×", $0)).tag($0) }
                }
                .labelsHidden()
                caption("Voices keep their pitch at any speed.")
            }
            timing(clip.start, clip.end)
            caption(String(format: "Plays for %@ in the video.", clock(clip.outputLength)))
            Button("Split at Playhead") { model.splitAtPlayhead() }
            Button("Cut This Clip", role: .destructive) { model.removeSelected() }
                .disabled(model.clips.segments.count == 1)
        }
    }

    @ViewBuilder private var cursorDetails: some View {
        if let index = model.selection?.index, model.cursorHidden.segments.indices.contains(index) {
            let range = model.cursorHidden.segments[index]
            heading("CURSOR HIDDEN")
            caption("The cursor and its click effects are left out of the video here.")
            timing(range.start, range.end)
            Button("Show Cursor Again", role: .destructive) { model.removeSelected() }
        }
    }

    @ViewBuilder private var cameraDetails: some View {
        if let span = model.selectedCameraSpan {
            heading("CAMERA")
            Picker("Layout", selection: Binding(get: { span.layout }, set: { model.setCameraLayout($0) })) {
                Text("Hidden").tag(CameraSpan.Layout.hidden)
                Text("Side by Side").tag(CameraSpan.Layout.split)
                Text("Full Screen").tag(CameraSpan.Layout.full)
            }
            .pickerStyle(.segmented).labelsHidden()
            caption(span.layout.explanation)
            timing(span.start, span.end)
            Button("Back to Bubble", role: .destructive) { model.removeSelected() }
        }
    }

    @ViewBuilder private var maskDetails: some View {
        if let index = model.selection?.index, let mask = model.selectedMask {
            heading("MASK \(index + 1) OF \(model.masks.segments.count)")
            Picker("Kind", selection: Binding(get: { mask.kind }, set: { model.setMask(kind: $0) })) {
                Text("Blur").tag(Mask.Kind.blur)
                Text("Highlight").tag(Mask.Kind.highlight)
            }
            .pickerStyle(.segmented).labelsHidden()
            RectEditor(image: still, rect: Binding(get: { mask.rect }, set: { model.setMask(rect: $0) }))
                .task(id: mask.start) { still = await model.still(at: (mask.start + mask.end) / 2) }
            caption(mask.kind == .blur ? "Drag or resize the box over anything private." : "Everything outside the box dims.")
            timing(mask.start, mask.end)
            Button("Remove Mask", role: .destructive) { model.removeSelected() }
        }
    }

    @ViewBuilder private var captionDetails: some View {
        if let line = model.selectedCaption {
            heading("CAPTION")
            TextField("Caption", text: Binding(get: { line.text }, set: { model.setCaptionText($0) }), axis: .vertical)
                .lineLimit(2...5)
                .textFieldStyle(.roundedBorder)
            caption(line.text.isEmpty ? "An empty caption shows nothing." : "Shown when captions are burned in, and written to the .srt file.")
            timing(line.start, line.end)
            Button("Remove Caption", role: .destructive) { model.removeSelected() }
        }
    }

    private var help: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Select something on the timeline to change it, or double-click an empty spot in a row to add to it.")
                .font(.callout).foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 6) {
                shortcut("Space", "Play or pause")
                shortcut("S", "Split the clip at the playhead")
                shortcut("1-9", "Zoom level 1.0× to 2.6×")
                shortcut("⌫", "Remove the selection")
                shortcut("⌘Z", "Undo, ⇧⌘Z redo")
                shortcut("⌘E", "Export")
            }
            .font(.caption)
        }
    }

    private func heading(_ text: String) -> some View {
        Text(text).font(.system(size: 11, weight: .semibold)).tracking(0.6).foregroundStyle(.secondary)
    }

    private func caption(_ text: String) -> some View {
        Text(text).font(.caption).foregroundStyle(.secondary)
    }

    private func timing(_ start: Double, _ end: Double) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Timing")
            Text("\(clock(start)) to \(clock(end))").font(.system(size: 12, design: .monospaced)).foregroundStyle(.secondary)
        }
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
        .aspectRatio(image.map { CGFloat($0.width) / CGFloat($0.height) } ?? 16 / 10, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

private struct TimelineView: View {
    @ObservedObject var model: EditorModel

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let x = { (t: Double) in CGFloat(t / max(model.duration, 0.001)) * width }
            let t = { (x: CGFloat) in Double(x / width) * model.duration }

            VStack(alignment: .leading, spacing: 6) {
                ruler(x: x)
                    .contentShape(Rectangle())
                    .gesture(DragGesture(minimumDistance: 0).onChanged { model.seek(to: t($0.location.x)) })
                LaneView(model: model, lane: .clips, title: "Clips", x: x, t: t)
                LaneView(model: model, lane: .zooms, title: "Zooms", x: x, t: t)
                LaneView(model: model, lane: .cursor, title: "Cursor hidden", x: x, t: t)
                if model.hasCamera {
                    LaneView(model: model, lane: .camera, title: "Camera", x: x, t: t)
                }
                LaneView(model: model, lane: .masks, title: "Masks", x: x, t: t)
                if model.hasCaptions {
                    LaneView(model: model, lane: .captions, title: "Captions", x: x, t: t)
                }
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

    private func ruler(x: @escaping (Double) -> CGFloat) -> some View {
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
}

/// One row of blocks. Blocks move by dragging, resize by their edges, and double-clicking an
/// empty spot adds one.
struct LaneView: View {
    @ObservedObject var model: EditorModel
    let lane: Lane
    let title: String
    let x: (Double) -> CGFloat
    let t: (CGFloat) -> Double
    @State private var dragOrigin: (start: Double, end: Double)?

    private var rows: (of: [Int], count: Int) { Self.rows(model.spans(in: lane)) }
    private var slot: CGFloat { Self.slot(lane, rows: rows.count) }
    private var height: CGFloat { Self.height(lane, rows: rows.count) }

    /// Overlapping blurs stack in rows so each one can still be grabbed.
    static func rows(_ spans: [(start: Double, end: Double)]) -> (of: [Int], count: Int) {
        var rows: [[(start: Double, end: Double)]] = []
        var assigned: [Int] = []
        for span in spans {
            let row = rows.firstIndex { $0.allSatisfy { $0.end <= span.start || $0.start >= span.end } } ?? rows.count
            if row == rows.count { rows.append([]) }
            rows[row].append(span)
            assigned.append(row)
        }
        return (assigned, max(rows.count, 1))
    }

    static func slot(_ lane: Lane, rows: Int) -> CGFloat {
        if lane == .zooms { return 44 }
        return rows == 1 ? 22 : max(5, min(18, (110 - 2 * CGFloat(rows - 1)) / CGFloat(rows)))
    }

    static func height(_ lane: Lane, rows: Int) -> CGFloat {
        12 + slot(lane, rows: rows) * CGFloat(rows) + 2 * CGFloat(rows - 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.system(size: 11)).foregroundStyle(.secondary)
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 8).fill(.white.opacity(0.035))
                    .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.white.opacity(0.08)))
                    .contentShape(Rectangle())
                    .gesture(
                        SpatialTapGesture(count: 2).onEnded { model.add(in: lane, at: t($0.location.x)) }
                            .exclusively(before: SpatialTapGesture().onEnded {
                                model.selection = nil
                                model.seek(to: t($0.location.x))
                            })
                    )
                let layout = rows
                ForEach(Array(model.spans(in: lane).enumerated()), id: \.offset) { index, span in
                    block(LaneSelection(lane: lane, index: index), span, row: layout.of[safe: index] ?? 0)
                }
                if lane == .zooms {
                    ForEach(model.clickTimes, id: \.self) { click in
                        Rectangle().fill(.white.opacity(0.85)).frame(width: 7, height: 7).rotationEffect(.degrees(45))
                            .position(x: x(click), y: height - 12)
                            .allowsHitTesting(false)
                    }
                }
            }
            .frame(height: height)
        }
    }

    private var color: Color {
        switch lane {
        case .clips: Color(rgb: 0x4F8F66)
        case .zooms: Brand.orange
        case .cursor: Color(rgb: 0x8E8E9A)
        case .camera: Color(rgb: 0x6E7FD6)
        case .masks: Color(rgb: 0xB06AD6)
        case .captions: Color(rgb: 0x3E9FB4)
        }
    }

    private func label(_ target: LaneSelection) -> (String, String)? {
        switch lane {
        case .clips:
            guard model.clips.segments.indices.contains(target.index) else { return nil }
            let speed = model.clips.segments[target.index].speed
            return (String(format: "%g×", speed), speed == 1 ? "" : "speed")
        case .zooms:
            guard model.zooms.segments.indices.contains(target.index) else { return nil }
            let segment = model.zooms.segments[target.index]
            return (String(format: "%.1f×", segment.scale), segment.focus == nil ? "auto" : "manual")
        case .cursor:
            return ("hidden", "")
        case .camera:
            guard model.camera.segments.indices.contains(target.index) else { return nil }
            return (model.camera.segments[target.index].layout.name, "")
        case .masks:
            guard model.masks.segments.indices.contains(target.index) else { return nil }
            return (model.masks.segments[target.index].kind == .blur ? "blur" : "highlight", "")
        case .captions:
            guard model.captions.segments.indices.contains(target.index) else { return nil }
            return (model.captions.segments[target.index].text, "")
        }
    }

    private func block(_ target: LaneSelection, _ span: (start: Double, end: Double), row: Int) -> some View {
        let selected = model.selection == target
        let left = x(span.start), blockWidth = max(x(span.end) - x(span.start), 6)
        return ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 7)
                .fill(LinearGradient(colors: [color.opacity(0.75), color.opacity(0.5)], startPoint: .top, endPoint: .bottom))
                .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(selected ? .white : .white.opacity(0.25), lineWidth: selected ? 2 : 1))
            if blockWidth > 70, slot >= 16, let (main, detail) = label(target) {
                HStack(spacing: 5) {
                    Text(main).font(.system(size: 12, weight: .semibold))
                    Text(detail).font(.system(size: 11)).opacity(0.75)
                }
                .padding(.leading, 12)
                .lineLimit(1)
            }
            HStack {
                handle(target, isStart: true)
                Spacer(minLength: 0)
                handle(target, isStart: false)
            }
        }
        .frame(width: blockWidth, height: slot)
        .offset(x: left, y: 6 + CGFloat(row) * (slot + 2))
        .contentShape(Rectangle())
        .onTapGesture { model.selection = target }
        .gesture(DragGesture(minimumDistance: 3)
            .onChanged { value in
                model.selection = target
                let origin = dragOrigin ?? (span.start, span.end)
                dragOrigin = origin
                model.move(target, to: origin.start + t(value.translation.width))
            }
            .onEnded { _ in
                dragOrigin = nil
                model.finishDrag()
            })
        .help(lane == .clips ? "Drag an edge to trim" : "Drag to move, drag an edge to resize")
    }

    private func handle(_ target: LaneSelection, isStart: Bool) -> some View {
        RoundedRectangle(cornerRadius: 2).fill(.white.opacity(0.85))
            .frame(width: 4, height: min(slot - 6, lane == .zooms ? 24 : 14))
            .padding(.horizontal, 4)
            .frame(width: 12, height: slot)
            .contentShape(Rectangle())
            .onHover { inside in (inside ? NSCursor.resizeLeftRight : NSCursor.arrow).set() }
            .gesture(DragGesture(minimumDistance: 1)
                .onChanged { value in
                    model.selection = target
                    guard let span = model.spans(in: lane)[safe: target.index] else { return }
                    let origin = dragOrigin ?? (span.start, span.end)
                    dragOrigin = origin
                    if isStart {
                        model.setStart(target, to: origin.start + t(value.translation.width))
                    } else {
                        model.setEnd(target, to: origin.end + t(value.translation.width))
                    }
                }
                .onEnded { _ in
                    dragOrigin = nil
                    model.finishDrag()
                })
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? { indices.contains(index) ? self[index] : nil }
}

private extension CameraSpan.Layout {
    var name: String {
        switch self {
        case .hidden: "hidden"
        case .split: "side by side"
        case .full: "full screen"
        }
    }

    var explanation: String {
        switch self {
        case .hidden: "The camera fades out here and back in at the end."
        case .split: "Screen and camera sit next to each other, or stacked in a tall video. Zooms stay inside the screen's card."
        case .full: "The camera fills the whole video, then goes back to its bubble."
        }
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

/// A still of the recording with a rectangle to drag and resize. Fractions use a top-left origin.
struct RectEditor: View {
    let image: CGImage?
    @Binding var rect: CGRect
    var minimum = 0.05
    @State private var origin: CGRect?

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let hole = CGRect(x: rect.minX * size.width, y: rect.minY * size.height, width: rect.width * size.width, height: rect.height * size.height)
            ZStack(alignment: .topLeading) {
                if let image { Image(decorative: image, scale: 1).resizable() } else { Color.white.opacity(0.05) }
                Path { path in
                    path.addRect(CGRect(origin: .zero, size: size))
                    path.addRect(hole)
                }
                .fill(Color.black.opacity(0.55), style: FillStyle(eoFill: true))
                Rectangle().strokeBorder(Brand.orange, lineWidth: 2)
                    .frame(width: hole.width, height: hole.height)
                    .offset(x: hole.minX, y: hole.minY)
                    .contentShape(Rectangle())
                    .gesture(drag(size: size) { start, dx, dy in
                        CGRect(x: min(max(start.minX + dx, 0), 1 - start.width), y: min(max(start.minY + dy, 0), 1 - start.height),
                               width: start.width, height: start.height)
                    })
                ForEach(0..<4, id: \.self) { corner in
                    let left = corner % 2 == 0, top = corner < 2
                    Circle().fill(.white).frame(width: 12, height: 12).shadow(radius: 2)
                        .position(x: left ? hole.minX : hole.maxX, y: top ? hole.minY : hole.maxY)
                        .gesture(drag(size: size) { start, dx, dy in resize(start, dx: dx, dy: dy, left: left, top: top) })
                }
            }
        }
        .aspectRatio(image.map { CGFloat($0.width) / CGFloat($0.height) } ?? 16 / 10, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private func drag(size: CGSize, _ update: @escaping (CGRect, Double, Double) -> CGRect) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let start = origin ?? rect
                origin = start
                rect = update(start, value.translation.width / size.width, value.translation.height / size.height)
            }
            .onEnded { _ in origin = nil }
    }

    private func resize(_ start: CGRect, dx: Double, dy: Double, left: Bool, top: Bool) -> CGRect {
        var minX = start.minX, minY = start.minY, maxX = start.maxX, maxY = start.maxY
        if left { minX = min(max(minX + dx, 0), maxX - minimum) } else { maxX = max(min(maxX + dx, 1), minX + minimum) }
        if top { minY = min(max(minY + dy, 0), maxY - minimum) } else { maxY = max(min(maxY + dy, 1), minY + minimum) }
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
}

/// Picks the part of the recording to keep.
private struct CropSheet: View {
    @ObservedObject var model: EditorModel
    @Binding var isPresented: Bool
    @State private var image: CGImage?
    @State private var rect = CGRect(x: 0, y: 0, width: 1, height: 1)

    var body: some View {
        VStack(spacing: 14) {
            Text("Crop the recording").font(.headline)
            RectEditor(image: image, rect: $rect, minimum: 0.1).frame(width: 720)
            HStack {
                Button("Reset") { rect = CGRect(x: 0, y: 0, width: 1, height: 1) }
                Spacer()
                Button("Cancel") { isPresented = false }.keyboardShortcut(.cancelAction)
                Button("Done") {
                    model.setCrop(rect)
                    isPresented = false
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 760)
        .task {
            rect = model.crop ?? CGRect(x: 0, y: 0, width: 1, height: 1)
            image = await model.still(at: model.time, maxSide: 1440)
        }
    }
}
