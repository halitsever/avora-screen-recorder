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
    var cursors: URL { url.appending(path: "cursors", directoryHint: .isDirectory) }
    var microphone: URL { url.appending(path: "microphone.m4a") }
    var systemAudio: URL { url.appending(path: "system-audio.m4a") }
    var audioManifest: URL { url.appending(path: "audio.json") }
    var edits: URL { url.appending(path: "edits.json") }

    /// Zooms changed in the editor; nil until the recording has been edited.
    func loadEdits() -> [ZoomSegment]? {
        guard let data = try? Data(contentsOf: edits) else { return nil }
        return try? JSONDecoder().decode(ZoomEdits.self, from: data).segments
    }

    func save(edits segments: [ZoomSegment]) throws {
        try JSONEncoder().encode(ZoomEdits(segments: segments)).write(to: edits, options: .atomic)
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

private struct ZoomEdits: Codable {
    var version = 1
    var segments: [ZoomSegment]
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
