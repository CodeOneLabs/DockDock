import SwiftUI

struct TriggerBandSlider: View {
    @Binding var value: Double
    var width: CGFloat?
    var showsLabels = true
    var onEditingChanged: (Bool) -> Void

    private let bounds = 1.0...50.0
    private let recommended = 15.0
    private let recommendedRange = 5.0...25.0

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            GeometryReader { proxy in
                let trackWidth = max(proxy.size.width, 1)
                let handleX = ratio(for: value) * trackWidth
                let recommendedStart = ratio(for: recommendedRange.lowerBound) * trackWidth
                let recommendedEnd = ratio(for: recommendedRange.upperBound) * trackWidth
                let recommendedX = ratio(for: recommended) * trackWidth

                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.secondary.opacity(0.15))
                        .frame(height: 8)

                    Capsule()
                        .fill(.blue.opacity(0.34))
                        .frame(width: max(recommendedEnd - recommendedStart, 2), height: 8)
                        .offset(x: recommendedStart)

                    Rectangle()
                        .fill(.blue.opacity(0.85))
                        .frame(width: 2, height: 18)
                        .clipShape(Capsule())
                        .offset(x: recommendedX - 1)

                    Circle()
                        .fill(.white)
                        .frame(width: 20, height: 20)
                        .shadow(color: .black.opacity(0.22), radius: 3, y: 1)
                        .overlay(Circle().stroke(.blue.opacity(0.65), lineWidth: 1))
                        .offset(x: min(max(handleX - 10, 0), max(trackWidth - 20, 0)))
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { gesture in
                            onEditingChanged(true)
                            value = valueFrom(x: gesture.location.x, trackWidth: trackWidth)
                        }
                        .onEnded { _ in
                            onEditingChanged(false)
                        }
                )
            }
            .frame(width: width, height: 24)
            .accessibilityElement()
            .accessibilityLabel("Trigger band")
            .accessibilityValue("\(Int(value)) pixels")
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment:
                    value = min(value + 1, bounds.upperBound)
                case .decrement:
                    value = max(value - 1, bounds.lowerBound)
                @unknown default:
                    break
                }
            }

            if showsLabels {
                HStack(spacing: 8) {
                    Text("1")
                    Text("Recommended: 5-25 px, best 15")
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                    Button("Use 15") {
                        value = recommended
                    }
                    .buttonStyle(.borderless)
                    Text("50")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: width, alignment: .leading)
            }
        }
    }

    private func ratio(for candidate: Double) -> CGFloat {
        let clamped = min(max(candidate, bounds.lowerBound), bounds.upperBound)
        return CGFloat((clamped - bounds.lowerBound) / (bounds.upperBound - bounds.lowerBound))
    }

    private func valueFrom(x: CGFloat, trackWidth: CGFloat) -> Double {
        let ratio = min(max(Double(x / max(trackWidth, 1)), 0), 1)
        let rawValue = bounds.lowerBound + ratio * (bounds.upperBound - bounds.lowerBound)
        return rawValue.rounded()
    }
}
