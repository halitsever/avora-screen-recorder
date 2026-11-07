import AppKit
import SwiftUI
import ZoomEngine

/// Sizes shared by the lane titles and the lanes, so the two columns line up.
enum TimelineMetrics {
    static let headerWidth: CGFloat = 132
    static let toolbarHeight: CGFloat = 26
    static let rulerHeight: CGFloat = 24
    static let spacing: CGFloat = 6
    static let audioHeight: CGFloat = 40
    static let scrollerHeight: CGFloat = 8

    static func slot(_ lane: Lane, rows: Int) -> CGFloat {
        let single: CGFloat = switch lane {
        case .zooms: 40
        case .clips: 32
        default: 26
        }
        return rows == 1 ? single : max(6, min(20, (100 - 2 * CGFloat(rows - 1)) / CGFloat(rows)))
    }

    static func height(_ lane: Lane, rows: Int) -> CGFloat {
        8 + slot(lane, rows: rows) * CGFloat(rows) + 2 * CGFloat(rows - 1) + (lane == .zooms ? clickStrip : 0)
    }

    /// Room under the zooms for the click marks, so they never sit on a block's grip.
    static let clickStrip: CGFloat = 10

    /// Overlapping masks stack in rows so each one can still be grabbed.
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
}

extension Lane {
    var title: String {
        switch self {
        case .clips: "Clips"
        case .zooms: "Zooms"
        case .cursor: "Cursor hidden"
        case .camera: "Camera"
        case .masks: "Blur & highlight"
        case .captions: "Captions"
        }
    }

    var addTitle: String {
        switch self {
        case .clips: "Restore Cut Part"
        case .zooms: "Add Zoom"
        case .cursor: "Hide Cursor"
        case .camera: "Add Camera Layout"
        case .masks: "Add Blur"
        case .captions: "Add Caption"
        }
    }

    var color: Color {
        switch self {
        // Tailwind's 500 shades, which shadcn/ui's charts use too.
        case .clips: Color(rgb: 0x10B981)
        case .zooms: Color(rgb: 0x3B82F6)
        case .cursor: Color(rgb: 0x71717A)
        case .camera: Color(rgb: 0xF59E0B)
        case .masks: Color(rgb: 0x8B5CF6)
        case .captions: Color(rgb: 0xF43F5E)
        }
    }
}

/// Clicking the timeline should leave text fields, so Delete and Space reach the editor again.
@MainActor
func endTextEditing() {
    NSApp.keyWindow?.makeFirstResponder(nil)
}

struct EditorTimeline: View {
    @ObservedObject var model: EditorModel
    @ObservedObject private var viewport: TimelineViewport
    @AppStorage("editorSnapping") private var snapping = true

    init(model: EditorModel) {
        self.model = model
        viewport = model.viewport
    }

    private var lanes: [Lane] {
        [.clips, .zooms, .cursor] + (model.hasCamera ? [.camera] : []) + [.masks, .captions]
    }

    private func laneHeight(_ lane: Lane) -> CGFloat {
        TimelineMetrics.height(lane, rows: TimelineMetrics.rows(model.spans(in: lane)).count)
    }

    private var tracksHeight: CGFloat {
        let rows = [TimelineMetrics.rulerHeight] + lanes.map(laneHeight) + (model.waveform == nil ? [] : [TimelineMetrics.audioHeight])
            + [TimelineMetrics.scrollerHeight]
        return rows.reduce(0, +) + TimelineMetrics.spacing * CGFloat(rows.count - 1)
    }

    var body: some View {
        VStack(spacing: 8) {
            toolbar.frame(height: TimelineMetrics.toolbarHeight)
            HStack(alignment: .top, spacing: 10) {
                headers.frame(width: TimelineMetrics.headerWidth)
                GeometryReader { proxy in
                    ZStack(alignment: .topLeading) {
                        tracks(width: proxy.size.width)
                        ScrollCatcher(area: proxy.frame(in: .global)) { event, point in scroll(event, at: point, width: proxy.size.width) }
                            .frame(width: 0, height: 0)
                    }
                }
            }
            .frame(height: tracksHeight)
        }
        .onChange(of: model.time) { _, time in viewport.reveal(time) }
    }

    // MARK: Toolbar

    private var toolbar: some View {
        HStack(spacing: 8) {
            Menu {
                ForEach(lanes.filter { $0 != .clips }, id: \.self) { lane in
                    Button(lane.addTitle) { add(lane) }
                }
            } label: {
                Label("Add at Playhead", systemImage: "plus")
            }
            .fixedSize()
            Button { model.splitAtPlayhead() } label: { Label("Split", systemImage: "scissors") }
                .help("Split the clip at the playhead (S)")
            Button { model.removeSelected() } label: { Label("Delete", systemImage: "trash") }
                .disabled(model.selection == nil)
                .help("Delete the selection (⌫)")
            Spacer()
            Toggle("Snap", isOn: $snapping)
                .toggleStyle(.button)
                .help("Snap edges to the playhead and to other blocks")
            Divider().frame(height: 16)
            Button { viewport.zoom(by: 1 / 1.6, around: model.time) } label: { Image(systemName: "minus.magnifyingglass") }
                .disabled(!viewport.isZoomed)
                .help("Zoom out (⌘−)")
            Slider(value: Binding(get: { log(viewport.zoom) }, set: { viewport.setZoom(exp($0), around: model.time) }),
                   in: 0...max(log(viewport.maxZoom), 0.01))
                .frame(width: 140)
                .help("Pinch, or scroll with ⌘ held, over the timeline to zoom")
            Button { viewport.zoom(by: 1.6, around: model.time) } label: { Image(systemName: "plus.magnifyingglass") }
                .disabled(viewport.zoom >= viewport.maxZoom)
                .help("Zoom in (⌘=)")
            Button("Fit") { viewport.fit() }
                .disabled(!viewport.isZoomed)
                .help("Show the whole recording (⌘0)")
        }
        .controlSize(.small)
    }

    private func add(_ lane: Lane) {
        endTextEditing()
        if !model.addAtPlayhead(in: lane) { NSSound.beep() }
    }

    // MARK: Lane titles

    private var headers: some View {
        VStack(alignment: .leading, spacing: TimelineMetrics.spacing) {
            Text(clock(model.time))
                .font(.system(size: 11, design: .monospaced)).foregroundStyle(.secondary)
                .frame(height: TimelineMetrics.rulerHeight)
            ForEach(lanes, id: \.self) { lane in
                HStack(spacing: 7) {
                    Circle().fill(lane.color).frame(width: 7, height: 7)
                    Text(lane.title).font(.system(size: 11.5)).foregroundStyle(.secondary).lineLimit(1)
                    Spacer(minLength: 0)
                    if lane == .clips {
                        Button { model.splitAtPlayhead() } label: { Image(systemName: "scissors") }
                            .help("Split at the playhead (S)")
                    } else {
                        Button { add(lane) } label: { Image(systemName: "plus") }
                            .help("\(lane.addTitle) at the playhead")
                    }
                }
                .buttonStyle(.borderless)
                .frame(height: laneHeight(lane))
            }
            if model.waveform != nil {
                HStack(spacing: 7) {
                    Circle().fill(Palette.muted).frame(width: 7, height: 7)
                    Text("Audio").font(.system(size: 11.5)).foregroundStyle(.secondary)
                }
                .frame(height: TimelineMetrics.audioHeight)
            }
        }
    }

    // MARK: Tracks

    private func tracks(width: CGFloat) -> some View {
        let seek = DragGesture(minimumDistance: 0).onChanged { value in
            endTextEditing()
            model.seek(to: viewport.time(atX: value.location.x, width: width))
        }
        return ZStack(alignment: .topLeading) {
            VStack(alignment: .leading, spacing: TimelineMetrics.spacing) {
                RulerView(start: viewport.start, span: viewport.span)
                    .frame(height: TimelineMetrics.rulerHeight)
                    .contentShape(Rectangle())
                    .gesture(seek)
                ForEach(lanes, id: \.self) { lane in
                    LaneTrack(model: model, viewport: viewport, lane: lane, width: width, snapping: snapping)
                }
                if let waveform = model.waveform {
                    WaveformTrack(peaks: waveform, start: viewport.start, span: viewport.span, duration: model.duration)
                        .frame(height: TimelineMetrics.audioHeight)
                        .contentShape(Rectangle())
                        .gesture(seek)
                }
                TimelineScroller(viewport: viewport, width: width)
                    .frame(height: TimelineMetrics.scrollerHeight)
            }
            cutShading(width: width)
            playhead(width: width)
        }
        .frame(width: width, alignment: .topLeading)
    }

    /// Parts that were cut stay on the timeline but are dimmed, since they leave the video.
    private func cutShading(width: CGFloat) -> some View {
        let height = tracksHeight - TimelineMetrics.rulerHeight - TimelineMetrics.scrollerHeight - 2 * TimelineMetrics.spacing
        let kept = model.clips.segments
        var gaps: [(Double, Double)] = []
        var cursor = 0.0
        for clip in kept {
            if clip.start > cursor + 1e-6 { gaps.append((cursor, clip.start)) }
            cursor = clip.end
        }
        if cursor < model.duration - 1e-6 { gaps.append((cursor, model.duration)) }
        return ForEach(Array(gaps.enumerated()), id: \.offset) { _, gap in
            let left = max(viewport.x(gap.0, width: width), 0), right = min(viewport.x(gap.1, width: width), width)
            if right > left {
                Rectangle().fill(.black.opacity(0.35))
                    .frame(width: right - left, height: height)
                    .offset(x: left, y: TimelineMetrics.rulerHeight + TimelineMetrics.spacing)
                    .allowsHitTesting(false)
            }
        }
    }

    @ViewBuilder private func playhead(width: CGFloat) -> some View {
        let x = viewport.x(model.time, width: width)
        if x >= -1, x <= width + 1 {
            ZStack(alignment: .top) {
                Rectangle().fill(.white).frame(width: 2).shadow(color: .white.opacity(0.5), radius: 3)
                UnevenRoundedRectangle(bottomLeadingRadius: 5, bottomTrailingRadius: 5)
                    .fill(.white).frame(width: 12, height: 14)
            }
            .frame(width: 12, height: tracksHeight - TimelineMetrics.scrollerHeight - TimelineMetrics.spacing)
            .offset(x: x - 6)
            .allowsHitTesting(false)
        }
    }

    /// Trackpad swipes and the wheel scroll the timeline; pinching or ⌘ with the wheel zooms it.
    private func scroll(_ event: NSEvent, at point: CGPoint, width: CGFloat) -> Bool {
        let anchor = viewport.time(atX: point.x, width: width)
        if event.type == .magnify {
            viewport.zoom(by: 1 + Double(event.magnification), around: anchor)
            return true
        }
        let precise = event.hasPreciseScrollingDeltas
        let dx = Double(event.scrollingDeltaX), dy = Double(event.scrollingDeltaY)
        if !event.modifierFlags.isDisjoint(with: [.command, .option]) {
            viewport.zoom(by: exp(dy * (precise ? 0.01 : 0.1)), around: anchor)
            return true
        }
        let delta = abs(dx) > abs(dy) ? dx : dy
        guard viewport.isZoomed, delta != 0 else { return false }
        viewport.scroll(by: -delta * (precise ? 1 : 12) * viewport.seconds(perPoint: width))
        return true
    }
}

/// One row of blocks, which move by their body and resize by their edges.
private struct LaneTrack: View {
    @ObservedObject var model: EditorModel
    @ObservedObject var viewport: TimelineViewport
    let lane: Lane
    let width: CGFloat
    let snapping: Bool
    @State private var drag: DragState?

    private struct DragState {
        var target: LaneSelection
        var start: Double
        var end: Double
        var moved = false
    }

    var body: some View {
        let spans = model.spans(in: lane)
        let layout = TimelineMetrics.rows(spans)
        let slot = TimelineMetrics.slot(lane, rows: layout.count)
        let height = TimelineMetrics.height(lane, rows: layout.count)
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 8).fill(Palette.surface.opacity(0.7))
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Palette.border))
                .contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 0).onChanged { value in
                    if value.translation == .zero {
                        endTextEditing()
                        model.selection = nil
                    }
                    model.seek(to: viewport.time(atX: value.location.x, width: width))
                })
                .simultaneousGesture(SpatialTapGesture(count: 2).onEnded { value in
                    model.add(in: lane, at: viewport.time(atX: value.location.x, width: width))
                    if model.selection?.lane != lane { NSSound.beep() }
                })
            if lane == .zooms {
                ClickMarks(times: model.clickTimes, start: viewport.start, span: viewport.span)
                    .frame(height: TimelineMetrics.clickStrip)
                    .offset(y: height - TimelineMetrics.clickStrip - 2)
                    .allowsHitTesting(false)
            }
            ForEach(spans.indices.filter { spans[$0].end >= viewport.start && spans[$0].start <= viewport.end }, id: \.self) { index in
                block(LaneSelection(lane: lane, index: index), spans[index], row: layout.of[safe: index] ?? 0, slot: slot)
            }
        }
        .frame(width: width, height: height)
        .coordinateSpace(name: Self.space)
    }

    static let space = "lane"

    private var tolerance: Double { 7 * viewport.seconds(perPoint: width) }

    private func block(_ target: LaneSelection, _ span: (start: Double, end: Double), row: Int, slot: CGFloat) -> some View {
        let selected = model.selection == target
        let rawLeft = viewport.x(span.start, width: width), rawRight = viewport.x(span.end, width: width)
        let left = max(rawLeft, 0), right = min(rawRight, width)
        let blockWidth = max(right - left, 4)
        let handleWidth = min(10, blockWidth / 3)
        return ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 6)
                .fill(lane.color.opacity(selected ? 0.9 : 0.62))
                .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(selected ? Palette.foreground : .white.opacity(0.16), lineWidth: selected ? 2 : 1))
            if blockWidth > 44, slot >= 16, let text = label(target, span: span, width: blockWidth) {
                Text(text)
                    .font(.system(size: 11.5, weight: .semibold))
                    .lineLimit(1)
                    .padding(.horizontal, handleWidth + 3)
            }
        }
        .frame(width: blockWidth, height: slot)
        .overlay(alignment: .leading) {
            if rawLeft >= -0.5 { edge(target, span, isStart: true, width: handleWidth, height: slot, selected: selected) }
        }
        .overlay(alignment: .trailing) {
            if rawRight <= width + 0.5 { edge(target, span, isStart: false, width: handleWidth, height: slot, selected: selected) }
        }
        .contentShape(Rectangle())
        .gesture(move(target, span))
        .simultaneousGesture(TapGesture(count: 2).onEnded { model.seek(to: span.start) })
        .contextMenu { menu(target, span) }
        .help(lane == .clips ? "Drag an edge to trim. Right-click for more." : "Drag to move, drag an edge to change the length. Right-click for more.")
        .position(x: left + blockWidth / 2, y: 4 + CGFloat(row) * (slot + 2) + slot / 2)
    }

    private func begin(_ target: LaneSelection, _ span: (start: Double, end: Double)) {
        guard drag?.target != target else { return }
        endTextEditing()
        model.selection = target
        drag = DragState(target: target, start: span.start, end: span.end)
    }

    private func finish() {
        if drag?.moved == true { model.finishDrag() }
        drag = nil
    }

    /// Measured in the lane, since the block moves under the pointer while it is dragged.
    private func move(_ target: LaneSelection, _ span: (start: Double, end: Double)) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named(LaneTrack.space))
            .onChanged { value in
                begin(target, span)
                // Clips keep their place in the recording; only their edges trim.
                guard lane != .clips, var state = drag else { return }
                if !state.moved, abs(value.translation.width) < 3 { return }
                state.moved = true
                drag = state
                var start = state.start + Double(value.translation.width) * viewport.seconds(perPoint: width)
                if snapping {
                    start = Snap.start(start, length: state.end - state.start, to: model.snapTimes(excluding: target), tolerance: tolerance)
                }
                model.move(target, to: start)
            }
            .onEnded { _ in finish() }
    }

    private func edge(_ target: LaneSelection, _ span: (start: Double, end: Double), isStart: Bool, width handleWidth: CGFloat,
                      height: CGFloat, selected: Bool) -> some View {
        EdgeHandle(width: handleWidth, height: height, highlighted: selected) { translation in
            begin(target, span)
            guard let state = drag else { return }
            drag?.moved = true
            var time = (isStart ? state.start : state.end) + Double(translation) * viewport.seconds(perPoint: width)
            if snapping { time = Snap.time(time, to: model.snapTimes(excluding: target), tolerance: tolerance) }
            if isStart { model.setStart(target, to: time) } else { model.setEnd(target, to: time) }
        } onEnd: {
            finish()
        }
    }

    private func label(_ target: LaneSelection, span: (start: Double, end: Double), width: CGFloat) -> String? {
        let length = width > 110 ? "  " + TimeText.seconds(span.end - span.start) : ""
        switch lane {
        case .clips:
            guard let clip = model.clips.segments[safe: target.index] else { return nil }
            return (clip.speed == 1 ? "Clip" : String(format: "%g× speed", clip.speed)) + length
        case .zooms:
            guard let zoom = model.zooms.segments[safe: target.index] else { return nil }
            return String(format: "%.1f×", zoom.scale) + (zoom.focus == nil ? "" : " pinned") + length
        case .cursor:
            return "Hidden" + length
        case .camera:
            return model.camera.segments[safe: target.index]?.layout.name
        case .masks:
            return model.masks.segments[safe: target.index].map { $0.kind == .blur ? "Blur" : "Highlight" }
        case .captions:
            return model.captions.segments[safe: target.index]?.text
        }
    }

    @ViewBuilder private func menu(_ target: LaneSelection, _ span: (start: Double, end: Double)) -> some View {
        Button("Go to Start") { model.seek(to: span.start) }
        Button("Go to End") { model.seek(to: span.end) }
        Divider()
        Button("Start at Playhead") { model.setTiming(target, start: model.time) }
        Button("End at Playhead") { model.setTiming(target, end: model.time) }
        Divider()
        switch lane {
        case .zooms:
            Menu("Level") {
                ForEach([1.25, 1.5, 2, 2.5, 3, 4], id: \.self) { level in
                    Button(String(format: "%g×", level)) {
                        model.selection = target
                        model.setLevel(level)
                    }
                }
            }
            if let zoom = model.zooms.segments[safe: target.index] {
                Button(zoom.focus == nil ? "Pin Focus" : "Follow the Cursor") {
                    model.selection = target
                    model.setFocus(zoom.focus == nil ? CGPoint(x: 0.5, y: 0.5) : nil)
                }
            }
        case .clips:
            Menu("Speed") {
                ForEach(EditorModel.speeds, id: \.self) { speed in
                    Button(String(format: "%g×", speed)) {
                        model.selection = target
                        model.setSpeed(speed)
                    }
                }
            }
            Button("Split at Playhead") { model.splitAtPlayhead() }
        case .masks:
            Button("Blur") {
                model.selection = target
                model.setMask(kind: .blur)
            }
            Button("Highlight") {
                model.selection = target
                model.setMask(kind: .highlight)
            }
        case .camera:
            ForEach([CameraSpan.Layout.hidden, .split, .full], id: \.self) { layout in
                Button(layout.title) {
                    model.selection = target
                    model.setCameraLayout(layout)
                }
            }
        case .cursor, .captions:
            EmptyView()
        }
        Divider()
        Button(lane == .clips ? "Cut This Clip" : "Delete", role: .destructive) {
            model.selection = target
            model.removeSelected()
        }
        .disabled(lane == .clips && model.clips.segments.count == 1)
    }
}

/// A grip on one edge of a block, wide enough to grab easily.
private struct EdgeHandle: View {
    let width: CGFloat
    let height: CGFloat
    let highlighted: Bool
    let onDrag: (CGFloat) -> Void
    let onEnd: () -> Void
    @State private var hovering = false
    @State private var active = false

    var body: some View {
        Color.clear
            .frame(width: width, height: height)
            .overlay(Capsule().fill(.white.opacity(hovering || active || highlighted ? 0.95 : 0.5))
                .frame(width: 3, height: max(height * 0.45, 4)))
            .contentShape(Rectangle())
            .onHover { inside in
                guard inside != hovering else { return }
                hovering = inside
                if inside { NSCursor.resizeLeftRight.push() } else { NSCursor.pop() }
            }
            .onDisappear { if hovering { NSCursor.pop() } }
            // Measured in the lane, since the grip itself moves with the edge it drags.
            .gesture(DragGesture(minimumDistance: 0, coordinateSpace: .named(LaneTrack.space))
                .onChanged { value in
                    active = true
                    onDrag(value.translation.width)
                }
                .onEnded { _ in
                    active = false
                    onEnd()
                })
    }
}

private struct RulerView: View {
    let start: Double
    let span: Double

    var body: some View {
        Canvas { context, size in
            let perSecond = Double(size.width) / max(span, 0.001)
            let steps = [0.1, 0.2, 0.5, 1, 2, 5, 10, 15, 30, 60, 120, 300, 600, 1800]
            let major = steps.first { $0 * perSecond >= 80 } ?? 3600
            let divisions = major * perSecond / 5 >= 8 ? 5 : 2
            let minor = major / Double(divisions)
            var ticks = Path()
            var index = Int(floor(start / minor))
            while Double(index) * minor <= start + span {
                let time = Double(index) * minor
                let x = CGFloat((time - start) * perSecond)
                let isMajor = index % divisions == 0
                ticks.move(to: CGPoint(x: x, y: size.height - (isMajor ? 9 : 4)))
                ticks.addLine(to: CGPoint(x: x, y: size.height))
                if isMajor, time >= 0 {
                    context.draw(Text(Self.label(time, step: major)).font(.system(size: 10, design: .monospaced)).foregroundStyle(Palette.muted),
                                 at: CGPoint(x: x + 3, y: 2), anchor: .topLeading)
                }
                index += 1
            }
            context.stroke(ticks, with: .color(Palette.muted.opacity(0.45)), lineWidth: 1)
        }
    }

    static func label(_ time: Double, step: Double) -> String {
        let whole = Int(time.rounded(.down))
        if step < 1 {
            let tenths = Int(((time - Double(whole)) * 10).rounded()) % 10
            return whole < 60 ? "\(whole).\(tenths)s" : String(format: "%d:%02d.%d", whole / 60, whole % 60, tenths)
        }
        let rounded = Int(time.rounded())
        return rounded < 60 ? "\(rounded)s" : String(format: "%d:%02d", rounded / 60, rounded % 60)
    }
}

/// Diamonds where the recording saw a click, which is what automatic zooms start from.
private struct ClickMarks: View {
    let times: [Double]
    let start: Double
    let span: Double

    var body: some View {
        Canvas { context, size in
            var marks = Path()
            for time in times where time >= start && time <= start + span {
                let x = CGFloat((time - start) / span) * size.width, y = size.height / 2
                marks.move(to: CGPoint(x: x, y: y - 4))
                marks.addLine(to: CGPoint(x: x + 4, y: y))
                marks.addLine(to: CGPoint(x: x, y: y + 4))
                marks.addLine(to: CGPoint(x: x - 4, y: y))
                marks.closeSubpath()
            }
            context.fill(marks, with: .color(Palette.muted))
        }
    }
}

/// The loudest moment in each slice of what is visible, mirrored around the middle.
private struct WaveformTrack: View {
    let peaks: [Float]
    let start: Double
    let span: Double
    let duration: Double

    var body: some View {
        Canvas { context, size in
            guard !peaks.isEmpty, size.width > 0 else { return }
            // Scaled to the loudest moment so quiet recordings still read.
            let loudest = CGFloat(max(peaks.max() ?? 1, 0.05))
            let perBucket = Double(peaks.count) / max(duration, 0.001)
            let bar: CGFloat = 2
            var bars = Path()
            var x: CGFloat = 0
            while x < size.width {
                let from = start + Double(x / size.width) * span, to = start + Double((x + bar) / size.width) * span
                let low = min(max(Int(from * perBucket), 0), peaks.count - 1)
                let high = min(max(Int((to * perBucket).rounded(.up)), low + 1), peaks.count)
                let peak = CGFloat(peaks[low..<high].max() ?? 0)
                let height = max(peak / loudest * size.height, 1)
                bars.addRect(CGRect(x: x, y: (size.height - height) / 2, width: bar - 0.5, height: height))
                x += bar
            }
            context.fill(bars, with: .color(Palette.muted.opacity(0.6)))
        }
        .background(RoundedRectangle(cornerRadius: 8).fill(Palette.surface.opacity(0.7)))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

/// Shows which part of the recording is in view once the timeline is zoomed in, and drags it along.
private struct TimelineScroller: View {
    @ObservedObject var viewport: TimelineViewport
    let width: CGFloat
    @State private var origin: Double?

    var body: some View {
        let thumb = max(CGFloat(viewport.span / viewport.duration) * width, 28)
        let travel = max(width - thumb, 1)
        let room = viewport.duration - viewport.span
        let x = room > 0 ? CGFloat(viewport.start / room) * travel : 0
        ZStack(alignment: .leading) {
            Capsule().fill(.white.opacity(viewport.isZoomed ? 0.05 : 0))
            if viewport.isZoomed {
                Capsule().fill(.white.opacity(origin == nil ? 0.25 : 0.4))
                    .frame(width: thumb)
                    .contentShape(Capsule())
                    .gesture(DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let from = origin ?? viewport.start
                            origin = from
                            viewport.scroll(to: from + Double(value.translation.width / travel) * room)
                        }
                        .onEnded { _ in origin = nil })
                    .padding(.leading, x)
            }
        }
    }
}

/// Hands scroll and pinch events over `area` to SwiftUI, which has no way to read them on macOS 14.
/// It takes no room itself: an AppKit view laid over or under the lanes takes their clicks away.
private struct ScrollCatcher: NSViewRepresentable {
    /// In the window's SwiftUI space, with the origin at the top left.
    let area: CGRect
    let handle: (NSEvent, CGPoint) -> Bool

    func makeNSView(context: Context) -> CatcherView { CatcherView() }

    func updateNSView(_ view: CatcherView, context: Context) {
        view.area = area
        view.handle = handle
    }

    final class CatcherView: NSView {
        var area = CGRect.zero
        var handle: ((NSEvent, CGPoint) -> Bool)?
        private var monitor: Any?

        override func hitTest(_ point: NSPoint) -> NSView? { nil }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if let monitor { NSEvent.removeMonitor(monitor) }
            monitor = nil
            guard window != nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: [.scrollWheel, .magnify]) { [weak self] event in
                guard let self, let window = self.window, event.window === window, let content = window.contentView else { return event }
                var point = content.convert(event.locationInWindow, from: nil)
                if !content.isFlipped { point.y = content.bounds.height - point.y }
                guard self.area.contains(point) else { return event }
                return self.handle?(event, CGPoint(x: point.x - self.area.minX, y: point.y - self.area.minY)) == true ? nil : event
            }
        }

        deinit {
            if let monitor { NSEvent.removeMonitor(monitor) }
        }
    }
}

extension Array {
    subscript(safe index: Int) -> Element? { indices.contains(index) ? self[index] : nil }
}

extension CameraSpan.Layout {
    var name: String {
        switch self {
        case .hidden: "hidden"
        case .split: "side by side"
        case .full: "full screen"
        }
    }

    var title: String {
        switch self {
        case .hidden: "Hidden"
        case .split: "Side by Side"
        case .full: "Full Screen"
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
