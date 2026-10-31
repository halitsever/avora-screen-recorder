import Foundation

/// `Avora render <recording-folder> [output] [options]` re-renders a raw recording without the UI.
/// Options left out fall back to the settings picked in the app.
enum RenderCommand {
    static let usage = """
        usage: Avora render <recording-folder> [output] [--background <id>] [--motion-blur <0-1>]
                            [--format h264|hevc|prores|gif] [--preset <name>] [--setting <key>=<value>]...

        """

    static func run(_ arguments: [String]) -> Never {
        var positional: [String] = []
        var settings = Preferences.shared.settings
        var background = Preferences.shared.background
        var remaining = arguments[...]
        while let argument = remaining.popFirst() {
            switch argument {
            case "--background":
                let id = remaining.popFirst() ?? ""
                let preset = BackgroundPreset.named(id)
                guard preset.id == BackgroundPreset.defaultID ? id == BackgroundPreset.defaultID : true else {
                    fail("unknown background; use color:RRGGBB, image:<path>, wallpaper or one of: \(BackgroundPreset.all.map(\.id).joined(separator: ", "))", code: 64)
                }
                background = preset
            case "--motion-blur":
                guard let value = remaining.popFirst().flatMap(Double.init), (0...1).contains(value) else {
                    fail("--motion-blur takes a number from 0 to 1", code: 64)
                }
                settings.motionBlur = value
            case "--preset":
                guard let name = remaining.popFirst(), let preset = Preferences.shared.presets.first(where: { $0.name == name }) else {
                    fail("--preset takes a preset saved in Avora's settings: \(Preferences.shared.presets.map(\.name).joined(separator: ", "))", code: 64)
                }
                settings = preset.settings
                background = BackgroundPreset.named(preset.backgroundID)
            case "--setting":
                guard let pair = remaining.popFirst(), let changed = settings.setting(pair) else {
                    fail("--setting takes key=value, for example clickEffect=ripple or padding=0.1", code: 64)
                }
                settings = changed
            case "--format":
                guard let format = remaining.popFirst().flatMap(RenderSettings.Format.init(rawValue:)) else {
                    fail("--format takes one of: \(RenderSettings.Format.allCases.map(\.rawValue).joined(separator: ", "))", code: 64)
                }
                settings.format = format
            default:
                positional.append(argument)
            }
        }
        guard let path = positional.first else { fail(usage, code: 64) }
        let style = OutputStyle(settings: settings, background: background)

        let folder = RecordingFolder(url: URL(fileURLWithPath: path, isDirectory: true))
        let output = positional.count > 1
            ? URL(fileURLWithPath: positional[1])
            : folder.url.appending(path: "output.\(style.format.fileExtension)")

        let done = DispatchSemaphore(value: 0)
        nonisolated(unsafe) var failure: Error?
        Task.detached {
            do {
                try await Exporter.export(folder, to: output, style: style) { value in
                    FileHandle.standardError.write(Data(String(format: "\rrendering %3.0f%%", value * 100).utf8))
                }
            } catch {
                failure = error
            }
            done.signal()
        }
        done.wait()

        if let failure { fail("\n\(failure.localizedDescription)", code: 1) }
        print("\n\(output.path)")
        exit(0)
    }

    private static func fail(_ message: String, code: Int32) -> Never {
        FileHandle.standardError.write(Data((message.hasSuffix("\n") ? message : message + "\n").utf8))
        exit(code)
    }
}

extension RenderSettings {
    /// One setting changed from `key=value` text, or nil when the key or value does not fit.
    func setting(_ pair: String) -> RenderSettings? {
        let parts = pair.split(separator: "=", maxSplits: 1).map(String.init)
        guard parts.count == 2,
              let data = try? JSONEncoder().encode(self),
              var object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              object[parts[0]] != nil
        else { return nil }
        let text = parts[1]
        object[parts[0]] = Bool(text).map { $0 as Any } ?? Double(text).map { $0 as Any } ?? text
        guard let patched = try? JSONSerialization.data(withJSONObject: object),
              let result = try? JSONDecoder().decode(RenderSettings.self, from: patched),
              let check = try? JSONSerialization.jsonObject(with: JSONEncoder().encode(result)) as? [String: Any],
              // Decoding falls back to defaults, so a value that did not survive the round trip was rejected.
              let kept = check[parts[0]] as? NSObject, kept.isEqual(object[parts[0]])
        else { return nil }
        return result
    }
}
