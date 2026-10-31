import CoreMedia
import Foundation
import ZoomEngine

enum HostClock {
    /// Same clock ScreenCaptureKit stamps frames with, so input and video line up.
    static func now() -> Double {
        CMClockGetTime(CMClockGetHostTimeClock()).seconds
    }
}

/// One raw recording on disk: the screen video, the input log and captured cursor images.
struct RecordingFolder {
    let url: URL

    var video: URL { url.appending(path: "screen.mov") }
    var log: URL { url.appending(path: "input.json") }
    /// Input written while recording, so a crash still leaves something to recover.
    var partialLog: URL { url.appending(path: "input.partial.json") }
    var cursors: URL { url.appending(path: "cursors", directoryHint: .isDirectory) }
    var microphone: URL { url.appending(path: "microphone.m4a") }
    var systemAudio: URL { url.appending(path: "system-audio.m4a") }
    var audioManifest: URL { url.appending(path: "audio.json") }
    var camera: URL { url.appending(path: "camera.mov") }
    var cameraManifest: URL { url.appending(path: "camera.json") }
    var keys: URL { url.appending(path: "keys.json") }
    var typing: URL { url.appending(path: "typing.json") }

    func loadTyping() -> [Double] {
        (try? Data(contentsOf: typing)).flatMap { try? JSONDecoder().decode([Double].self, from: $0) } ?? []
    }

    func loadKeys() -> [KeyPress] {
        (try? Data(contentsOf: keys)).flatMap { try? JSONDecoder().decode([KeyPress].self, from: $0) } ?? []
    }

    /// The camera file and where it starts; nil when the recording has no camera.
    func loadCamera() -> CameraManifest? {
        (try? Data(contentsOf: cameraManifest)).flatMap { try? JSONDecoder().decode(CameraManifest.self, from: $0) }
    }
    var edits: URL { url.appending(path: "edits.json") }

    /// What the editor changed; nil until the recording has been edited.
    func loadEdits() -> RecordingEdits? {
        guard let data = try? Data(contentsOf: edits) else { return nil }
        return try? JSONDecoder().decode(RecordingEdits.self, from: data)
    }

    func save(_ changes: RecordingEdits) throws {
        try JSONEncoder().encode(changes).write(to: edits, options: .atomic)
    }

    static func makeNew() throws -> RecordingFolder {
        let folder = RecordingFolder(url: RawRecordings.root.appending(path: timestamp(), directoryHint: .isDirectory))
        try FileManager.default.createDirectory(at: folder.cursors, withIntermediateDirectories: true)
        return folder
    }

    static func newMovieURL(fileExtension: String = "mp4") throws -> URL {
        let movies = FileManager.default.urls(for: .moviesDirectory, in: .userDomainMask)[0]
            .appending(path: "Avora", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: movies, withIntermediateDirectories: true)
        return movies.appending(path: "Avora \(timestamp()).\(fileExtension)")
    }

    private static func timestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd 'at' HH.mm.ss"
        return formatter.string(from: Date())
    }
}

/// Everything changed in the editor for one recording, saved next to it as edits.json.
struct RecordingEdits: Equatable {
    /// nil keeps the zooms made from the clicks.
    var zooms: [ZoomSegment]?
    var cursorHidden: [TimeRange] = []
    var camera: [CameraSpan] = []
    var masks: [Mask] = []
    /// nil until the recording has been transcribed.
    var captions: [Caption]?
    /// Part of the recording to keep, as fractions with a top-left origin; nil keeps all of it.
    var crop: CGRect?
    /// Kept parts of the recording and their speed; nil keeps all of it at normal speed.
    var clips: [Clip]?

    func clipList(duration: Double) -> ClipList {
        clips.map { ClipList(segments: $0, duration: duration) } ?? .whole(duration: duration)
    }

    /// `crop` in source pixels, kept inside the recording and even for the encoders.
    static func cropPixels(_ crop: CGRect, source: CGSize) -> CGRect {
        let even = { (value: Double) in (value / 2).rounded(.down) * 2 }
        let x = (crop.minX * source.width).rounded(), y = (crop.minY * source.height).rounded()
        let width = even(min(crop.width * source.width, source.width - x))
        let height = even(min(crop.height * source.height, source.height - y))
        return CGRect(x: x, y: y, width: max(width, 2), height: max(height, 2))
    }
}

extension RecordingEdits: Codable {
    private enum Key: String, CodingKey { case version, zooms, segments, cursorHidden, camera, cameraHidden, masks, captions, crop, clips }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Key.self)
        // The first version of the file only held zooms, under "segments".
        zooms = try c.decodeIfPresent([ZoomSegment].self, forKey: .zooms) ?? c.decodeIfPresent([ZoomSegment].self, forKey: .segments)
        cursorHidden = try c.decodeIfPresent([TimeRange].self, forKey: .cursorHidden) ?? []
        // Version 2 could only hide the camera.
        camera = try c.decodeIfPresent([CameraSpan].self, forKey: .camera)
            ?? (c.decodeIfPresent([TimeRange].self, forKey: .cameraHidden) ?? []).map { CameraSpan(start: $0.start, end: $0.end, layout: .hidden) }
        masks = try c.decodeIfPresent([Mask].self, forKey: .masks) ?? []
        captions = try c.decodeIfPresent([Caption].self, forKey: .captions)
        crop = try c.decodeIfPresent(CGRect.self, forKey: .crop)
        clips = try c.decodeIfPresent([Clip].self, forKey: .clips)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: Key.self)
        try c.encode(3, forKey: .version)
        try c.encodeIfPresent(zooms, forKey: .zooms)
        try c.encode(cursorHidden, forKey: .cursorHidden)
        try c.encode(camera, forKey: .camera)
        try c.encode(masks, forKey: .masks)
        try c.encodeIfPresent(captions, forKey: .captions)
        try c.encodeIfPresent(crop, forKey: .crop)
        try c.encodeIfPresent(clips, forKey: .clips)
    }
}

/// Raw recordings are kept so they can be rendered again, but only for a week.
enum RawRecordings {
    static let lifetime: TimeInterval = 7 * 24 * 60 * 60

    static var root: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appending(path: "Avora/Recordings", directoryHint: .isDirectory)
    }

    static func expired(in root: URL = root, now: Date = Date()) -> [URL] {
        recordings(in: root).filter { folder in
            let created = (try? folder.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? now
            return now.timeIntervalSince(created) > lifetime
        }
    }

    /// The newest recording that finished, which the editor opens.
    static func latest(in root: URL = root) -> RecordingFolder? {
        recordings(in: root)
            .map(RecordingFolder.init(url:))
            .filter { FileManager.default.fileExists(atPath: $0.video.path) && FileManager.default.fileExists(atPath: $0.log.path) }
            .max { created($0.url) < created($1.url) }
    }

    /// Recordings cut short by a crash: screen video and input saved along the way, never finished.
    static func unfinished(in root: URL = root) -> [RecordingFolder] {
        let exists = { (url: URL) in FileManager.default.fileExists(atPath: url.path) }
        return recordings(in: root)
            .map(RecordingFolder.init(url:))
            .filter { exists($0.video) && exists($0.partialLog) && !exists($0.log) }
            .sorted { created($0.url) < created($1.url) }
    }

    /// Makes the input saved along the way the recording's input, so it exports like any other.
    static func markRecovered(_ folder: RecordingFolder) throws {
        try FileManager.default.moveItem(at: folder.partialLog, to: folder.log)
    }

    private static func created(_ url: URL) -> Date {
        (try? url.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
    }

    static func size(of root: URL = root) -> Int64 {
        guard let files = FileManager.default.enumerator(at: root, includingPropertiesForKeys: [.fileSizeKey]) else { return 0 }
        return files.reduce(into: Int64(0)) { total, item in
            guard let url = item as? URL, let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize else { return }
            total += Int64(size)
        }
    }

    static func removeExpired(in root: URL = root) {
        expired(in: root).forEach { try? FileManager.default.removeItem(at: $0) }
    }

    static func removeAll(in root: URL = root) {
        recordings(in: root).forEach { try? FileManager.default.removeItem(at: $0) }
    }

    private static func recordings(in root: URL) -> [URL] {
        let items = (try? FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: [.isDirectoryKey])) ?? []
        return items.filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true }
    }
}
