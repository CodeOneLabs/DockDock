import CoreGraphics

enum DisplayGeometry {
    static func bounds(containing point: CGPoint) -> CGRect? {
        var displayCount: UInt32 = 0
        guard CGGetActiveDisplayList(0, nil, &displayCount) == .success, displayCount > 0 else {
            return CGDisplayBounds(CGMainDisplayID())
        }

        var displays = [CGDirectDisplayID](repeating: 0, count: Int(displayCount))
        guard CGGetActiveDisplayList(displayCount, &displays, &displayCount) == .success else {
            return CGDisplayBounds(CGMainDisplayID())
        }

        for display in displays.prefix(Int(displayCount)) {
            let bounds = CGDisplayBounds(display)
            if bounds.contains(point) {
                return bounds
            }
        }

        return CGDisplayBounds(CGMainDisplayID())
    }
}
