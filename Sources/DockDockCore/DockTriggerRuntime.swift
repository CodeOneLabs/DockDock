import CoreGraphics
import Foundation

public struct DockDisplayTarget: Equatable {
    public var displayID: CGDirectDisplayID
    public var bounds: CGRect
    public var dockClearance: CGFloat

    public init(displayID: CGDirectDisplayID, bounds: CGRect, dockClearance: CGFloat) {
        self.displayID = displayID
        self.bounds = bounds
        self.dockClearance = dockClearance
    }
}

public struct DockTriggerRuntimeConfiguration: Equatable {
    public var isEnabled: Bool
    public var activationBand: CGFloat
    public var dockEdge: DockEdge
    public var isSnapSoundEnabled: Bool
    public var isFrontmostAppExcluded: Bool
    public var dockDisplay: DockDisplayTarget?

    public init(
        isEnabled: Bool = false,
        activationBand: CGFloat = 15,
        dockEdge: DockEdge = .bottom,
        isSnapSoundEnabled: Bool = true,
        isFrontmostAppExcluded: Bool = false,
        dockDisplay: DockDisplayTarget? = nil
    ) {
        self.isEnabled = isEnabled
        self.activationBand = activationBand
        self.dockEdge = dockEdge
        self.isSnapSoundEnabled = isSnapSoundEnabled
        self.isFrontmostAppExcluded = isFrontmostAppExcluded
        self.dockDisplay = dockDisplay
    }
}

public struct DockTriggerSnap: Equatable {
    public var point: CGPoint
    public var shouldPlaySound: Bool

    public init(point: CGPoint, shouldPlaySound: Bool) {
        self.point = point
        self.shouldPlaySound = shouldPlaySound
    }
}

public final class DockTriggerRuntime {
    private let lock = NSLock()
    private var configuration = DockTriggerRuntimeConfiguration()
    private var lastSnapTime: TimeInterval = 0
    private var lastPointerLocation: CGPoint?
    private var isSnapArmed = true

    public init() {}

    public func updateConfiguration(_ configuration: DockTriggerRuntimeConfiguration) {
        lock.withLock {
            self.configuration = configuration
            if !configuration.isEnabled || configuration.isFrontmostAppExcluded || configuration.dockDisplay == nil {
                resetStateLocked()
            }
        }
    }

    public func resetState() {
        lock.withLock {
            resetStateLocked()
        }
    }

    public func handleMouseMoved(to point: CGPoint, now: TimeInterval = CFAbsoluteTimeGetCurrent()) -> DockTriggerSnap? {
        lock.withLock {
            guard configuration.isEnabled,
                  !configuration.isFrontmostAppExcluded,
                  let dockDisplay = configuration.dockDisplay,
                  dockDisplay.bounds.contains(point) else {
                lastPointerLocation = nil
                return nil
            }

            let geometry = TriggerGeometry(activationBand: configuration.activationBand)
            if !isSnapArmed {
                let rearmDistance = geometry.rearmDistance(dockClearance: dockDisplay.dockClearance)

                guard geometry.isBeyondRearmDistance(
                    point,
                    in: dockDisplay.bounds,
                    edge: configuration.dockEdge,
                    rearmDistance: rearmDistance
                ) else {
                    lastPointerLocation = point
                    return nil
                }

                isSnapArmed = true
            }

            guard now - lastSnapTime > 0.18 else {
                lastPointerLocation = point
                return nil
            }

            guard geometry.shouldSnap(
                from: lastPointerLocation,
                to: point,
                in: dockDisplay.bounds,
                edge: configuration.dockEdge
            ) else {
                lastPointerLocation = point
                return nil
            }

            guard let snapPoint = geometry.snapPoint(
                for: point,
                in: dockDisplay.bounds,
                edge: configuration.dockEdge
            ) else {
                lastPointerLocation = point
                return nil
            }

            lastSnapTime = now
            isSnapArmed = false
            lastPointerLocation = snapPoint

            return DockTriggerSnap(
                point: snapPoint,
                shouldPlaySound: configuration.isSnapSoundEnabled
            )
        }
    }

    private func resetStateLocked() {
        lastPointerLocation = nil
        isSnapArmed = true
    }
}

private extension NSLock {
    func withLock<T>(_ operation: () -> T) -> T {
        lock()
        defer { unlock() }
        return operation()
    }
}
