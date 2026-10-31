import AVFoundation
import AppKit
import ZoomEngine

/// State of one editor window: the recording, its zooms and the player showing them.
@MainActor
final class EditorModel: ObservableObject {
    let folder: RecordingFolder
    let log: InputLog
    let player = AVPlayer()
    let clickTimes: [Double]

    @Published private(set) var timeline: ZoomTimeline
    @Published var selection: Int?
    @Published private(set) var time = 0.0
    @Published private(set) var isPlaying = false
    @Published private(set) var exportProgress: Double?
    @Published var errorMessage: String?

    var duration: Double { log.duration }
    var title: String { folder.url.lastPathComponent }

    private var preview: PreviewAsset?
    private var timeObserver: Any?
    private var refreshTask: Task<Void, Never>?
    private let preferences = Preferences.shared

    init(folder: RecordingFolder) throws {
        self.folder = folder
        log = try JSONDecoder().decode(InputLog.self, from: Data(contentsOf: folder.log))
        clickTimes = log.clicks.filter(\.isDown).map(\.time)
        timeline = ZoomTimeline(segments: folder.loadEdits() ?? [], duration: log.duration)
        if folder.loadEdits() == nil { timeline = automaticTimeline() }
    }

    func load() async {
        do {
            let preview = try await PreviewAsset.make(for: folder, duration: duration)
            self.preview = preview
            let item = AVPlayerItem(asset: preview.composition)
            item.audioMix = preview.audioMix
            player.replaceCurrentItem(with: item)
            timeObserver = player.addPeriodicTimeObserver(forInterval: CMTime(value: 1, timescale: 30), queue: .main) { [weak self] now in
                MainActor.assumeIsolated {
                    guard let self else { return }
                    self.time = min(now.seconds, self.duration)
                    self.isPlaying = self.player.rate > 0
                }
            }
            refreshPreview(immediately: true)
        } catch {
            errorMessage = error.localizedDescription
        }
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
            if time >= duration - 0.05 { seek(to: 0) }
            player.play()
        }
        isPlaying = player.rate > 0
    }

    func seek(to seconds: Double) {
        time = min(max(seconds, 0), duration)
        player.seek(to: .seconds(time), toleranceBefore: .zero, toleranceAfter: .zero)
    }

    // MARK: Zoom edits

    var selected: ZoomSegment? {
        guard let selection, timeline.segments.indices.contains(selection) else { return nil }
        return timeline.segments[selection]
    }

    func select(at time: Double) {
        selection = timeline.index(at: time)
    }

    func addZoom(at time: Double) {
        let scale = selected?.scale ?? preferences.settings.zoom
        var added: Int?
        edit { added = $0.add(at: time, scale: scale) }
        selection = added
    }

    func removeSelected() {
        guard let selection, selected != nil else { return }
        edit { $0.remove(selection) }
        self.selection = nil
    }

    func move(_ index: Int, to start: Double) { edit(preview: false) { $0.move(index, to: start) } }
    func setStart(_ index: Int, to time: Double) { edit(preview: false) { $0.setStart(index, to: time) } }
    func setEnd(_ index: Int, to time: Double) { edit(preview: false) { $0.setEnd(index, to: time) } }

    /// Called when a drag ends, so the preview is rebuilt once instead of on every mouse move.
    func finishDrag() { edit { _ in } }

    func setLevel(_ scale: Double) {
        guard let selection, selected != nil else { return }
        edit { $0.update(selection) { $0.scale = min(max(scale, 1), 4) } }
    }

    func setFocus(_ focus: CGPoint?) {
        guard let selection, selected != nil else { return }
        edit { $0.update(selection) { $0.focus = focus } }
    }

    func resetZooms() {
        selection = nil
        timeline = automaticTimeline()
        try? FileManager.default.removeItem(at: folder.edits)
        refreshPreview(immediately: true)
    }

    // MARK: Export

    func export() async {
        guard exportProgress == nil else { return }
        player.pause()
        exportProgress = 0
        defer { exportProgress = nil }
        do {
            try folder.save(edits: timeline.segments)
            let style = preferences.outputStyle
            let movie = try RecordingFolder.newMovieURL(fileExtension: style.format.fileExtension)
            try await Exporter.export(folder, to: movie, style: style) { [weak self] value in
                Task { @MainActor in if self?.exportProgress != nil { self?.exportProgress = value } }
            }
            NSWorkspace.shared.activateFileViewerSelecting([movie])
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// A frame of the raw recording, for picking a manual focus point.
    func still(at seconds: Double) async -> CGImage? {
        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: folder.video))
        generator.maximumSize = CGSize(width: 640, height: 640)
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .seconds(0.5)
        return try? await generator.image(at: .seconds(seconds)).image
    }

    // MARK: Private

    private func automaticTimeline() -> ZoomTimeline {
        let config = ZoomConfig(scale: preferences.settings.zoom)
        return ZoomTimeline(segments: ZoomSegments.make(clickTimes: clickTimes, duration: duration, config: config), duration: duration)
    }

    private func edit(preview: Bool = true, _ change: (inout ZoomTimeline) -> Void) {
        change(&timeline)
        try? folder.save(edits: timeline.segments)
        if preview { refreshPreview() }
    }

    /// Rebuilds the renderer off the main thread; long recordings take a moment to simulate.
    private func refreshPreview(immediately: Bool = false) {
        guard let preview else { return }
        refreshTask?.cancel()
        var style = preferences.outputStyle
        // The preview only needs to fit the window, and smaller frames keep playback smooth.
        style.resolution = .hd
        let segments = timeline.segments, log = log, cursors = folder.cursors
        refreshTask = Task { [weak self] in
            if !immediately { try? await Task.sleep(for: .milliseconds(120)) }
            let renderer = await Task.detached { FrameRenderer(log: log, cursorFolder: cursors, style: style, segments: segments) }.value
            guard !Task.isCancelled, let self, let item = player.currentItem else { return }
            item.videoComposition = preview.videoComposition(renderer: renderer, fps: style.fps)
            if player.rate == 0 { seek(to: time) }
        }
    }
}
