import AppKit

/// What the user picked on the selection overlay, in global (Quartz) points.
struct CaptureSelection {
    let rect: CGRect
    /// The picked window, followed while it is recorded; nil for a dragged area.
    let window: (id: CGWindowID, owner: pid_t)?
}

/// A dimmed layer over every display for picking a window or dragging out an area.
@MainActor
final class SelectionOverlay {
    private let mode: CaptureMode
    private var windows: [OverlayWindow] = []
    private var continuation: CheckedContinuation<CaptureSelection?, Never>?
    private let candidates: [(rect: CGRect, id: CGWindowID, owner: pid_t)]

    fileprivate var dragStart: CGPoint?
    fileprivate var selection: CGRect?
    fileprivate var hovered: (rect: CGRect, id: CGWindowID, owner: pid_t)?

    /// nil when the user presses Esc.
    static func pick(_ mode: CaptureMode) async -> CaptureSelection? {
        let overlay = SelectionOverlay(mode: mode)
        return await withCheckedContinuation { overlay.show(resuming: $0) }
    }

    private init(mode: CaptureMode) {
        self.mode = mode
        candidates = mode == .window ? Self.visibleWindows() : []
    }

    fileprivate var hint: String {
        switch mode {
        case .window: "Click a window to record it. Esc cancels."
        case .area: selection == nil ? "Drag to select an area. Esc cancels." : "Return or Record starts. Drag again to change it. Esc cancels."
        case .screen: ""
        }
    }

    private func show(resuming continuation: CheckedContinuation<CaptureSelection?, Never>) {
        self.continuation = continuation
        windows = NSScreen.screens.map { OverlayWindow(screen: $0, overlay: self) }
        windows.forEach { $0.orderFrontRegardless() }
        let mouse = NSEvent.mouseLocation
        (windows.first { $0.frame.contains(mouse) } ?? windows.first)?.makeKey()
        NSApp.activate(ignoringOtherApps: true)
        NSCursor.crosshair.push()
        moved(to: Self.globalMouse())
    }

    fileprivate func finish(_ result: CaptureSelection?) {
        guard let continuation else { return }
        self.continuation = nil
        NSCursor.pop()
        windows.forEach { $0.orderOut(nil) }
        windows = []
        continuation.resume(returning: result)
    }

    fileprivate func confirm() {
        if let selection { finish(CaptureSelection(rect: selection, window: nil)) }
    }

    fileprivate func moved(to point: CGPoint) {
        guard mode == .window else { return }
        hovered = candidates.first { $0.rect.contains(point) }
        redraw()
    }

    fileprivate func pressed(at point: CGPoint) {
        switch mode {
        case .window:
            if let hovered { finish(CaptureSelection(rect: hovered.rect, window: (hovered.id, hovered.owner))) }
        case .area:
            dragStart = point
            selection = nil
            redraw()
        case .screen:
            break
        }
    }

    fileprivate func dragged(to point: CGPoint) {
        guard mode == .area, let dragStart, let display = Self.displayBounds(containing: dragStart) else { return }
        selection = CaptureGeometry.selection(from: dragStart, to: point, within: display)
        redraw()
    }

    fileprivate func redraw() {
        windows.forEach { $0.refresh() }
    }

    static func globalMouse() -> CGPoint {
        CGEvent(source: nil)?.location ?? .zero
    }

    private static func displayBounds(containing point: CGPoint) -> CGRect? {
        var count: UInt32 = 0
        var display = CGDirectDisplayID()
        guard CGGetDisplaysWithPoint(point, 1, &display, &count) == .success, count > 0 else { return nil }
        return CGDisplayBounds(display)
    }

    /// Normal app windows of other apps, front to back.
    private static func visibleWindows() -> [(rect: CGRect, id: CGWindowID, owner: pid_t)] {
        let info = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
        let ownPID = ProcessInfo.processInfo.processIdentifier
        return info.compactMap { window in
            guard (window[kCGWindowLayer as String] as? Int) == 0,
                  let owner = window[kCGWindowOwnerPID as String] as? pid_t, owner != ownPID,
                  let id = window[kCGWindowNumber as String] as? CGWindowID,
                  (window[kCGWindowAlpha as String] as? Double ?? 1) > 0,
                  let bounds = window[kCGWindowBounds as String] as? NSDictionary,
                  let rect = CGRect(dictionaryRepresentation: bounds),
                  rect.width >= CaptureGeometry.minimumSize, rect.height >= CaptureGeometry.minimumSize
            else { return nil }
            return (rect, id, owner)
        }
    }
}

private final class OverlayWindow: NSWindow {
    private unowned let overlay: SelectionOverlay
    private let canvas: OverlayView

    init(screen: NSScreen, overlay: SelectionOverlay) {
        self.overlay = overlay
        canvas = OverlayView(overlay: overlay)
        super.init(contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false)
        setFrame(screen.frame, display: false)
        level = .screenSaver
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false
        acceptsMouseMovedEvents = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        isReleasedWhenClosed = false
        contentView = canvas
    }

    override var canBecomeKey: Bool { true }

    func refresh() {
        canvas.needsDisplay = true
        canvas.updateRecordButton()
    }
}

private final class OverlayView: NSView {
    private unowned let overlay: SelectionOverlay
    private lazy var recordButton: NSButton = {
        let button = NSButton(title: "Record", target: self, action: #selector(record))
        button.bezelStyle = .rounded
        button.keyEquivalent = "\r"
        button.bezelColor = Brand.orangeColor
        button.isHidden = true
        addSubview(button)
        return button
    }()

    init(overlay: SelectionOverlay) {
        self.overlay = overlay
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(rect: bounds, options: [.mouseMoved, .activeAlways, .inVisibleRect], owner: self))
    }

    override func mouseMoved(with event: NSEvent) { overlay.moved(to: SelectionOverlay.globalMouse()) }
    override func mouseDown(with event: NSEvent) { overlay.pressed(at: SelectionOverlay.globalMouse()) }
    override func mouseDragged(with event: NSEvent) { overlay.dragged(to: SelectionOverlay.globalMouse()) }

    override func keyDown(with event: NSEvent) {
        switch Int(event.keyCode) {
        case 53: overlay.finish(nil)
        case 36, 76: overlay.confirm()
        default: super.keyDown(with: event)
        }
    }

    override func cancelOperation(_ sender: Any?) { overlay.finish(nil) }

    @objc private func record() { overlay.confirm() }

    /// A global rect in this view's coordinates.
    private func local(_ rect: CGRect) -> CGRect? {
        guard let window, let mainHeight = NSScreen.screens.first?.frame.height else { return nil }
        let cocoa = CaptureGeometry.cocoaRect(fromGlobal: rect, mainHeight: mainHeight)
        let inWindow = cocoa.offsetBy(dx: -window.frame.minX, dy: -window.frame.minY)
        return inWindow.intersects(bounds) ? inWindow : nil
    }

    private var highlighted: CGRect? {
        (overlay.selection ?? overlay.hovered?.rect).flatMap(local)
    }

    func updateRecordButton() {
        guard overlay.dragStart != nil, let hole = overlay.selection.flatMap(local) else {
            recordButton.isHidden = true
            return
        }
        recordButton.sizeToFit()
        let size = CGSize(width: recordButton.frame.width + 24, height: recordButton.frame.height)
        let below = hole.minY - size.height - 14 > bounds.minY + 10
        let y = below ? hole.minY - size.height - 14 : hole.minY + 14
        recordButton.frame = CGRect(x: hole.midX - size.width / 2, y: y, width: size.width, height: size.height)
        recordButton.isHidden = false
    }

    override func draw(_ dirtyRect: NSRect) {
        let dim = NSBezierPath(rect: bounds)
        if let hole = highlighted {
            dim.append(NSBezierPath(rect: hole))
            dim.windingRule = .evenOdd
        }
        NSColor.black.withAlphaComponent(0.38).setFill()
        dim.fill()

        if let hole = highlighted {
            let border = NSBezierPath(rect: hole.insetBy(dx: -1, dy: -1))
            border.lineWidth = 2
            Brand.orangeColor.setStroke()
            border.stroke()
            if let rect = overlay.selection ?? overlay.hovered?.rect {
                drawPill("\(Int(rect.width)) × \(Int(rect.height))", centeredAt: CGPoint(x: hole.midX, y: min(hole.maxY + 18, bounds.maxY - 18)))
            }
        }
        drawPill(overlay.hint, centeredAt: CGPoint(x: bounds.midX, y: bounds.maxY - 60))
    }

    private func drawPill(_ text: String, centeredAt center: CGPoint) {
        guard !text.isEmpty else { return }
        let attributes: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 13, weight: .medium), .foregroundColor: NSColor.white]
        let label = NSAttributedString(string: text, attributes: attributes)
        let size = label.size()
        let pill = CGRect(x: center.x - size.width / 2 - 12, y: center.y - size.height / 2 - 6, width: size.width + 24, height: size.height + 12)
        NSColor(white: 0.08, alpha: 0.85).setFill()
        NSBezierPath(roundedRect: pill, xRadius: pill.height / 2, yRadius: pill.height / 2).fill()
        label.draw(at: CGPoint(x: pill.minX + 12, y: pill.minY + 6))
    }
}
