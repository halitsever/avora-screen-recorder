import Foundation

/// `Avora render <recording-folder> [output.mp4] [--background <id>]` re-renders a raw recording
/// without the UI. The background defaults to the one picked in the app.
enum RenderCommand {
    static let usage = "usage: Avora render <recording-folder> [output.mp4] [--background <id>]\n"

    static func run(_ arguments: [String]) -> Never {
        var positional: [String] = []
        var background = Preferences.shared.background
        var remaining = arguments[...]
        while let argument = remaining.popFirst() {
            guard argument == "--background" else {
                positional.append(argument)
                continue
            }
            guard let id = remaining.popFirst(), let preset = BackgroundPreset.all.first(where: { $0.id == id }) else {
                fail("unknown background; choose one of: \(BackgroundPreset.all.map(\.id).joined(separator: ", "))", code: 64)
            }
            background = preset
        }
        guard let path = positional.first else { fail(usage, code: 64) }

        let folder = RecordingFolder(url: URL(fileURLWithPath: path, isDirectory: true))
        let output = positional.count > 1
            ? URL(fileURLWithPath: positional[1])
            : folder.url.appending(path: "output.mp4")

        let done = DispatchSemaphore(value: 0)
        nonisolated(unsafe) var failure: Error?
        Task.detached {
            do {
                try await Exporter.export(folder, to: output, style: OutputStyle(background: background)) { value in
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
