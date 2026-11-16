import Foundation
import Testing
@testable import Avora

struct AppVersionTests {
    @Test func comparesEachNumber() {
        #expect(AppVersion.isNewer("0.4.1", than: "0.4.0"))
        #expect(AppVersion.isNewer("0.10.0", than: "0.9.9"))
        #expect(AppVersion.isNewer("1.0", than: "0.99.99"))
        #expect(!AppVersion.isNewer("0.4.0", than: "0.4.0"))
        #expect(!AppVersion.isNewer("0.3.9", than: "0.4.0"))
    }

    @Test func readsTagsWithAPrefixOrMissingParts() {
        #expect(AppVersion.parts("v0.4.1") == [0, 4, 1])
        #expect(AppVersion.parts("1.2-beta") == [1, 2])
        #expect(!AppVersion.isNewer("v0.4", than: "0.4.0"))
    }
}

@MainActor
struct UpdaterTests {
    private func release(tag: String, asset: String = "Avora.zip", prerelease: Bool = false) -> Data {
        Data("""
        {"tag_name": "\(tag)", "html_url": "https://example.com/releases/\(tag)", "draft": false, "prerelease": \(prerelease),
         "assets": [{"name": "\(asset)", "browser_download_url": "https://example.com/\(asset)"}]}
        """.utf8)
    }

    @Test func newerReleaseWithTheAppIsAnUpdate() throws {
        let update = try Updater.update(from: release(tag: "v0.5.0"), current: "0.4.1")
        #expect(update == AppUpdate(version: "0.5.0", download: URL(string: "https://example.com/Avora.zip")!,
                                    page: URL(string: "https://example.com/releases/v0.5.0")!))
    }

    @Test func sameVersionIsNoUpdate() throws {
        #expect(try Updater.update(from: release(tag: "v0.4.1"), current: "0.4.1") == nil)
    }

    @Test func releaseWithoutTheAppIsSkipped() throws {
        #expect(try Updater.update(from: release(tag: "v0.5.0", asset: "notes.txt"), current: "0.4.1") == nil)
    }

    @Test func prereleaseIsSkipped() throws {
        #expect(try Updater.update(from: release(tag: "v0.5.0", prerelease: true), current: "0.4.1") == nil)
    }
}
