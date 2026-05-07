import AppKit
import CoreGraphics
import DockDockCore

enum DisplayGeometry {
    static func bounds(containing point: CGPoint) -> CGRect? {
        displayInfo(containing: point)?.bounds
    }

    static func dockDisplayTarget(edge: DockEdge) -> DockDisplayTarget? {
        let displays = activeDisplays()
        guard !displays.isEmpty else {
            let mainDisplay = CGMainDisplayID()
            return DockDisplayTarget(
                displayID: mainDisplay,
                bounds: CGDisplayBounds(mainDisplay),
                dockClearance: estimatedDockThickness()
            )
        }

        let estimatedThickness = estimatedDockThickness()
        let targets = displays.map { display -> (target: DockDisplayTarget, reservedThickness: CGFloat) in
            let screen = screen(for: display)
            let reservedThickness = screen.map { reservedDockThickness(on: $0, edge: edge) } ?? 0
            return (
                DockDisplayTarget(
                    displayID: display,
                    bounds: CGDisplayBounds(display),
                    dockClearance: max(reservedThickness, estimatedThickness)
                ),
                reservedThickness
            )
        }

        if let visibleDockTarget = targets
            .filter({ $0.reservedThickness > 1 })
            .max(by: { $0.reservedThickness < $1.reservedThickness }) {
            return visibleDockTarget.target
        }

        let mainDisplay = CGMainDisplayID()
        return targets.first { $0.target.displayID == mainDisplay }?.target ?? targets.first?.target
    }

    static func dockClearance(containing point: CGPoint, edge: DockEdge) -> CGFloat {
        guard let info = displayInfo(containing: point),
              let screen = screen(for: info.displayID) else {
            return estimatedDockThickness()
        }

        let reservedThickness = reservedDockThickness(on: screen, edge: edge)
        return max(reservedThickness, estimatedDockThickness())
    }

    private static func displayInfo(containing point: CGPoint) -> (displayID: CGDirectDisplayID, bounds: CGRect)? {
        let displays = activeDisplays()
        guard !displays.isEmpty else {
            let mainDisplay = CGMainDisplayID()
            return (mainDisplay, CGDisplayBounds(mainDisplay))
        }

        for display in displays {
            let bounds = CGDisplayBounds(display)
            if bounds.contains(point) {
                return (display, bounds)
            }
        }

        let mainDisplay = CGMainDisplayID()
        return (mainDisplay, CGDisplayBounds(mainDisplay))
    }

    private static func activeDisplays() -> [CGDirectDisplayID] {
        var displayCount: UInt32 = 0
        guard CGGetActiveDisplayList(0, nil, &displayCount) == .success, displayCount > 0 else {
            return []
        }

        var displays = [CGDirectDisplayID](repeating: 0, count: Int(displayCount))
        guard CGGetActiveDisplayList(displayCount, &displays, &displayCount) == .success else {
            return []
        }

        return Array(displays.prefix(Int(displayCount)))
    }

    private static func screen(for displayID: CGDirectDisplayID) -> NSScreen? {
        NSScreen.screens.first { screen in
            guard let screenNumber = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
                return false
            }

            return screenNumber.uint32Value == displayID
        }
    }

    private static func reservedDockThickness(on screen: NSScreen, edge: DockEdge) -> CGFloat {
        switch edge {
        case .bottom:
            screen.visibleFrame.minY - screen.frame.minY
        case .left:
            screen.visibleFrame.minX - screen.frame.minX
        case .right:
            screen.frame.maxX - screen.visibleFrame.maxX
        }
    }

    private static func estimatedDockThickness() -> CGFloat {
        let tileSize = UserDefaults(suiteName: "com.apple.dock")?
            .object(forKey: "tilesize") as? NSNumber
        let clampedTileSize = min(max(CGFloat(tileSize?.doubleValue ?? 64), 16), 128)
        return clampedTileSize + 36
    }
}
