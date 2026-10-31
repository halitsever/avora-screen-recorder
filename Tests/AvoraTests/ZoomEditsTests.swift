import Foundation
import Testing
import ZoomEngine
@testable import Avora

private func makeFolder(_ name: String = UUID().uuidString, in root: URL? = nil) throws -> RecordingFolder {
    let parent = root ?? FileManager.default.temporaryDirectory.appending(path: "avora-edits-\(UUID().uuidString)")
    let folder = RecordingFolder(url: parent.appending(path: name, directoryHint: .isDirectory))
    try FileManager.default.createDirectory(at: folder.cursors, withIntermediateDirectories: true)
    return folder
}

struct ZoomEditsTests {
    @Test func folderWithoutEditsUsesClickZooms() throws {
        #expect(try makeFolder().loadEdits() == nil)
    }

    @Test func savedEditsComeBack() throws {
        let folder = try makeFolder()
        let segments = [ZoomSegment(start: 1, end: 2.5, scale: 1.8), ZoomSegment(start: 4, end: 6, scale: 3, focus: CGPoint(x: 0.2, y: 0.9))]
        try folder.save(edits: segments)
        #expect(folder.loadEdits() == segments)
    }

    @Test func latestRecordingIsTheNewestFinishedOne() throws {
        let root = FileManager.default.temporaryDirectory.appending(path: "avora-latest-\(UUID().uuidString)")
        for (name, finished, age) in [("older", true, 300.0), ("newest", true, 10.0), ("unfinished", false, 1.0)] {
            let folder = try makeFolder(name, in: root)
            if finished {
                try Data().write(to: folder.video)
                try Data().write(to: folder.log)
            }
            try FileManager.default.setAttributes([.creationDate: Date().addingTimeInterval(-age)], ofItemAtPath: folder.url.path)
        }
        #expect(RawRecordings.latest(in: root)?.url.lastPathComponent == "newest")
    }
}
