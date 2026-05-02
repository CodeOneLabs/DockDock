import Foundation

public enum DockEdge: String, CaseIterable, Identifiable {
    case bottom
    case left
    case right

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .bottom:
            "Bottom"
        case .left:
            "Left"
        case .right:
            "Right"
        }
    }
}
