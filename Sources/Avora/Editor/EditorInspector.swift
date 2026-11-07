import SwiftUI
import ZoomEngine

enum InspectorTab: String, CaseIterable, Identifiable {
    case edit, backdrop, cursor, camera, captions, export

    var id: Self { self }

    var title: String {
        switch self {
        case .edit: "Edit"
        case .backdrop: "Backdrop"
        case .cursor: "Cursor"
        case .camera: "Camera"
        case .captions: "Captions"
        case .export: "Export"
        }
    }

    var symbol: String {
        switch self {
        case .edit: "slider.horizontal.3"
        case .backdrop: "photo.on.rectangle"
        case .cursor: "cursorarrow"
        case .camera: "video"
        case .captions: "captions.bubble"
        case .export: "square.and.arrow.up"
        }
    }
}

/// Look and export settings here are Avora's own, shared with the Settings window.
struct EditorInspector: View {
    @ObservedObject var model: EditorModel
    @ObservedObject var preferences: Preferences
    @Binding var tab: InspectorTab

    private var tabs: [InspectorTab] {
        InspectorTab.allCases.filter { $0 != .camera || model.hasCamera }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 2) {
                ForEach(tabs) { item in
                    Button { tab = item } label: {
                        VStack(spacing: 3) {
                            Image(systemName: item.symbol).font(.system(size: 14))
                            Text(item.title).font(.system(size: 10))
                        }
                        .frame(maxWidth: .infinity).frame(height: 42)
                        .foregroundStyle(tab == item ? Palette.foreground : Palette.muted)
                        .background(tab == item ? Palette.border : .clear, in: RoundedRectangle(cornerRadius: 7))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help(item.title)
                }
            }
            .padding(8)
            Divider()
            Group {
                switch tab {
                case .edit:
                    SelectionPane(model: model)
                case .backdrop:
                    Form {
                        BackdropSection(preferences: preferences, showsGallery: true)
                        FrameSection(settings: $preferences.settings, showsShape: true)
                    }
                    .formStyle(.grouped)
                case .cursor:
                    Form {
                        CursorSection(settings: $preferences.settings)
                        MotionSection(settings: $preferences.settings)
                        if model.hasKeys {
                            Section("Keyboard") {
                                Toggle("Show keyboard shortcuts", isOn: $preferences.settings.showsShortcuts)
                            }
                        }
                    }
                    .formStyle(.grouped)
                case .camera:
                    Form {
                        Section("Camera bubble") { CameraLookRows(look: $preferences.settings.camera) }
                        Section {
                            Text("Add a camera layout on the timeline to hide the camera, put it next to the screen or fill the video with it for a while.")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .formStyle(.grouped)
                case .captions:
                    CaptionsPane(model: model, preferences: preferences)
                case .export:
                    ExportPane(model: model, preferences: preferences)
                }
            }
            .scrollContentBackground(.hidden)
            .frame(maxHeight: .infinity, alignment: .top)
        }
    }
}

// MARK: Selection

private struct SelectionPane: View {
    @ObservedObject var model: EditorModel
    @State private var still: CGImage?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if let selection = model.selection, let span = model.spans(in: selection.lane)[safe: selection.index] {
                    header(selection)
                    details(selection)
                    TimingEditor(model: model, target: selection, span: span)
                        .id(selection)
                    removeButton(selection)
                } else {
                    overview
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func header(_ selection: LaneSelection) -> some View {
        let count = model.spans(in: selection.lane).count
        return HStack {
            Circle().fill(selection.lane.color).frame(width: 8, height: 8)
            heading("\(selection.lane.title.uppercased())  \(selection.index + 1) OF \(count)")
            Spacer()
            ControlGroup {
                Button { select(selection.lane, selection.index - 1) } label: { Image(systemName: "chevron.left") }
                    .disabled(selection.index == 0)
                    .help("Previous")
                Button { select(selection.lane, selection.index + 1) } label: { Image(systemName: "chevron.right") }
                    .disabled(selection.index + 1 >= count)
                    .help("Next")
            }
            .controlSize(.small)
            .fixedSize()
            Button { model.selection = nil } label: { Image(systemName: "xmark") }
                .buttonStyle(.borderless)
                .help("Deselect (Esc)")
        }
    }

    private func select(_ lane: Lane, _ index: Int) {
        guard let span = model.spans(in: lane)[safe: index] else { return }
        endTextEditing()
        model.selection = LaneSelection(lane: lane, index: index)
        model.seek(to: span.start)
    }

    @ViewBuilder private func details(_ selection: LaneSelection) -> some View {
        switch selection.lane {
        case .zooms: zoomDetails
        case .clips: clipDetails
        case .cursor: caption("The cursor and its click effects are left out of the video here.")
        case .camera: cameraDetails
        case .masks: maskDetails
        case .captions: captionDetails
        }
    }

    @ViewBuilder private var zoomDetails: some View {
        if let zoom = model.selectedZoom {
            group("Level") {
                HStack {
                    Slider(value: Binding(get: { zoom.scale }, set: { model.setLevel(($0 * 10).rounded() / 10) }), in: 1...4)
                    Text(String(format: "%.1f×", zoom.scale)).monospacedDigit().foregroundStyle(.secondary).frame(width: 40, alignment: .trailing)
                }
                HStack(spacing: 6) {
                    ForEach([1.5, 2, 2.5, 3], id: \.self) { level in
                        Button(String(format: "%g×", level)) { model.setLevel(level) }
                            .controlSize(.small)
                    }
                }
                caption("Keys 1 to 9 set 1.0× to 2.6× too.")
            }
            group("Focus") {
                Picker("Focus", selection: Binding(get: { zoom.focus == nil }, set: { model.setFocus($0 ? nil : CGPoint(x: 0.5, y: 0.5)) })) {
                    Text("Follow the cursor").tag(true)
                    Text("Pinned").tag(false)
                }
                .pickerStyle(.segmented).labelsHidden()
                if let focus = zoom.focus {
                    FocusPicker(image: still, focus: focus) { model.setFocus($0) }
                        .task(id: zoom.start) { still = await model.still(at: zoom.start + 0.05) }
                    caption("Click or drag where the camera should look.")
                } else {
                    caption("Follows your clicks and the cursor.")
                }
            }
        }
    }

    @ViewBuilder private var clipDetails: some View {
        if let clip = model.selectedClip {
            group("Speed") {
                Picker("Speed", selection: Binding(get: { clip.speed }, set: { model.setSpeed($0) })) {
                    ForEach(EditorModel.speeds, id: \.self) { Text(String(format: "%g×", $0)).tag($0) }
                }
                .pickerStyle(.segmented).labelsHidden()
                caption(String(format: "Plays for %@ in the video. Voices keep their pitch at any speed.", clock(clip.outputLength)))
            }
            Button { model.splitAtPlayhead() } label: { Label("Split at Playhead", systemImage: "scissors") }
        }
    }

    @ViewBuilder private var cameraDetails: some View {
        if let span = model.selectedCameraSpan {
            group("Layout") {
                Picker("Layout", selection: Binding(get: { span.layout }, set: { model.setCameraLayout($0) })) {
                    ForEach(CameraSpan.Layout.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented).labelsHidden()
                caption(span.layout.explanation)
            }
        }
    }

    @ViewBuilder private var maskDetails: some View {
        if let mask = model.selectedMask {
            group("Kind") {
                Picker("Kind", selection: Binding(get: { mask.kind }, set: { model.setMask(kind: $0) })) {
                    Text("Blur").tag(Mask.Kind.blur)
                    Text("Highlight").tag(Mask.Kind.highlight)
                }
                .pickerStyle(.segmented).labelsHidden()
            }
            group("Area") {
                RectEditor(image: still, rect: Binding(get: { mask.rect }, set: { model.setMask(rect: $0) }))
                    .task(id: mask.start) { still = await model.still(at: (mask.start + mask.end) / 2) }
                caption(mask.kind == .blur ? "Drag or resize the box over anything private." : "Everything outside the box dims.")
            }
        }
    }

    @ViewBuilder private var captionDetails: some View {
        if let line = model.selectedCaption {
            group("Text") {
                TextField("Caption", text: Binding(get: { line.text }, set: { model.setCaptionText($0) }), axis: .vertical)
                    .lineLimit(2...6)
                    .textFieldStyle(.roundedBorder)
                caption(line.text.isEmpty ? "An empty caption shows nothing." : "Shown when captions are burned in, and written to the .srt file.")
            }
        }
    }

    private func removeButton(_ selection: LaneSelection) -> some View {
        let title = switch selection.lane {
        case .clips: "Cut This Clip"
        case .zooms: "Delete Zoom"
        case .cursor: "Show Cursor Again"
        case .camera: "Back to Bubble"
        case .masks: "Delete Mask"
        case .captions: "Delete Caption"
        }
        return Button(role: .destructive) { model.removeSelected() } label: {
            Label(title, systemImage: "trash").frame(maxWidth: .infinity)
        }
        .controlSize(.large)
        .disabled(selection.lane == .clips && model.clips.segments.count == 1)
        .help("Delete (⌫)")
    }

    // MARK: Nothing selected

    private var overview: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Click a block on the timeline to change it. Double-click an empty spot in a row, or use +, to add one.")
                .font(.callout).foregroundStyle(.secondary)
            group("Zooms (\(model.zooms.segments.count))") {
                VStack(spacing: 2) {
                    ForEach(Array(model.zooms.segments.enumerated()), id: \.offset) { index, zoom in
                        ZoomRow(index: index, zoom: zoom, isCurrent: zoom.contains(model.time)) {
                            select(.zooms, index)
                        } remove: {
                            model.selection = LaneSelection(lane: .zooms, index: index)
                            model.removeSelected()
                        }
                    }
                }
                HStack {
                    Button { if !model.addAtPlayhead(in: .zooms) { NSSound.beep() } } label: { Label("Add at Playhead", systemImage: "plus") }
                    Spacer()
                    Button("Reset Zooms") { model.resetZooms() }
                        .help("Go back to the zooms made from your clicks")
                }
                .controlSize(.small)
            }
            group("Shortcuts") {
                VStack(alignment: .leading, spacing: 6) {
                    shortcut("Space", "Play or pause")
                    shortcut("← →", "Move the playhead 0.1 s, with ⇧ 1 s")
                    shortcut("Z", "Add a zoom at the playhead")
                    shortcut("S", "Split the clip at the playhead")
                    shortcut("1-9", "Zoom level 1.0× to 2.6×")
                    shortcut("⌫", "Delete the selection")
                    shortcut("Esc", "Deselect")
                    shortcut("⌘= ⌘− ⌘0", "Zoom the timeline in, out, or fit")
                    shortcut("⌘Z", "Undo, ⇧⌘Z redo")
                    shortcut("⌘E", "Export")
                }
                .font(.caption)
            }
        }
    }

    private func shortcut(_ keys: String, _ what: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(keys).font(.system(size: 11, design: .monospaced)).padding(.horizontal, 5).padding(.vertical, 1)
                .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 4))
            Text(what).foregroundStyle(.secondary)
        }
    }
}

private struct ZoomRow: View {
    let index: Int
    let zoom: ZoomSegment
    let isCurrent: Bool
    let select: () -> Void
    let remove: () -> Void
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 8) {
            Text("\(index + 1)").font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary).frame(width: 20, alignment: .trailing)
            Text("\(clock(zoom.start)) – \(clock(zoom.end))").font(.system(size: 11.5, design: .monospaced))
            Spacer()
            Text(String(format: "%.1f×", zoom.scale)).font(.system(size: 11.5)).monospacedDigit()
            if zoom.focus != nil { Image(systemName: "scope").font(.system(size: 10)).foregroundStyle(.secondary) }
            Button(action: remove) { Image(systemName: "trash") }
                .buttonStyle(.borderless)
                .opacity(hovering ? 1 : 0.35)
                .help("Delete this zoom")
        }
        .padding(.horizontal, 8).frame(height: 26)
        .background(isCurrent ? Lane.zooms.color.opacity(0.18) : hovering ? Palette.surface : .clear, in: RoundedRectangle(cornerRadius: 6))
        .contentShape(Rectangle())
        .onTapGesture(perform: select)
        .onHover { hovering = $0 }
    }
}

/// Start, end and length, typed or nudged, plus jumps to the playhead.
private struct TimingEditor: View {
    @ObservedObject var model: EditorModel
    let target: LaneSelection
    let span: (start: Double, end: Double)

    var body: some View {
        group("Timing") {
            TimeField(title: "Start", value: span.start, style: .clock) { model.setTiming(target, start: $0)?.start }
            TimeField(title: "End", value: span.end, style: .clock) { model.setTiming(target, end: $0)?.end }
            TimeField(title: "Length", value: span.end - span.start, style: .seconds) { length in
                model.setTiming(target, end: span.start + max(length, 0.1)).map { $0.end - $0.start }
            }
            HStack(spacing: 6) {
                Button("Start at Playhead") { model.setTiming(target, start: model.time) }
                Button("End at Playhead") { model.setTiming(target, end: model.time) }
            }
            .controlSize(.small)
            caption("Type seconds like 2.5 or a time like 0:02.50. Arrows nudge by 0.1 s.")
        }
    }
}

private struct TimeField: View {
    enum Style { case clock, seconds }

    let title: String
    let value: Double
    let style: Style
    /// Returns the value the model settled on, which can differ when it would overlap a neighbor.
    let commit: (Double) -> Double?
    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 8) {
            Text(title).foregroundStyle(.secondary).frame(width: 50, alignment: .leading)
            TextField(title, text: $text)
                .labelsHidden()
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 12, design: .monospaced))
                .focused($focused)
                // Return hands the keys back to the timeline, so ⌘Z and Delete act on the edit.
                .onSubmit {
                    apply()
                    focused = false
                }
            Stepper(title, onIncrement: { nudge(0.1) }, onDecrement: { nudge(-0.1) })
                .labelsHidden()
        }
        .onAppear { text = display(value) }
        .onChange(of: value) { _, new in if !focused { text = display(new) } }
        .onChange(of: focused) { _, now in if !now { apply() } }
    }

    private func display(_ seconds: Double) -> String {
        style == .clock ? clock(seconds) : String(format: "%.2f", seconds)
    }

    private func nudge(_ delta: Double) {
        text = display(commit(value + delta) ?? value)
    }

    private func apply() {
        guard let parsed = TimeText.parse(text), display(parsed) != display(value) else {
            text = display(value)
            return
        }
        text = display(commit(parsed) ?? value)
    }
}

// MARK: Captions

private struct CaptionsPane: View {
    @ObservedObject var model: EditorModel
    @ObservedObject var preferences: Preferences

    var body: some View {
        Form {
            Section {
                Button { Task { await model.generateCaptions() } } label: {
                    if model.isTranscribing {
                        HStack { ProgressView().controlSize(.small); Text("Writing captions…") }
                    } else {
                        Label(model.hasCaptions ? "Write Captions Again" : "Write Captions from Speech", systemImage: "waveform")
                    }
                }
                .disabled(model.isTranscribing)
                Text("Runs on this Mac and replaces the captions there are.").font(.caption).foregroundStyle(.secondary)
            }
            CaptionSection(preferences: preferences)
            if !model.captions.segments.isEmpty {
                Section("Lines (\(model.captions.segments.count))") {
                    ForEach(Array(model.captions.segments.enumerated()), id: \.offset) { index, line in
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Button(clock(line.start)) {
                                endTextEditing()
                                model.selection = LaneSelection(lane: .captions, index: index)
                                model.seek(to: line.start)
                            }
                            .buttonStyle(.borderless)
                            .font(.system(size: 11, design: .monospaced))
                            .help("Select this caption and go to it")
                            TextField("Caption", text: Binding(get: { line.text }, set: { model.setCaptionText($0, at: index) }), axis: .vertical)
                                .labelsHidden()
                                .lineLimit(1...4)
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: Export

private struct ExportPane: View {
    @ObservedObject var model: EditorModel
    @ObservedObject var preferences: Preferences

    var body: some View {
        Form {
            Section {
                if let progress = model.exportProgress {
                    ProgressView(value: progress) { Text("Exporting \(Int(progress * 100))%").monospacedDigit() }
                } else {
                    Button { Task { await model.export(copy: false) } } label: {
                        Label("Export Video", systemImage: "square.and.arrow.up").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(SolidButtonStyle())
                    HStack {
                        Button("Export and Copy") { Task { await model.export(copy: true) } }
                        Spacer()
                        Button("Copy Frame") { Task { await model.copyFrame() } }
                        Button("Save Frame…") { Task { await model.saveFrame() } }
                    }
                    .controlSize(.small)
                }
            }
            VideoSection(settings: $preferences.settings, showsShape: false)
            Section("Sound") {
                Picker("Voice", selection: $preferences.settings.voice) {
                    Text("As recorded").tag(VoicePreset.off)
                    Text("Even level").tag(VoicePreset.standard)
                    Text("Clear: remove background noise").tag(VoicePreset.clear)
                }
            }
            PresetsSection(preferences: preferences)
            Section {
                Text("These are Avora's settings, shared with the Settings window. The shape is under Backdrop.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: Pieces

private func heading(_ text: String) -> some View {
    Text(text).font(.system(size: 11, weight: .semibold)).tracking(0.6).foregroundStyle(.secondary)
}

private func caption(_ text: String) -> some View {
    Text(text).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
}

private func group<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
    VStack(alignment: .leading, spacing: 8) {
        Text(title).font(.system(size: 12, weight: .semibold))
        content()
    }
    .frame(maxWidth: .infinity, alignment: .leading)
}
