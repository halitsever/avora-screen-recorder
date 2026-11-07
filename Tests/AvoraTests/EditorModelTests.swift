import Foundation
import Testing
import ZoomEngine
@testable import Avora

@MainActor
private func makeModel(clicks: [Double] = [2, 9], preferences: Preferences = isolatedPreferences()) throws -> EditorModel {
    let folder = RecordingFolder(url: FileManager.default.temporaryDirectory.appending(path: "avora-editor-\(UUID().uuidString)"))
    try FileManager.default.createDirectory(at: folder.cursors, withIntermediateDirectories: true)
    let log = InputLog(sourceSize: CGSize(width: 1000, height: 600), pointPixelScale: 1, duration: 20,
                       clicks: clicks.map { ClickEvent(time: $0, position: .zero, isDown: true) })
    try JSONEncoder().encode(log).write(to: folder.log)
    return try EditorModel(folder: folder, preferences: preferences)
}

private func isolatedPreferences() -> Preferences {
    Preferences(defaults: UserDefaults(suiteName: "avora-editor-\(UUID().uuidString)")!)
}

@MainActor
struct EditorTimingTests {
    @Test func typedTimingIsOneUndoStep() throws {
        let model = try makeModel()
        let target = LaneSelection(lane: .zooms, index: 0)
        let before = model.zooms.segments[0]
        let result = model.setTiming(target, start: 1, end: 2.2)
        #expect(result?.start == 1 && result?.end == 2.2)
        #expect(model.edits.zooms != nil)
        model.undo()
        #expect(model.zooms.segments[0] == before)
        #expect(!model.canUndo)
    }

    @Test func timingCanJumpPastTheOldEnd() throws {
        let model = try makeModel(clicks: [2])
        let target = LaneSelection(lane: .zooms, index: 0)
        let result = model.setTiming(target, start: 10, end: 12)
        #expect(result?.start == 10 && result?.end == 12)
    }

    @Test func aStartPastTheEndMovesTheZoom() throws {
        let model = try makeModel()
        let target = LaneSelection(lane: .zooms, index: 0)
        let length = model.zooms.segments[0].length
        let result = model.setTiming(target, start: 5)
        #expect(result?.start == 5)
        #expect(abs((result?.end ?? 0) - (5 + length)) < 1e-9)
    }

    @Test func anEndBeforeTheStartMovesTheZoom() throws {
        let model = try makeModel()
        let target = LaneSelection(lane: .zooms, index: 1)
        let length = model.zooms.segments[1].length
        let result = model.setTiming(target, end: 7.5)
        #expect(result?.end == 7.5)
        #expect(abs((result?.start ?? 0) - (7.5 - length)) < 1e-9)
    }

    @Test func timingStaysClearOfTheNextZoom() throws {
        let model = try makeModel()
        let target = LaneSelection(lane: .zooms, index: 0)
        let next = model.zooms.segments[1].start
        let result = model.setTiming(target, end: 30)
        #expect(result?.end == next)
    }

    @Test func addingWhereAZoomIsSelectsIt() throws {
        let model = try makeModel()
        model.seek(to: 2.5)
        #expect(model.addAtPlayhead(in: .zooms))
        #expect(model.selection == LaneSelection(lane: .zooms, index: 0))
        #expect(model.zooms.segments.count == 2)
    }

    @Test func addingInAGapAddsAZoom() throws {
        let model = try makeModel()
        model.seek(to: 15)
        #expect(model.addAtPlayhead(in: .zooms))
        #expect(model.zooms.segments.count == 3)
        #expect(model.selectedZoom?.start == 15)
    }

    @Test func steppingMovesThePlayheadInsideTheRecording() throws {
        let model = try makeModel()
        model.step(by: -1)
        #expect(model.time == 0)
        model.step(by: 1.5)
        #expect(model.time == 1.5)
        model.step(by: 100)
        #expect(model.time == 20)
    }

    @Test func untouchedZoomsFollowTheZoomSetting() async throws {
        let preferences = isolatedPreferences()
        let model = try makeModel(preferences: preferences)
        preferences.settings.zoom = 2.75
        try await Task.sleep(for: .milliseconds(200))
        #expect(model.zooms.segments.allSatisfy { $0.scale == 2.75 })
        #expect(model.edits.zooms == nil)
    }

    @Test func captionTextChangesByIndex() throws {
        let model = try makeModel()
        model.add(in: .captions, at: 4)
        model.setCaptionText("Hello", at: 0)
        #expect(model.captions.segments[0].text == "Hello")
    }
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
