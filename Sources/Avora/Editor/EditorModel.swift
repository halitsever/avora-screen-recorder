import AVFoundation
import AppKit
import UniformTypeIdentifiers
import ZoomEngine

/// One row of the editor's timeline.
enum Lane: Hashable {
    case clips, zooms, cursor, camera, masks, captions
}

struct LaneSelection: Equatable {
    var lane: Lane
    var index: Int
}

/// State of one editor window: the recording, its edits and the player showing them.
/// The timeline is drawn in recording time; the player runs on the video's time after clips
/// are cut and sped up.
@MainActor
final class EditorModel: ObservableObject {
    static let speeds = [0.5, 1, 1.5, 2, 3, 4, 8]

    let folder: RecordingFolder
    let log: InputLog
    let player = AVPlayer()
    let clickTimes: [Double]
    let hasCamera: Bool
    /// Moments keys were pressed, when the recording noted them.
    let typing: [Double]

    @Published private(set) var clips: ClipList
    @Published private(set) var zooms: ZoomTimeline
    @Published private(set) var cursorHidden: SpanTimeline<TimeRange>
    @Published private(set) var camera: SpanTimeline<CameraSpan>
    @Published private(set) var masks: SpanTimeline<Mask>
    @Published private(set) var captions: SpanTimeline<Caption>
    /// False until the recording has been transcribed; an empty list means nothing was said.
    @Published private(set) var hasCaptions: Bool
    @Published private(set) var isTranscribing = false
    /// How far a search for private things on screen has got.
    @Published private(set) var scanProgress: Double?
    @Published private(set) var crop: CGRect?
    @Published var selection: LaneSelection?
    /// The playhead, in recording time.
    @Published private(set) var time = 0.0
    @Published private(set) var isPlaying = false
    @Published private(set) var exportProgress: Double?
    @Published var errorMessage: String?
    /// Loudness of the recording's mix along the timeline; nil when there is no audio.
    @Published private(set) var waveform: [Float]?
    @Published private(set) var canUndo = false
    @Published private(set) var canRedo = false

    var duration: Double { log.duration }
    var title: String { folder.url.lastPathComponent }
    var videoTime: Double { clips.outputTime(snappingSource: time) }

    /// False while the zooms are the ones made from the clicks, so they follow later rule changes.
    private var zoomsEdited: Bool
    private var undoStack: [RecordingEdits] = []
    private var redoStack: [RecordingEdits] = []
    private var lastUndo: (key: String, at: Date)?
    private var dragSnapshot: RecordingEdits?
    private var preview: PreviewAsset?
    private var timeObserver: Any?
    private var refreshTask: Task<Void, Never>?
    private let preferences = Preferences.shared

    init(folder: RecordingFolder) throws {
        self.folder = folder
        log = try JSONDecoder().decode(InputLog.self, from: Data(contentsOf: folder.log))
        clickTimes = log.clicks.filter(\.isDown).map(\.time)
        let saved = folder.loadEdits()
        zoomsEdited = saved?.zooms != nil
        clips = saved?.clipList(duration: log.duration) ?? .whole(duration: log.duration)
        zooms = ZoomTimeline(segments: [], duration: log.duration)
        cursorHidden = SpanTimeline(segments: saved?.cursorHidden ?? [], duration: log.duration)
        camera = SpanTimeline(segments: saved?.camera ?? [], duration: log.duration)
        masks = SpanTimeline(segments: saved?.masks ?? [], duration: log.duration, allowsOverlap: true)
        captions = SpanTimeline(segments: saved?.captions ?? [], duration: log.duration)
        hasCaptions = saved?.captions != nil
        hasCamera = folder.loadCamera() != nil
        typing = folder.loadTyping()
        crop = saved?.crop
        zooms = saved?.zooms.map { ZoomTimeline(segments: $0, duration: duration) } ?? automaticZooms()
    }

    func load() async {
        refreshPreview(immediately: true)
        let folder = folder, duration = duration
        let voice = preferences.settings.voice
        waveform = try? await Task.detached {
            try await AudioMixSource.waveform(for: folder, duration: duration, buckets: min(max(Int(duration * 40), 200), 4000), voice: voice)
        }.value
    }

    func close() {
        player.pause()
        if let timeObserver { player.removeTimeObserver(timeObserver) }
        timeObserver = nil
        refreshTask?.cancel()
    }

    // MARK: Playback

    func togglePlay() {
        if player.rate > 0 {
            player.pause()
        } else {
            if videoTime >= clips.outputDuration - 0.05 { seek(to: clips.segments.first?.start ?? 0) }
            player.play()
        }
        isPlaying = player.rate > 0
    }

    /// Seeks to a moment of the recording; a moment that was cut lands on the next kept clip.
    func seek(to source: Double) {
        let output = clips.outputTime(snappingSource: min(max(source, 0), duration))
        time = clips.sourceTime(atOutput: output)
        player.seek(to: .seconds(output), toleranceBefore: .zero, toleranceAfter: .zero)
    }

    // MARK: Lanes

    func spans(in lane: Lane) -> [(start: Double, end: Double)] {
        switch lane {
        case .clips: clips.segments.map { ($0.start, $0.end) }
        case .zooms: zooms.segments.map { ($0.start, $0.end) }
        case .cursor: cursorHidden.segments.map { ($0.start, $0.end) }
        case .camera: camera.segments.map { ($0.start, $0.end) }
        case .masks: masks.segments.map { ($0.start, $0.end) }
        case .captions: captions.segments.map { ($0.start, $0.end) }
        }
    }

    /// In the clips row this brings back the part that was cut there.
    func add(in lane: Lane, at time: Double) {
        var added: Int?
        change {
            switch lane {
            case .clips:
                added = clips.add(at: time) { Clip(start: $0, end: $1) }
            case .zooms:
                let scale = selectedZoom?.scale ?? preferences.settings.zoom
                added = zooms.add(at: time, scale: scale)
                if added != nil { zoomsEdited = true }
            case .cursor:
                added = cursorHidden.add(at: time) { TimeRange(start: $0, end: $1) }
            case .camera:
                added = camera.add(at: time) { CameraSpan(start: $0, end: $1, layout: .hidden) }
            case .masks:
                added = masks.add(at: time) { Mask(start: $0, end: $1, rect: CGRect(x: 0.35, y: 0.35, width: 0.3, height: 0.3), kind: .blur) }
            case .captions:
                added = captions.add(at: time) { Caption(start: $0, end: $1, text: "New caption") }
                if added != nil { hasCaptions = true }
            }
        }
        selection = added.map { LaneSelection(lane: lane, index: $0) }
    }

    /// Removing a clip cuts that part out of the video; the last clip always stays.
    func removeSelected() {
        guard let selection, isValid(selection) else { return }
        if selection.lane == .clips, clips.segments.count == 1 { return }
        change {
            switch selection.lane {
            case .clips: clips.remove(selection.index)
            case .zooms:
                zooms.remove(selection.index)
                zoomsEdited = true
            case .cursor: cursorHidden.remove(selection.index)
            case .camera: camera.remove(selection.index)
            case .masks: masks.remove(selection.index)
            case .captions: captions.remove(selection.index)
            }
        }
        self.selection = nil
    }

    /// Clips keep their place in the recording, so only zooms and hidden ranges move.
    func move(_ target: LaneSelection, to start: Double) {
        beginDrag(target)
        switch target.lane {
        case .clips: break
        case .zooms: zooms.move(target.index, to: start)
        case .cursor: cursorHidden.move(target.index, to: start)
        case .camera: camera.move(target.index, to: start)
        case .masks: masks.move(target.index, to: start)
        case .captions: captions.move(target.index, to: start)
        }
    }

    func setStart(_ target: LaneSelection, to time: Double) {
        beginDrag(target)
        switch target.lane {
        case .clips: clips.setStart(target.index, to: time)
        case .zooms: zooms.setStart(target.index, to: time)
        case .cursor: cursorHidden.setStart(target.index, to: time)
        case .camera: camera.setStart(target.index, to: time)
        case .masks: masks.setStart(target.index, to: time)
        case .captions: captions.setStart(target.index, to: time)
        }
    }

    func setEnd(_ target: LaneSelection, to time: Double) {
        beginDrag(target)
        switch target.lane {
        case .clips: clips.setEnd(target.index, to: time)
        case .zooms: zooms.setEnd(target.index, to: time)
        case .cursor: cursorHidden.setEnd(target.index, to: time)
        case .camera: camera.setEnd(target.index, to: time)
        case .masks: masks.setEnd(target.index, to: time)
        case .captions: captions.setEnd(target.index, to: time)
        }
    }

    /// Called when a drag ends: one undo step for the whole drag, and one preview rebuild.
    func finishDrag() {
        if let dragSnapshot, dragSnapshot != edits { pushUndo(dragSnapshot) }
        dragSnapshot = nil
        lastUndo = nil
        save()
        refreshPreview()
    }

    // MARK: Clips

    var selectedClip: Clip? {
        guard let selection, selection.lane == .clips, isValid(selection) else { return nil }
        return clips.segments[selection.index]
    }

    func splitAtPlayhead() {
        var second: Int?
        change { second = clips.split(at: time) }
        if let second { selection = LaneSelection(lane: .clips, index: second) }
    }

    /// Plays every stretch of steady typing at triple speed. Returns how many it found.
    @discardableResult
    func speedUpTyping() -> Int {
        let bursts = TypingBursts.find(in: typing)
        change { clips.speedUp(bursts, to: 3) }
        return bursts.count
    }

    func setSpeed(_ speed: Double) {
        guard let selection, selectedClip != nil else { return }
        change { clips.update(selection.index) { $0.speed = speed } }
    }

    // MARK: Camera

    var selectedCameraSpan: CameraSpan? {
        guard let selection, selection.lane == .camera, isValid(selection) else { return nil }
        return camera.segments[selection.index]
    }

    func setCameraLayout(_ layout: CameraSpan.Layout) {
        guard let selection, selectedCameraSpan != nil else { return }
        change { camera.update(selection.index) { $0.layout = layout } }
    }

    // MARK: Masks

    var selectedMask: Mask? {
        guard let selection, selection.lane == .masks, isValid(selection) else { return nil }
        return masks.segments[selection.index]
    }

    func setMask(kind: Mask.Kind? = nil, rect: CGRect? = nil) {
        guard let selection, selectedMask != nil else { return }
        change(coalescing: rect == nil ? nil : "maskRect") {
            masks.update(selection.index) { mask in
                if let kind { mask.kind = kind }
                if let rect { mask.rect = rect }
            }
        }
    }

    /// Blurs what the scan finds on screen, skipping places a blur already covers. Returns how many it added.
    @discardableResult
    func blurAutomatically(_ target: SensitiveScanner.Target) async -> Int {
        guard scanProgress == nil else { return 0 }
        scanProgress = 0
        defer { scanProgress = nil }
        let video = folder.video, duration = duration
        do {
            let found = try await Task.detached {
                try await SensitiveScanner.scan(video, duration: duration, for: target) { value in
                    Task { @MainActor in self.scanProgress = value }
                }
            }.value
            let added = found.filter { mask in !masks.segments.contains { $0.kind == .blur && $0.covers(mask) } }
            selection = nil
            change {
                masks = SpanTimeline(segments: masks.segments + added, duration: duration, allowsOverlap: true)
            }
            if added.isEmpty {
                errorMessage = target == .text ? "No email addresses, phone or card numbers, IBANs or keys were found on screen."
                                               : "No faces were found on screen."
            }
            return added.count
        } catch {
            errorMessage = error.localizedDescription
            return 0
        }
    }

    // MARK: Captions

    var selectedCaption: Caption? {
        guard let selection, selection.lane == .captions, isValid(selection) else { return nil }
        return captions.segments[selection.index]
    }

    func setCaptionText(_ text: String) {
        guard let selection, selectedCaption != nil else { return }
        change(coalescing: "captionText") { captions.update(selection.index) { $0.text = text } }
    }

    /// Writes captions from what was said, replacing any there were.
    func generateCaptions() async {
        guard !isTranscribing else { return }
        isTranscribing = true
        defer { isTranscribing = false }
        do {
            let made = try await Captioner.transcribe(folder, locale: preferences.settings.captionLocale)
            selection = nil
            change {
                captions = SpanTimeline(segments: made, duration: duration)
                hasCaptions = true
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: Zoom details

    var selectedZoom: ZoomSegment? {
        guard let selection, selection.lane == .zooms, isValid(selection) else { return nil }
        return zooms.segments[selection.index]
    }

    func setLevel(_ scale: Double) {
        guard let selection, selectedZoom != nil else { return }
        change(coalescing: "level") {
            zooms.update(selection.index) { $0.scale = min(max(scale, 1), 4) }
            zoomsEdited = true
        }
    }

    func setFocus(_ focus: CGPoint?) {
        guard let selection, selectedZoom != nil else { return }
        change {
            zooms.update(selection.index) { $0.focus = focus }
            zoomsEdited = true
        }
    }

    func resetZooms() {
        selection = nil
        change {
            zooms = automaticZooms()
            zoomsEdited = false
        }
    }

    /// nil, or a rect covering the whole frame, keeps everything.
    func setCrop(_ rect: CGRect?) {
        let full = CGRect(x: 0, y: 0, width: 1, height: 1)
        change { crop = rect.flatMap { $0.insetBy(dx: 0.001, dy: 0.001).contains(full) ? nil : $0 } }
    }

    // MARK: Undo

    func undo() {
        guard let previous = undoStack.popLast() else { return }
        redoStack.append(edits)
        apply(previous)
    }

    func redo() {
        guard let next = redoStack.popLast() else { return }
        undoStack.append(edits)
        apply(next)
    }

    // MARK: Export

    /// With `copy` the video goes to the clipboard, ready to paste into a chat or an email.
    func export(copy: Bool) async {
        guard exportProgress == nil else { return }
        player.pause()
        exportProgress = 0
        defer { exportProgress = nil }
        do {
            try folder.save(edits)
            let style = preferences.outputStyle
            let movie = try RecordingFolder.newMovieURL(fileExtension: style.format.fileExtension)
            try await Exporter.export(folder, to: movie, style: style) { [weak self] value in
                Task { @MainActor in if self?.exportProgress != nil { self?.exportProgress = value } }
            }
            if copy { Clipboard.copy(file: movie) } else { NSWorkspace.shared.activateFileViewerSelecting([movie]) }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func copyFrame() async {
        guard let frame = await currentFrame() else { return }
        Clipboard.copy(image: frame)
    }

    func saveFrame() async {
        guard let frame = await currentFrame() else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.nameFieldStringValue = "\(title) \(clock(videoTime).replacingOccurrences(of: ":", with: ".")).png"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do { try Clipboard.writePNG(frame, to: url) } catch { errorMessage = error.localizedDescription }
    }

    /// A frame of the raw recording, for picking a focus point or a crop.
    func still(at seconds: Double, maxSide: Double = 640) async -> CGImage? {
        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: folder.video))
        generator.maximumSize = CGSize(width: maxSide, height: maxSide)
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .seconds(0.5)
        return try? await generator.image(at: .seconds(seconds)).image
    }

    // MARK: Private

    var edits: RecordingEdits {
        RecordingEdits(zooms: zoomsEdited ? zooms.segments : nil, cursorHidden: cursorHidden.segments,
                       camera: camera.segments, masks: masks.segments,
                       captions: hasCaptions ? captions.segments : nil, crop: crop,
                       clips: clips == .whole(duration: duration) ? nil : clips.segments)
    }

    /// The frame under the playhead at the size the export would have.
    private func currentFrame() async -> CGImage? {
        player.pause()
        var settings = preferences.settings
        // A still is never a GIF frame, so it keeps the full export size.
        if settings.format == .gif { settings.format = .h264 }
        let style = OutputStyle(settings: settings, background: preferences.background)
        let edits = edits, log = log, cursors = folder.cursors, at = time, keys = folder.loadKeys()
        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: folder.video))
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .seconds(1.0 / 60)
        do {
            let source = try await generator.image(at: .seconds(at)).image
            var camera: CGImage?
            if let manifest = folder.loadCamera() {
                let cameraGenerator = AVAssetImageGenerator(asset: AVURLAsset(url: folder.url.appending(path: manifest.file)))
                cameraGenerator.requestedTimeToleranceBefore = .zero
                cameraGenerator.requestedTimeToleranceAfter = .seconds(0.1)
                camera = try? await cameraGenerator.image(at: .seconds(max(at - manifest.syncedOffset, 0))).image
            }
            return await Task.detached {
                let renderer = FrameRenderer(log: log, cursorFolder: cursors, style: style, edits: edits, keys: keys)
                let image = renderer.render(source: CIImage(cgImage: source), camera: camera.map { CIImage(cgImage: $0) }, at: at)
                return CIContext().createCGImage(image, from: CGRect(origin: .zero, size: renderer.canvas))
            }.value
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    private func automaticZooms() -> ZoomTimeline {
        let config = ZoomConfig(scale: preferences.settings.zoom)
        return ZoomTimeline(segments: ZoomSegments.make(clickTimes: clickTimes, duration: duration, config: config), duration: duration)
    }

    private func isValid(_ selection: LaneSelection) -> Bool {
        spans(in: selection.lane).indices.contains(selection.index)
    }

    private func beginDrag(_ target: LaneSelection) {
        if dragSnapshot == nil { dragSnapshot = edits }
        if target.lane == .zooms { zoomsEdited = true }
    }

    /// One undoable edit. Changes with the same `key` in quick succession, like a slider being
    /// dragged, share one undo step.
    private func change(coalescing key: String? = nil, _ body: () -> Void) {
        let before = edits
        body()
        guard edits != before else { return }
        let now = Date()
        if let key, let lastUndo, lastUndo.key == key, now.timeIntervalSince(lastUndo.at) < 0.8 {
            self.lastUndo = (key, now)
        } else {
            pushUndo(before)
            lastUndo = key.map { ($0, now) }
        }
        save()
        refreshPreview()
    }

    private func pushUndo(_ snapshot: RecordingEdits) {
        undoStack.append(snapshot)
        redoStack.removeAll()
        updateUndoState()
    }

    private func apply(_ snapshot: RecordingEdits) {
        zoomsEdited = snapshot.zooms != nil
        zooms = snapshot.zooms.map { ZoomTimeline(segments: $0, duration: duration) } ?? automaticZooms()
        cursorHidden = SpanTimeline(segments: snapshot.cursorHidden, duration: duration)
        camera = SpanTimeline(segments: snapshot.camera, duration: duration)
        masks = SpanTimeline(segments: snapshot.masks, duration: duration, allowsOverlap: true)
        captions = SpanTimeline(segments: snapshot.captions ?? [], duration: duration)
        hasCaptions = snapshot.captions != nil
        crop = snapshot.crop
        clips = snapshot.clipList(duration: duration)
        selection = nil
        lastUndo = nil
        updateUndoState()
        save()
        refreshPreview()
    }

    private func updateUndoState() {
        canUndo = !undoStack.isEmpty
        canRedo = !redoStack.isEmpty
    }

    private func save() {
        try? folder.save(edits)
    }

    /// Rebuilds the renderer off the main thread, and the player's timeline too when the clips
    /// changed. Long recordings take a moment to simulate.
    private func refreshPreview(immediately: Bool = false) {
        updateUndoState()
        refreshTask?.cancel()
        var style = preferences.outputStyle
        // The preview only needs to fit the window, and smaller frames keep playback smooth.
        style.resolution = .hd
        let edits = edits, log = log, cursors = folder.cursors, clips = clips, folder = folder, duration = duration, keys = folder.loadKeys()
        refreshTask = Task { [weak self] in
            if !immediately { try? await Task.sleep(for: .milliseconds(120)) }
            guard let self else { return }
            if preview?.clips != clips {
                do {
                    let asset = try await PreviewAsset.make(for: folder, duration: duration, clips: clips, voice: style.voice)
                    guard !Task.isCancelled else { return }
                    install(asset)
                } catch {
                    errorMessage = error.localizedDescription
                    return
                }
            }
            let renderer = await Task.detached { FrameRenderer(log: log, cursorFolder: cursors, style: style, edits: edits, keys: keys) }.value
            guard !Task.isCancelled, let preview, let item = player.currentItem else { return }
            item.videoComposition = preview.videoComposition(renderer: renderer, fps: style.fps)
            if player.rate == 0 { seek(to: time) }
        }
    }

    private func install(_ asset: PreviewAsset) {
        preview = asset
        let item = AVPlayerItem(asset: asset.composition)
        item.audioMix = asset.audioMix
        item.audioTimePitchAlgorithm = TimelineComposition.pitchAlgorithm
        player.replaceCurrentItem(with: item)
        if timeObserver == nil {
            timeObserver = player.addPeriodicTimeObserver(forInterval: CMTime(value: 1, timescale: 30), queue: .main) { [weak self] now in
                MainActor.assumeIsolated {
                    guard let self else { return }
                    // While paused the playhead is set by seeking, which already knows the recording time.
                    if self.player.rate > 0 { self.time = self.clips.sourceTime(atOutput: now.seconds) }
                    self.isPlaying = self.player.rate > 0
                }
            }
        }
    }
}
