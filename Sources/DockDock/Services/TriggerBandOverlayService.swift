import AppKit
import DockDockCore

@MainActor
final class TriggerBandOverlayService: ObservableObject {
    private var windows: [NSWindow] = []
    private var hideTask: Task<Void, Never>?

    func show(settings: AppSettings, autoHideAfter delay: TimeInterval? = 1.4) {
        show(activationBand: CGFloat(settings.activationBand), edge: settings.dockEdge, autoHideAfter: delay)
    }

    func show(activationBand: CGFloat, edge: DockEdge, autoHideAfter delay: TimeInterval? = 1.4) {
        hideTask?.cancel()
        closeWindows()

        let band = max(2, min(activationBand, 240))
        windows = NSScreen.screens.map { screen in
            let frame = overlayFrame(for: screen.frame, band: band, edge: edge)
            let panel = NSPanel(
                contentRect: frame,
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )

            panel.isOpaque = false
            panel.backgroundColor = .clear
            panel.ignoresMouseEvents = true
            panel.level = .screenSaver
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
            panel.contentView = TriggerBandOverlayView(edge: edge)
            panel.orderFrontRegardless()
            return panel
        }

        if let delay {
            hideTask = Task { [weak self] in
                try? await Task.sleep(for: .seconds(delay))
                self?.hide()
            }
        }
    }

    func hide() {
        hideTask?.cancel()
        hideTask = nil
        closeWindows()
    }

    private func closeWindows() {
        windows.forEach { $0.close() }
        windows.removeAll()
    }

    private func overlayFrame(for screenFrame: CGRect, band: CGFloat, edge: DockEdge) -> CGRect {
        switch edge {
        case .bottom:
            CGRect(x: screenFrame.minX, y: screenFrame.minY, width: screenFrame.width, height: band)
        case .left:
            CGRect(x: screenFrame.minX, y: screenFrame.minY, width: band, height: screenFrame.height)
        case .right:
            CGRect(x: screenFrame.maxX - band, y: screenFrame.minY, width: band, height: screenFrame.height)
        }
    }
}

private final class TriggerBandOverlayView: NSView {
    private let edge: DockEdge

    init(edge: DockEdge) {
        self.edge = edge
        super.init(frame: .zero)
        wantsLayer = true
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.systemBlue.withAlphaComponent(0.18).setFill()
        bounds.fill()

        NSColor.systemBlue.withAlphaComponent(0.85).setStroke()
        let path = NSBezierPath()
        path.lineWidth = 2

        switch edge {
        case .bottom:
            path.move(to: CGPoint(x: bounds.minX, y: bounds.maxY - 1))
            path.line(to: CGPoint(x: bounds.maxX, y: bounds.maxY - 1))
        case .left:
            path.move(to: CGPoint(x: bounds.maxX - 1, y: bounds.minY))
            path.line(to: CGPoint(x: bounds.maxX - 1, y: bounds.maxY))
        case .right:
            path.move(to: CGPoint(x: bounds.minX + 1, y: bounds.minY))
            path.line(to: CGPoint(x: bounds.minX + 1, y: bounds.maxY))
        }

        path.stroke()
    }
}
