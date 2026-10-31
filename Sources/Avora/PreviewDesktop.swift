import SwiftUI

/// A made-up Mac desktop for the preview, so a backdrop is judged around something that looks
/// like a real recording. Everything is sized in hundredths of the width.
struct PreviewDesktop: View {
    var body: some View {
        GeometryReader { proxy in
            let u = proxy.size.width / 100
            ZStack(alignment: .topLeading) {
                LinearGradient(colors: [Color(rgb: 0x163E52), Color(rgb: 0x3C7F86), Color(rgb: 0xE2B587)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                RadialGradient(colors: [.white.opacity(0.22), .clear], center: .init(x: 0.85, y: 0.1),
                               startRadius: 0, endRadius: 45 * u)
                MenuBar(u: u)
                BrowserWindow(u: u)
                    .frame(width: 62 * u, height: 44 * u)
                    .offset(x: 5 * u, y: 6.5 * u)
                EditorWindow(u: u)
                    .frame(width: 46 * u, height: 32.5 * u)
                    .offset(x: 48 * u, y: 20 * u)
                Dock(u: u)
                    .frame(width: proxy.size.width)
                    .offset(y: proxy.size.height - 8.4 * u)
                Pointer(u: u)
                    .offset(x: 69.5 * u, y: 34.6 * u)
            }
        }
    }
}

private struct MenuBar: View {
    let u: CGFloat

    var body: some View {
        HStack(spacing: 1.7 * u) {
            Image(systemName: "applelogo")
            Text("Code").fontWeight(.bold)
            ForEach(["File", "Edit", "View", "Window", "Help"], id: \.self) { Text($0) }
            Spacer()
            Image(systemName: "magnifyingglass")
            Image(systemName: "wifi")
            Image(systemName: "battery.75percent")
            Text("Sat 9:41")
        }
        .font(.system(size: 1.45 * u))
        .foregroundStyle(.white)
        .padding(.horizontal, 2 * u)
        .frame(height: 3.6 * u)
        .background(.black.opacity(0.22))
    }
}

/// The three window buttons.
private struct TrafficLights: View {
    let u: CGFloat

    var body: some View {
        HStack(spacing: 0.75 * u) {
            ForEach([0xFF5F57, 0xFEBC2E, 0x28C840] as [UInt32], id: \.self) { Circle().fill(Color(rgb: $0)).frame(width: 1.25 * u) }
        }
    }
}

private struct BrowserWindow: View {
    let u: CGFloat

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                HStack {
                    TrafficLights(u: u)
                    Spacer()
                }
                HStack(spacing: 0.6 * u) {
                    Image(systemName: "lock.fill").font(.system(size: 1.1 * u))
                    Text("docs.example.com").font(.system(size: 1.4 * u))
                }
                .foregroundStyle(Color(white: 0.35))
                .frame(width: 24 * u, height: 2.7 * u)
                .background(RoundedRectangle(cornerRadius: 0.8 * u).fill(Color(white: 0.89)))
            }
            .padding(.horizontal, 1.6 * u)
            .frame(height: 4.8 * u)
            .background(Color(white: 0.95))

            HStack(alignment: .top, spacing: 3 * u) {
                VStack(alignment: .leading, spacing: 1.3 * u) {
                    ForEach(["Introduction", "Install", "Recording", "Editing", "Export"], id: \.self) { item in
                        Text(item).font(.system(size: 1.4 * u, weight: item == "Recording" ? .semibold : .regular))
                            .foregroundStyle(item == "Recording" ? Color(rgb: 0xE07A3F) : Color(white: 0.4))
                    }
                }
                .frame(width: 11 * u, alignment: .leading)
                VStack(alignment: .leading, spacing: 1.2 * u) {
                    Text("Recording your screen").font(.system(size: 2.9 * u, weight: .bold)).foregroundStyle(Color(white: 0.12))
                    TextLines(u: u, widths: [0.95, 0.88, 0.6], color: Color(white: 0.82))
                    HStack(spacing: 1.4 * u) {
                        ForEach([[0xF2A65A, 0xE0685A], [0x6A8DFF, 0x9B6BFF], [0x4CC6A0, 0x2E8FB8]] as [[UInt32]], id: \.self) { colors in
                            RoundedRectangle(cornerRadius: 0.9 * u)
                                .fill(LinearGradient(colors: colors.map { Color(rgb: $0) }, startPoint: .topLeading, endPoint: .bottomTrailing))
                                .frame(height: 10 * u)
                        }
                    }
                    .padding(.top, 0.6 * u)
                    TextLines(u: u, widths: [0.9, 0.75], color: Color(white: 0.82))
                }
            }
            .padding(3 * u)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(.white)
        }
        .clipShape(RoundedRectangle(cornerRadius: 1.2 * u))
        .compositingGroup()
        .shadow(color: .black.opacity(0.3), radius: 2 * u, y: 0.8 * u)
    }
}

/// Grey bars standing in for paragraphs too small to read.
private struct TextLines: View {
    let u: CGFloat
    let widths: [CGFloat]
    let color: Color

    var body: some View {
        GeometryReader { proxy in
            VStack(alignment: .leading, spacing: 0.9 * u) {
                ForEach(widths.indices, id: \.self) { index in
                    Capsule().fill(color).frame(width: proxy.size.width * widths[index], height: 0.9 * u)
                }
            }
        }
        .frame(height: CGFloat(widths.count) * 1.8 * u)
    }
}

private struct EditorWindow: View {
    let u: CGFloat

    private static let keyword = Color(rgb: 0xFC5FA3)
    private static let type = Color(rgb: 0x5DD8FF)
    private static let number = Color(rgb: 0xD0BF69)
    private static let plain = Color(white: 0.9)

    /// Each line as runs of text and their color.
    private let lines: [[(String, Color)]] = [
        [("import", keyword), (" AVFoundation", plain)],
        [],
        [("struct", keyword), (" Recorder", type), (" {", plain)],
        [("    var", keyword), (" zoom = ", plain), ("2.0", number)],
        [],
        [("    func", keyword), (" start() ", plain), ("async throws", keyword), (" {", plain)],
        [("        let", keyword), (" screen = ", plain), ("Screen", type), (".main", plain)],
        [("        try await", keyword), (" record(screen)", plain)],
        [("    }", plain)],
        [("}", plain)],
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 2 * u) {
                TrafficLights(u: u)
                Text("Recorder.swift").font(.system(size: 1.4 * u)).foregroundStyle(Color(white: 0.75))
                Spacer()
            }
            .padding(.horizontal, 1.6 * u)
            .frame(height: 4.2 * u)
            .background(Color(rgb: 0x2A2A30))

            VStack(alignment: .leading, spacing: 0.55 * u) {
                ForEach(lines.indices, id: \.self) { index in
                    HStack(spacing: 2 * u) {
                        Text("\(index + 1)").foregroundStyle(Color(white: 0.4)).frame(width: 2.4 * u, alignment: .trailing)
                        lines[index].reduce(Text("")) { $0 + Text($1.0).foregroundStyle($1.1) }
                    }
                }
            }
            .font(.system(size: 1.5 * u, design: .monospaced))
            .padding(.horizontal, 1.6 * u)
            .padding(.top, 1.6 * u)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Color(rgb: 0x1F1F24))
        }
        .clipShape(RoundedRectangle(cornerRadius: 1.2 * u))
        .overlay(RoundedRectangle(cornerRadius: 1.2 * u).strokeBorder(.white.opacity(0.12), lineWidth: 0.1 * u))
        .compositingGroup()
        .shadow(color: .black.opacity(0.45), radius: 2.4 * u, y: 1 * u)
    }
}

private struct Dock: View {
    let u: CGFloat

    private let apps: [(symbol: String, colors: [UInt32])] = [
        ("face.smiling", [0x6CC4FF, 0x1E73E8]),
        ("safari", [0x5AC8FA, 0x0A6CFF]),
        ("message.fill", [0x6FE07A, 0x22B04B]),
        ("envelope.fill", [0x67B7FF, 0x1C6EF2]),
        ("music.note", [0xFF6B81, 0xF2264B]),
        ("terminal", [0x3A3A40, 0x141418]),
        ("gearshape.fill", [0xB9B9C0, 0x7C7C86]),
    ]

    var body: some View {
        HStack(spacing: 0.9 * u) {
            ForEach(apps.indices, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1.1 * u)
                    .fill(LinearGradient(colors: apps[index].colors.map { Color(rgb: $0) }, startPoint: .top, endPoint: .bottom))
                    .frame(width: 4.6 * u, height: 4.6 * u)
                    .overlay(Image(systemName: apps[index].symbol).font(.system(size: 2.3 * u, weight: .medium)).foregroundStyle(.white))
            }
        }
        .padding(0.8 * u)
        .background(RoundedRectangle(cornerRadius: 1.8 * u).fill(.white.opacity(0.22)))
        .overlay(RoundedRectangle(cornerRadius: 1.8 * u).strokeBorder(.white.opacity(0.3), lineWidth: 0.1 * u))
    }
}

/// Avora's cursor in the middle of a click, drawn like the arrow in its videos.
private struct Pointer: View {
    let u: CGFloat

    var body: some View {
        let scale = 0.17 * u
        let arrow = Path { path in
            path.addLines([CGPoint(x: 0, y: 0), CGPoint(x: 0, y: 16), CGPoint(x: 4, y: 12.4), CGPoint(x: 6.6, y: 18.2),
                           CGPoint(x: 9.2, y: 17.1), CGPoint(x: 6.7, y: 11.5), CGPoint(x: 11.6, y: 11.5)])
            path.closeSubpath()
        }
        .applying(CGAffineTransform(scaleX: scale, y: scale))
        ZStack(alignment: .topLeading) {
            Circle().strokeBorder(.white.opacity(0.85), lineWidth: 0.35 * u)
                .frame(width: 4.4 * u, height: 4.4 * u)
                .offset(x: -2.2 * u, y: -2.2 * u)
            arrow.fill(.black)
            arrow.stroke(.white, style: StrokeStyle(lineWidth: 2.2 * scale, lineJoin: .round))
        }
        .shadow(color: .black.opacity(0.35), radius: 0.4 * u, y: 0.2 * u)
    }
}
