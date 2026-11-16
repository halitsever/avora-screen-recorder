import AppKit

/** A release newer than the running app, with the zipped app to install. */
struct AppUpdate: Equatable {
    let version: String
    let download: URL
    let page: URL
}

enum AppVersion {
    static var current: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    }

    /** Numbers of `v1.2.3` or `1.2`. Anything after a dash, like `-beta`, is ignored. */
    static func parts(_ text: String) -> [Int] {
        let plain = text.hasPrefix("v") ? String(text.dropFirst()) : text
        let core = plain.split(separator: "-").first.map(String.init) ?? ""
        return core.split(separator: ".").map { Int($0) ?? 0 }
    }

    static func isNewer(_ candidate: String, than current: String) -> Bool {
        let a = parts(candidate), b = parts(current)
        for index in 0..<max(a.count, b.count) {
            let x = index < a.count ? a[index] : 0, y = index < b.count ? b[index] : 0
            if x != y { return x > y }
        }
        return false
    }
}

enum UpdateError: LocalizedError {
    case badDownload
    case notWritable(URL)
    case busy

    var errorDescription: String? {
        switch self {
        case .badDownload: "The downloaded update is not a valid Avora app."
        case .notWritable(let folder): "Avora can't replace itself in \(folder.path). Move Avora to a folder you can write to, like Applications, and try again."
        case .busy: "Finish or stop the recording first, then install the update."
        }
    }
}

/// Looks for new releases on GitHub and installs them in place. Builds are signed ad hoc, so
/// macOS asks for Screen Recording permission again after an update.
@MainActor
final class Updater {
    static let repository = "halitsever/avora-screen-recorder"
    static let assetName = "Avora.zip"
    static let interval: TimeInterval = 24 * 60 * 60

    private(set) var available: AppUpdate?
    private(set) var isInstalling = false
    var onChange: (() -> Void)?
    private var timer: Timer?

    func startChecking() {
        Task { try? await check() }
        timer = Timer.scheduledTimer(withTimeInterval: Self.interval, repeats: true) { [weak self] _ in
            Task { @MainActor in try? await self?.check() }
        }
    }

    /// Returns the update when there is one.
    @discardableResult
    func check() async throws -> AppUpdate? {
        var request = URLRequest(url: URL(string: "https://api.github.com/repos/\(Self.repository)/releases/latest")!)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("Avora", forHTTPHeaderField: "User-Agent")
        let (data, _) = try await URLSession.shared.data(for: request)
        available = try Self.update(from: data, current: AppVersion.current)
        onChange?()
        return available
    }

    /** The release in GitHub's JSON when it is newer than `current` and carries the zipped app. */
    static func update(from data: Data, current: String) throws -> AppUpdate? {
        let release = try JSONDecoder().decode(Release.self, from: data)
        guard !release.draft, !release.prerelease, AppVersion.isNewer(release.tagName, than: current),
              let asset = release.assets.first(where: { $0.name == assetName })
        else { return nil }
        let version = release.tagName.hasPrefix("v") ? String(release.tagName.dropFirst()) : release.tagName
        return AppUpdate(version: version, download: asset.url, page: release.page)
    }

    /// Downloads and unpacks the update next to the running app, then quits. A helper swaps the
    /// bundles once Avora has exited and opens the new one.
    func install(_ update: AppUpdate) async throws {
        isInstalling = true
        onChange?()
        defer {
            isInstalling = false
            onChange?()
        }
        let target = Bundle.main.bundleURL
        let folder = target.deletingLastPathComponent()
        guard FileManager.default.isWritableFile(atPath: folder.path) else { throw UpdateError.notWritable(folder) }

        let (zip, _) = try await URLSession.shared.download(from: update.download)
        // On the app's volume, so the final move is a rename.
        let work = try FileManager.default.url(for: .itemReplacementDirectory, in: .userDomainMask, appropriateFor: target, create: true)
        try await Task.detached { try Self.run("/usr/bin/ditto", ["-x", "-k", zip.path, work.path]) }.value
        let app = work.appending(path: "Avora.app")
        guard let bundle = Bundle(url: app), bundle.bundleIdentifier == Bundle.main.bundleIdentifier,
              bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String == update.version
        else { throw UpdateError.badDownload }

        let script = """
        while kill -0 "$1" 2>/dev/null; do sleep 0.2; done
        if mv "$2" "$2.old"; then
            if mv "$3" "$2"; then rm -rf "$2.old"; else mv "$2.old" "$2"; fi
        fi
        rm -rf "$4"
        xattr -dr com.apple.quarantine "$2" 2>/dev/null
        open "$2"
        """
        let helper = Process()
        helper.executableURL = URL(fileURLWithPath: "/bin/sh")
        helper.arguments = ["-c", script, "sh", String(ProcessInfo.processInfo.processIdentifier), target.path, app.path, work.path]
        try helper.run()
        NSApp.terminate(nil)
    }

    private nonisolated static func run(_ tool: String, _ arguments: [String]) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: tool)
        process.arguments = arguments
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { throw UpdateError.badDownload }
    }

    private struct Release: Decodable {
        struct Asset: Decodable {
            let name: String
            let url: URL

            enum CodingKeys: String, CodingKey {
                case name
                case url = "browser_download_url"
            }
        }

        let tagName: String
        let page: URL
        let draft: Bool
        let prerelease: Bool
        let assets: [Asset]

        enum CodingKeys: String, CodingKey {
            case tagName = "tag_name"
            case page = "html_url"
            case draft, prerelease, assets
        }
    }
}
