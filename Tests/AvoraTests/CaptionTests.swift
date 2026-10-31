import Foundation
import Testing
import ZoomEngine
@testable import Avora

private func words(_ items: [(String, Double)], length: Double = 0.3) -> [SpokenWord] {
    items.map { SpokenWord(text: $0.0, start: $0.1, end: $0.1 + length) }
}

struct CaptionTests {
    @Test func wordsGroupIntoShortPhrases() {
        let spoken = words((0..<10).map { ("w\($0)", Double($0) * 0.35) })
        let phrases = Captioner.phrases(from: spoken)
        #expect(phrases.count == 2)
        #expect(phrases[0].text == "w0 w1 w2 w3 w4 w5 w6")
        #expect(phrases[0].start == 0)
    }

    @Test func pausesAndSentenceEndsStartANewPhrase() {
        let phrases = Captioner.phrases(from: words([("Hello", 0), ("there.", 0.4), ("Next", 0.8), ("one", 2.5)]))
        #expect(phrases.map(\.text) == ["Hello there.", "Next", "one"])
    }

    @Test func phrasesStayAWhileButNeverOverlap() {
        let phrases = Captioner.phrases(from: words([("One.", 0), ("Two.", 0.5)]))
        #expect(phrases[0].end > 0.3)
        #expect(phrases[0].end <= phrases[1].start)
    }

    @Test func subtitlesFollowTheEditedTimeline() {
        let captions = [Caption(start: 1, end: 2, text: "kept"), Caption(start: 5, end: 6, text: "cut"), Caption(start: 9, end: 10, text: "sped up")]
        let clips = ClipList(segments: [Clip(start: 0, end: 4), Clip(start: 8, end: 12, speed: 2)], duration: 12)
        let srt = SubRip.make(captions, clips: clips)
        #expect(srt == "1\n00:00:01,000 --> 00:00:02,000\nkept\n\n2\n00:00:04,500 --> 00:00:05,000\nsped up\n")
    }

    @Test func captionsAreSavedWithTheEdits() throws {
        let folder = RecordingFolder(url: FileManager.default.temporaryDirectory.appending(path: "avora-captions-\(UUID().uuidString)"))
        try FileManager.default.createDirectory(at: folder.url, withIntermediateDirectories: true)
        try folder.save(RecordingEdits(captions: [Caption(start: 1, end: 2, text: "Hi")]))
        #expect(folder.loadEdits()?.captions == [Caption(start: 1, end: 2, text: "Hi")])
    }
}
