import Foundation
import Testing
import ZoomEngine
@testable import Avora

@MainActor
private func makeModel(clicks: [Double] = [2, 9]) throws -> EditorModel {
    let folder = RecordingFolder(url: FileManager.default.temporaryDirectory.appending(path: "avora-editor-\(UUID().uuidString)"))
    try FileManager.default.createDirectory(at: folder.cursors, withIntermediateDirectories: true)
    let log = InputLog(sourceSize: CGSize(width: 1000, height: 600), pointPixelScale: 1, duration: 20,
                       clicks: clicks.map { ClickEvent(time: $0, position: .zero, isDown: true) })
    try JSONEncoder().encode(log).write(to: folder.log)
    return try EditorModel(folder: folder)
}

@MainActor
struct EditorModelTests {
    @Test func untouchedZoomsStayAutomatic() throws {
        let model = try makeModel()
        #expect(model.zooms.segments.count == 2)
        #expect(model.edits.zooms == nil)
    }

    @Test func hidingTheCursorIsSavedWithTheRecording() throws {
        let model = try makeModel()
        model.add(in: .cursor, at: 5)
        #expect(model.folder.loadEdits()?.cursorHidden == [TimeRange(start: 5, end: 8)])
        #expect(model.folder.loadEdits()?.zooms == nil)
    }

    @Test func undoAndRedoStepThroughEdits() throws {
        let model = try makeModel()
        model.selection = LaneSelection(lane: .zooms, index: 0)
        model.removeSelected()
        #expect(model.zooms.segments.count == 1)
        model.undo()
        #expect(model.zooms.segments.count == 2)
        #expect(model.edits.zooms == nil)
        model.redo()
        #expect(model.zooms.segments.count == 1)
    }

    @Test func aWholeDragIsOneUndoStep() throws {
        let model = try makeModel()
        let target = LaneSelection(lane: .zooms, index: 0)
        let start = model.zooms.segments[0].start
        model.move(target, to: start + 0.5)
        model.move(target, to: start + 1)
        model.finishDrag()
        model.undo()
        #expect(model.zooms.segments[0].start == start)
        #expect(!model.canUndo)
    }

    @Test func sliderChangesShareOneUndoStep() throws {
        let model = try makeModel()
        model.selection = LaneSelection(lane: .zooms, index: 0)
        model.setLevel(2.2)
        model.setLevel(2.6)
        model.setLevel(3.0)
        model.undo()
        #expect(model.zooms.segments[0].scale == 2)
    }
}

@MainActor
struct EditorClipTests {
    @Test func splittingAndCuttingShortenTheVideo() throws {
        let model = try makeModel()
        model.seek(to: 5)
        model.splitAtPlayhead()
        #expect(model.clips.segments.count == 2)
        model.selection = LaneSelection(lane: .clips, index: 0)
        model.removeSelected()
        #expect(model.clips.outputDuration == 15)
        #expect(model.folder.loadEdits()?.clips == [Clip(start: 5, end: 20)])
    }

    @Test func theLastClipCannotBeCut() throws {
        let model = try makeModel()
        model.selection = LaneSelection(lane: .clips, index: 0)
        model.removeSelected()
        #expect(model.clips.segments.count == 1)
    }

    @Test func seekingIntoACutLandsOnTheNextClip() throws {
        let model = try makeModel()
        model.seek(to: 5)
        model.splitAtPlayhead()
        model.selection = LaneSelection(lane: .clips, index: 0)
        model.removeSelected()
        model.seek(to: 2)
        #expect(model.time == 5)
        #expect(model.videoTime == 0)
    }

    @Test func speedIsUndoable() throws {
        let model = try makeModel()
        model.selection = LaneSelection(lane: .clips, index: 0)
        model.setSpeed(2)
        #expect(model.clips.outputDuration == 10)
        model.undo()
        #expect(model.clips.outputDuration == 20)
        #expect(model.edits.clips == nil)
    }
}

@MainActor
struct EditorTypingTests {
    @Test func typingIsSpedUpAndUndoable() throws {
        let model = try makeModel()
        let typing = stride(from: 4.0, through: 7.0, by: 0.2).map { $0 }
        try JSONEncoder().encode(typing).write(to: model.folder.typing)
        let reopened = try EditorModel(folder: model.folder)
        #expect(reopened.speedUpTyping() == 1)
        #expect(reopened.clips.segments.contains { $0.speed == 3 && abs($0.start - 4) < 1e-9 })
        #expect(abs(reopened.clips.outputDuration - 18) < 1e-6)
        reopened.undo()
        #expect(reopened.clips.outputDuration == 20)
    }
}
