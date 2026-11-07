import SwiftUI
import ZoomEngine

struct EditorView: View {
    @ObservedObject var model: EditorModel
    @State private var cropping = false
    @State private var tab = InspectorTab.edit

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider().overlay(Palette.border)
            HStack(spacing: 0) {
                VStack(spacing: 10) {
                    PlayerView(player: model.player)
                        .background(Palette.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    transport
                }
                .padding(16)
                Divider().overlay(Palette.border)
                EditorInspector(model: model, preferences: model.preferences, tab: $tab)
                    .frame(width: 350)
            }
            .frame(maxHeight: .infinity)
            Divider().overlay(Palette.border)
            EditorTimeline(model: model)
                .padding(.horizontal, 16).padding(.top, 10).padding(.bottom, 14)
        }
        .background(Palette.background)
        .foregroundStyle(Palette.foreground)
        .tint(Palette.tint)
        .preferredColorScheme(.dark)
        .onChange(of: model.selection) { _, selection in
            if selection != nil { tab = .edit }
        }
        .sheet(isPresented: $cropping) { CropSheet(model: model, isPresented: $cropping) }
        .alert("Avora", isPresented: Binding(get: { model.errorMessage != nil }, set: { if !$0 { model.errorMessage = nil } })) {
            Button("OK") { model.errorMessage = nil }
        } message: {
            Text(model.errorMessage ?? "")
        }
    }

    private var toolbar: some View {
        HStack(spacing: 10) {
            ControlGroup {
                Button { model.undo() } label: { Image(systemName: "arrow.uturn.backward") }
                    .disabled(!model.canUndo).help("Undo (⌘Z)")
                Button { model.redo() } label: { Image(systemName: "arrow.uturn.forward") }
                    .disabled(!model.canRedo).help("Redo (⇧⌘Z)")
            }
            .fixedSize()
            Divider().frame(height: 18)
            Button { model.splitAtPlayhead() } label: { Label("Split", systemImage: "scissors") }
                .help("Split the clip at the playhead (S)")
            Button { cropping = true } label: { Label(model.crop == nil ? "Crop" : "Cropped", systemImage: "crop") }
                .help("Keep only part of the recording")
            if let progress = model.scanProgress {
                ProgressView(value: progress).frame(width: 80)
                Text("Scanning \(Int(progress * 100))%").font(.system(size: 12)).monospacedDigit()
            } else {
                Menu {
                    Button("Blur Private Info") { Task { await model.blurAutomatically(.text) } }
                    Button("Blur Faces") { Task { await model.blurAutomatically(.faces) } }
                } label: {
                    Label("Auto Blur", systemImage: "eye.slash")
                }
                .fixedSize()
                .help("Find email addresses, phone and card numbers, IBANs, keys or faces on screen and blur them")
            }
            if !model.typing.isEmpty {
                Button { model.speedUpTyping() } label: { Label("Speed Up Typing", systemImage: "keyboard") }
                    .help("Play every stretch of steady typing at 3×")
            }
            Button { Task { await model.generateCaptions() } } label: {
                if model.isTranscribing {
                    ProgressView().controlSize(.small)
                } else {
                    Label(model.hasCaptions ? "Redo Captions" : "Captions", systemImage: "captions.bubble")
                }
            }
            .disabled(model.isTranscribing)
            .help("Turn what was said into captions, on this Mac")
            Spacer()
            Button("Reset Zooms") { model.resetZooms() }
                .help("Go back to the zooms made from your clicks")
            if let progress = model.exportProgress {
                ProgressView(value: progress).frame(width: 120)
                Text("Exporting \(Int(progress * 100))%").font(.system(size: 12)).monospacedDigit()
            } else {
                HStack(spacing: 4) {
                    Button { Task { await model.export(copy: false) } } label: { Label("Export", systemImage: "square.and.arrow.up") }
                        .buttonStyle(SolidButtonStyle())
                        .keyboardShortcut("e", modifiers: .command)
                        .help("Save a new video (⌘E)")
                    Menu {
                        Button("Export and Copy") { Task { await model.export(copy: true) } }
                        Divider()
                        Button("Copy Frame") { Task { await model.copyFrame() } }
                        Button("Save Frame…") { Task { await model.saveFrame() } }
                    } label: {
                        Image(systemName: "ellipsis")
                    }
                    .menuStyle(.borderlessButton)
                    .menuIndicator(.hidden)
                    .fixedSize()
                    .help("More ways to export")
                }
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 48)
    }

    private var transport: some View {
        HStack(spacing: 6) {
            Button { model.seek(to: 0) } label: { Image(systemName: "backward.end.fill") }
                .help("Go to the start")
            Button { model.step(by: -0.1) } label: { Image(systemName: "backward.frame.fill") }
                .help("Back 0.1 s (←)")
            Button { model.togglePlay() } label: {
                Image(systemName: model.isPlaying ? "pause.fill" : "play.fill").frame(width: 22)
            }
            .controlSize(.large)
            .help("Play or pause (Space)")
            Button { model.step(by: 0.1) } label: { Image(systemName: "forward.frame.fill") }
                .help("Forward 0.1 s (→)")
            Button { model.seek(to: model.duration) } label: { Image(systemName: "forward.end.fill") }
                .help("Go to the end")
            Text("\(clock(model.videoTime)) / \(clock(model.clips.outputDuration))")
                .font(.system(size: 12.5, design: .monospaced)).foregroundStyle(.secondary)
                .padding(.leading, 8)
            Spacer()
            if let index = model.zooms.index(at: model.time) {
                Text(String(format: "Zoom %d · %.1f×", index + 1, model.zooms.segments[index].scale))
                    .font(.system(size: 11.5, weight: .medium)).monospacedDigit()
                    .padding(.horizontal, 9).padding(.vertical, 3)
                    .background(Lane.zooms.color.opacity(0.22), in: Capsule())
            }
        }
        .buttonStyle(.bordered)
    }
}

/// Rounded, so a zoom at 10.699999 s reads 0:10.70.
func clock(_ seconds: Double) -> String {
    let hundredths = Int((max(seconds, 0) * 100).rounded())
    return String(format: "%d:%02d.%02d", hundredths / 6000, hundredths / 100 % 60, hundredths % 100)
}

/// A still of the recording with a dot for the manual focus point, in fractions of the frame.
struct FocusPicker: View {
    let image: CGImage?
    let focus: CGPoint
    let change: (CGPoint) -> Void

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            ZStack(alignment: .topLeading) {
                if let image {
                    Image(decorative: image, scale: 1).resizable()
                } else {
                    Rectangle().fill(.white.opacity(0.05))
                }
                Circle().strokeBorder(.white, lineWidth: 2).background(Circle().fill(Lane.zooms.color))
                    .frame(width: 14, height: 14)
                    .shadow(radius: 2)
                    .position(x: focus.x * size.width, y: focus.y * size.height)
            }
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0).onEnded { value in
                change(CGPoint(x: min(max(value.location.x / size.width, 0), 1), y: min(max(value.location.y / size.height, 0), 1)))
            })
        }
        .aspectRatio(image.map { CGFloat($0.width) / CGFloat($0.height) } ?? 16 / 10, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

/// A still of the recording with a rectangle to drag and resize. Fractions use a top-left origin.
struct RectEditor: View {
    let image: CGImage?
    @Binding var rect: CGRect
    var minimum = 0.05
    @State private var origin: CGRect?

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let hole = CGRect(x: rect.minX * size.width, y: rect.minY * size.height, width: rect.width * size.width, height: rect.height * size.height)
            ZStack(alignment: .topLeading) {
                if let image { Image(decorative: image, scale: 1).resizable() } else { Color.white.opacity(0.05) }
                Path { path in
                    path.addRect(CGRect(origin: .zero, size: size))
                    path.addRect(hole)
                }
                .fill(Color.black.opacity(0.55), style: FillStyle(eoFill: true))
                Rectangle().strokeBorder(Palette.foreground, lineWidth: 2)
                    .frame(width: hole.width, height: hole.height)
                    .offset(x: hole.minX, y: hole.minY)
                    .contentShape(Rectangle())
                    .gesture(drag(size: size) { start, dx, dy in
                        CGRect(x: min(max(start.minX + dx, 0), 1 - start.width), y: min(max(start.minY + dy, 0), 1 - start.height),
                               width: start.width, height: start.height)
                    })
                ForEach(0..<4, id: \.self) { corner in
                    let left = corner % 2 == 0, top = corner < 2
                    Circle().fill(.white).frame(width: 12, height: 12).shadow(radius: 2)
                        .position(x: left ? hole.minX : hole.maxX, y: top ? hole.minY : hole.maxY)
                        .gesture(drag(size: size) { start, dx, dy in resize(start, dx: dx, dy: dy, left: left, top: top) })
                }
            }
        }
        .aspectRatio(image.map { CGFloat($0.width) / CGFloat($0.height) } ?? 16 / 10, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private func drag(size: CGSize, _ update: @escaping (CGRect, Double, Double) -> CGRect) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let start = origin ?? rect
                origin = start
                rect = update(start, value.translation.width / size.width, value.translation.height / size.height)
            }
            .onEnded { _ in origin = nil }
    }

    private func resize(_ start: CGRect, dx: Double, dy: Double, left: Bool, top: Bool) -> CGRect {
        var minX = start.minX, minY = start.minY, maxX = start.maxX, maxY = start.maxY
        if left { minX = min(max(minX + dx, 0), maxX - minimum) } else { maxX = max(min(maxX + dx, 1), minX + minimum) }
        if top { minY = min(max(minY + dy, 0), maxY - minimum) } else { maxY = max(min(maxY + dy, 1), minY + minimum) }
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
}

/// Picks the part of the recording to keep.
private struct CropSheet: View {
    @ObservedObject var model: EditorModel
    @Binding var isPresented: Bool
    @State private var image: CGImage?
    @State private var rect = CGRect(x: 0, y: 0, width: 1, height: 1)

    var body: some View {
        VStack(spacing: 14) {
            Text("Crop the recording").font(.headline)
            RectEditor(image: image, rect: $rect, minimum: 0.1).frame(width: 720)
            HStack {
                Button("Reset") { rect = CGRect(x: 0, y: 0, width: 1, height: 1) }
                Spacer()
                Button("Cancel") { isPresented = false }.keyboardShortcut(.cancelAction)
                Button("Done") {
                    model.setCrop(rect)
                    isPresented = false
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 760)
        .task {
            rect = model.crop ?? CGRect(x: 0, y: 0, width: 1, height: 1)
            image = await model.still(at: model.time, maxSide: 1440)
        }
    }
}
