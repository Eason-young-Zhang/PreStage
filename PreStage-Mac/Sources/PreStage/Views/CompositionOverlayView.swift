import SwiftUI

struct CompositionOverlayView: View {
    @Environment(\.displayScale) private var displayScale

    let imageRect: CGRect
    let overlays: Set<CompositionOverlay>
    let color: CompositionOverlayColor
    let opacity: Double
    let constrainedAspectRatio: CGFloat?

    var body: some View {
        GeometryReader { proxy in
            let guideRect = constrainedAspectRatio.map { PreviewOverlayGeometry.cropRect(in: imageRect, aspectRatio: $0, scale: displayScale) } ?? imageRect
            Canvas { context, _ in
                guard guideRect.width > 1, guideRect.height > 1, !overlays.isEmpty else { return }
                let stroke = GraphicsContext.Shading.color(lineColor.opacity(min(opacity, 0.48)))

                for overlay in CompositionOverlay.allCases where overlays.contains(overlay) {
                    for path in paths(for: overlay, in: guideRect) {
                        context.stroke(path, with: stroke, lineWidth: 0.9)
                    }
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var lineColor: Color {
        switch color {
        case .gray: Color(nsColor: .tertiaryLabelColor)
        case .white: .white
        case .black: .black
        case .accent: .blue
        }
    }

    private func paths(for overlay: CompositionOverlay, in rect: CGRect) -> [Path] {
        switch overlay {
        case .thirds:
            return verticalLines(at: [1.0 / 3.0, 2.0 / 3.0], in: rect) + horizontalLines(at: [1.0 / 3.0, 2.0 / 3.0], in: rect)
        case .center:
            return verticalLines(at: [0.5], in: rect) + horizontalLines(at: [0.5], in: rect)
        case .diagonals:
            return [
                line(from: CGPoint(x: rect.minX, y: rect.minY), to: CGPoint(x: rect.maxX, y: rect.maxY)),
                line(from: CGPoint(x: rect.maxX, y: rect.minY), to: CGPoint(x: rect.minX, y: rect.maxY))
            ]
        case .goldenRatio:
            let low = 1.0 - 0.61803398875
            let high = 0.61803398875
            return verticalLines(at: [low, high], in: rect) + horizontalLines(at: [low, high], in: rect)
        }
    }

    private func verticalLines(at fractions: [Double], in rect: CGRect) -> [Path] {
        fractions.map { fraction in
            let x = rect.minX + rect.width * CGFloat(fraction)
            return line(from: CGPoint(x: x, y: rect.minY), to: CGPoint(x: x, y: rect.maxY))
        }
    }

    private func horizontalLines(at fractions: [Double], in rect: CGRect) -> [Path] {
        fractions.map { fraction in
            let y = rect.minY + rect.height * CGFloat(fraction)
            return line(from: CGPoint(x: rect.minX, y: y), to: CGPoint(x: rect.maxX, y: y))
        }
    }

    private func line(from start: CGPoint, to end: CGPoint) -> Path {
        var path = Path()
        path.move(to: start)
        path.addLine(to: end)
        return path
    }
}

struct CropGuideOverlayView: View {
    @Environment(\.displayScale) private var displayScale

    let imageRect: CGRect
    let aspectRatio: CGFloat
    let style: CropGuideStyle

    var body: some View {
        GeometryReader { proxy in
            let cropRect = PreviewOverlayGeometry.cropRect(in: imageRect, aspectRatio: aspectRatio, scale: displayScale)
            Canvas { context, _ in
                guard imageRect.width > 1, imageRect.height > 1, cropRect.width > 1, cropRect.height > 1 else { return }

                if style == .mask {
                    for rect in PreviewRenderGeometry.maskRects(imageRect: imageRect, cropRect: cropRect, scale: displayScale) {
                        context.fill(Path(rect), with: .color(.black.opacity(0.46)))
                    }
                }

                if style == .frame {
                    let frame = Path(roundedRect: cropRect, cornerRadius: 1)
                    context.stroke(frame, with: .color(.white.opacity(0.62)), lineWidth: 1.8)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

}

enum PreviewOverlayGeometry {
    static func previewImageRect(for item: MediaItem, in size: CGSize) -> CGRect {
        guard let imageAspect = item.displayAspectRatio else {
            return CGRect(origin: .zero, size: size)
        }
        return previewImageRect(aspectRatio: imageAspect, in: size, scale: 1)
    }

    static func previewImageRect(for item: MediaItem, previewURL: URL, in size: CGSize) -> CGRect {
        let aspectRatio = PreviewSourceGeometry.aspectRatio(for: item, previewURL: previewURL)
        return previewImageRect(aspectRatio: aspectRatio, in: size, scale: 1)
    }

    static func previewImageRect(for item: MediaItem, previewURL: URL, in size: CGSize, scale: CGFloat) -> CGRect {
        let aspectRatio = PreviewSourceGeometry.aspectRatio(for: item, previewURL: previewURL)
        return previewImageRect(aspectRatio: aspectRatio, in: size, scale: scale)
    }

    static func previewImageRect(aspectRatio imageAspect: CGFloat, in size: CGSize, scale: CGFloat = 1) -> CGRect {
        PreviewRenderGeometry.imageRect(aspectRatio: imageAspect, in: size, scale: scale)
    }

    static func cropRect(in imageRect: CGRect, aspectRatio: CGFloat) -> CGRect {
        cropRect(in: imageRect, aspectRatio: aspectRatio, scale: 1)
    }

    static func cropRect(in imageRect: CGRect, aspectRatio: CGFloat, scale: CGFloat) -> CGRect {
        PreviewRenderGeometry.cropRect(in: imageRect, aspectRatio: aspectRatio, scale: scale)
    }
}
