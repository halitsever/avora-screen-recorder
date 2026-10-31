import Foundation
import Testing
@testable import Avora

private func makeRoot() throws -> URL {
    let root = FileManager.default.temporaryDirectory.appending(path: "avora-raw-\(UUID().uuidString)", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    return root
}

private func makeRecording(_ name: String, in root: URL, created: Date, bytes: Int = 0) throws -> URL {
    let folder = root.appending(path: name, directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: folder.appending(path: "cursors"), withIntermediateDirectories: true)
    try Data(count: bytes).write(to: folder.appending(path: "screen.mov"))
    try FileManager.default.setAttributes([.creationDate: created], ofItemAtPath: folder.path)
    return folder
}

struct RawRecordingsTests {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    private let day: TimeInterval = 24 * 60 * 60

    @Test func onlyRecordingsOlderThanAWeekExpire() throws {
        let root = try makeRoot()
        let old = try makeRecording("old", in: root, created: now - 8 * day)
        _ = try makeRecording("recent", in: root, created: now - 6 * day)

        let expired = RawRecordings.expired(in: root, now: now)
        #expect(expired.map(\.lastPathComponent) == [old.lastPathComponent])
    }

    @Test func sizeCountsFilesInsideEveryRecording() throws {
        let root = try makeRoot()
        _ = try makeRecording("a", in: root, created: now, bytes: 1_000)
        let b = try makeRecording("b", in: root, created: now, bytes: 500)
        try Data(count: 250).write(to: b.appending(path: "cursors/0.png"))

        #expect(RawRecordings.size(of: root) == 1_750)
    }

    @Test func missingFolderHasNothingToClean() {
        let root = FileManager.default.temporaryDirectory.appending(path: "avora-missing-\(UUID().uuidString)")
        #expect(RawRecordings.expired(in: root, now: now).isEmpty)
        #expect(RawRecordings.size(of: root) == 0)
    }

    @Test func removeDeletesEveryRecordingButKeepsTheFolder() throws {
        let root = try makeRoot()
        _ = try makeRecording("a", in: root, created: now, bytes: 10)
        _ = try makeRecording("b", in: root, created: now, bytes: 10)

        RawRecordings.removeAll(in: root)
        #expect(FileManager.default.fileExists(atPath: root.path))
        #expect(RawRecordings.size(of: root) == 0)
    }
}
