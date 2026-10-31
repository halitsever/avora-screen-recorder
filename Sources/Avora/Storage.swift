import CoreMedia
import Foundation

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

    static func makeNew() throws -> RecordingFolder {
        let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appending(path: "Avora/Recordings", directoryHint: .isDirectory)
        let folder = RecordingFolder(url: root.appending(path: timestamp(), directoryHint: .isDirectory))
        try FileManager.default.createDirectory(at: folder.cursors, withIntermediateDirectories: true)
        return folder
    }

    static func newMovieURL() throws -> URL {
        let movies = FileManager.default.urls(for: .moviesDirectory, in: .userDomainMask)[0]
            .appending(path: "Avora", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: movies, withIntermediateDirectories: true)
        return movies.appending(path: "Avora \(timestamp()).mp4")
    }

    private static func timestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd 'at' HH.mm.ss"
        return formatter.string(from: Date())
    }
}
