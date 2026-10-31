import CoreGraphics
import Foundation
import Testing
import ZoomEngine
@testable import Avora

struct CameraLayoutTests {
    private let canvas = CGSize(width: 1920, height: 1080)

    private func look(_ change: (inout CameraLook) -> Void = { _ in }) -> CameraLook {
        var look = CameraLook()
        change(&look)
        return look
    }

    @Test func defaultBubbleSitsBottomRightAsASquare() {
        let rect = CameraLayout.frame(canvas: canvas, look: look(), zoomProgress: 0)
        #expect(rect.width == rect.height)
        #expect(abs(rect.width - 1080 * CameraLook().size) < 0.5)
        #expect(abs(rect.maxX - (1920 - CameraLayout.margin(canvas))) < 0.5)
        #expect(abs(rect.maxY - (1080 - CameraLayout.margin(canvas))) < 0.5)
    }

    @Test func positionsCoverEveryCornerAndEdge() {
        let topLeft = CameraLayout.frame(canvas: canvas, look: look { $0.position = .topLeft }, zoomProgress: 0)
        #expect(abs(topLeft.minX - CameraLayout.margin(canvas)) < 0.5 && abs(topLeft.minY - CameraLayout.margin(canvas)) < 0.5)
        let bottom = CameraLayout.frame(canvas: canvas, look: look { $0.position = .bottom }, zoomProgress: 0)
        #expect(abs(bottom.midX - 960) < 0.5)
    }

    @Test func wideCameraKeepsItsShortSide() {
        let rect = CameraLayout.frame(canvas: canvas, look: look { $0.aspect = .wide }, zoomProgress: 0)
        #expect(abs(rect.width / rect.height - 16.0 / 9) < 0.01)
        #expect(abs(rect.height - 1080 * CameraLook().size) < 0.5)
    }

    @Test func bubbleShrinksTowardItsCornerDuringZoom() {
        let resting = CameraLayout.frame(canvas: canvas, look: look(), zoomProgress: 0)
        let zoomed = CameraLayout.frame(canvas: canvas, look: look(), zoomProgress: 1)
        #expect(abs(zoomed.width - resting.width * 0.8) < 0.5)
        #expect(abs(zoomed.maxX - resting.maxX) < 0.5 && abs(zoomed.maxY - resting.maxY) < 0.5)
    }

    @Test func shrinkingCanBeTurnedOff() {
        let rect = CameraLayout.frame(canvas: canvas, look: look { $0.shrinksOnZoom = false }, zoomProgress: 1)
        #expect(abs(rect.width - 1080 * CameraLook().size) < 0.5)
    }

    @Test func cornerRadiusFollowsTheShortSide() {
        let circle = look { $0.roundness = 0.5 }
        let rect = CameraLayout.frame(canvas: canvas, look: circle, zoomProgress: 0)
        let radius = CameraLayout.cornerRadius(rect, look: circle)
        // A square bubble at roundness 0.5 is a circle.
        #expect(rect.width == rect.height)
        #expect(radius == Double(rect.width) / 2)
    }

    @Test func cameraLookSurvivesInSettings() throws {
        var settings = RenderSettings()
        settings.camera.position = .topRight
        settings.camera.mirrored = true
        let decoded = try JSONDecoder().decode(RenderSettings.self, from: JSONEncoder().encode(settings))
        #expect(decoded.camera == settings.camera)
    }
}

struct CameraFadeTests {
    @Test func hiddenRangeFadesOutAndBackIn() {
        let hidden = [CameraSpan(start: 2, end: 6, layout: .hidden)]
        #expect(FrameRenderer.cameraOpacity(at: 1, spans: hidden) == 1)
        #expect(abs(FrameRenderer.cameraOpacity(at: 2.125, spans: hidden) - 0.5) < 1e-9)
        #expect(FrameRenderer.cameraOpacity(at: 4, spans: hidden) == 0)
        #expect(abs(FrameRenderer.cameraOpacity(at: 5.875, spans: hidden) - 0.5) < 1e-9)
    }

    @Test func otherLayoutsKeepTheCameraVisible() {
        let spans = [CameraSpan(start: 2, end: 6, layout: .full)]
        #expect(FrameRenderer.cameraOpacity(at: 4, spans: spans) == 1)
    }
}

struct CameraArrangementTests {
    private let spans = [CameraSpan(start: 2, end: 6, layout: .split)]

    @Test func layoutEasesInAndOutAtItsEdges() throws {
        #expect(CameraLayout.arrangement(at: 1, spans: spans) == nil)
        let entering = try #require(CameraLayout.arrangement(at: 2 + CameraLayout.transition / 2, spans: spans))
        #expect(entering.layout == .split)
        #expect(abs(entering.amount - 0.5) < 1e-9)
        let settled = try #require(CameraLayout.arrangement(at: 4, spans: spans))
        #expect(settled.amount == 1)
        let leaving = try #require(CameraLayout.arrangement(at: 6 - CameraLayout.transition / 4, spans: spans))
        #expect(leaving.amount < 0.5)
    }

    @Test func wideCanvasPutsTheCardsSideBySide() {
        let canvas = CGSize(width: 1920, height: 1080)
        let cards = CameraLayout.split(canvas: canvas, source: CGSize(width: 1600, height: 1000))
        let bounds = CGRect(origin: .zero, size: canvas)
        let screenRatio = Double(cards.screen.width / cards.screen.height)
        let sameRow = abs(Double(cards.screen.minY - cards.camera.minY)) < 0.5 && abs(Double(cards.screen.height - cards.camera.height)) < 0.5
        #expect(cards.screen.maxX < cards.camera.minX)
        #expect(sameRow)
        #expect(abs(screenRatio - 1.6) < 0.01)
        #expect(bounds.contains(cards.screen) && bounds.contains(cards.camera))
    }

    @Test func tallCanvasStacksTheCards() {
        let canvas = CGSize(width: 1080, height: 1920)
        let cards = CameraLayout.split(canvas: canvas, source: CGSize(width: 1600, height: 1000))
        let bounds = CGRect(origin: .zero, size: canvas)
        let sameColumn = abs(Double(cards.screen.minX - cards.camera.minX)) < 0.5 && abs(Double(cards.screen.width - cards.camera.width)) < 0.5
        #expect(cards.screen.maxY < cards.camera.minY)
        #expect(sameColumn)
        #expect(bounds.contains(cards.screen) && bounds.contains(cards.camera))
    }
}

struct CameraSpanStorageTests {
    @Test func hiddenRangesFromOlderEditsBecomeHiddenSpans() throws {
        let json = #"{"version":2,"cursorHidden":[],"cameraHidden":[{"start":1,"end":3}],"masks":[]}"#
        let edits = try JSONDecoder().decode(RecordingEdits.self, from: Data(json.utf8))
        #expect(edits.camera == [CameraSpan(start: 1, end: 3, layout: .hidden)])
    }

    @Test func layoutsSurviveARoundTrip() throws {
        var edits = RecordingEdits()
        edits.camera = [CameraSpan(start: 1, end: 3, layout: .split), CameraSpan(start: 5, end: 8, layout: .full)]
        let decoded = try JSONDecoder().decode(RecordingEdits.self, from: JSONEncoder().encode(edits))
        #expect(decoded.camera == edits.camera)
    }
}
