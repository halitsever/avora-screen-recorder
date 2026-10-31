import AppKit

let arguments = Array(CommandLine.arguments.dropFirst())

if arguments.first == "render" {
    RenderCommand.run(Array(arguments.dropFirst()))
}

MainActor.assumeIsolated {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.setActivationPolicy(.accessory)
    app.run()
}
