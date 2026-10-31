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
        let edits = RecordingEdits(zooms: segments, cursorHidden: [TimeRange(start: 7, end: 9)])
        try folder.save(edits)
        #expect(folder.loadEdits() == edits)
    }

    @Test func firstFormatOfTheEditsFileStillLoads() throws {
        let folder = try makeFolder()
        try Data(#"{"version":1,"segments":[{"start":1,"end":4,"scale":3,"focus":[0.5,0.5]}]}"#.utf8).write(to: folder.edits)
        #expect(folder.loadEdits()?.zooms == [ZoomSegment(start: 1, end: 4, scale: 3, focus: CGPoint(x: 0.5, y: 0.5))])
        #expect(folder.loadEdits()?.cursorHidden == [])
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

struct CropEditsTests {
    @Test func cropIsSavedWithTheEdits() throws {
        let folder = RecordingFolder(url: FileManager.default.temporaryDirectory.appending(path: "avora-crop-\(UUID().uuidString)"))
        try FileManager.default.createDirectory(at: folder.url, withIntermediateDirectories: true)
        let edits = RecordingEdits(crop: CGRect(x: 0.1, y: 0.2, width: 0.5, height: 0.6))
        try folder.save(edits)
        #expect(folder.loadEdits()?.crop == CGRect(x: 0.1, y: 0.2, width: 0.5, height: 0.6))
    }

    @Test func cropInPixelsIsEvenAndInsideTheRecording() {
        let pixels = RecordingEdits.cropPixels(CGRect(x: 0.1, y: 0.1, width: 0.95, height: 0.333), source: CGSize(width: 1001, height: 600))
        #expect(pixels.maxX <= 1001 && pixels.maxY <= 600)
        #expect(pixels.width.truncatingRemainder(dividingBy: 2) == 0 && pixels.height.truncatingRemainder(dividingBy: 2) == 0)
    }
}
