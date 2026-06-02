import AppKit
import SwiftUI

struct FloatingHistogramOverlay: View {
    private static let margin: CGFloat = 8
    private static let snapThreshold: CGFloat = 34
    private static let defaultSize = CGSize(width: 230, height: 112)
    private static let minimumSize = CGSize(width: 180, height: 86)

    @EnvironmentObject private var store: AppStore
    let item: MediaItem
    let previewURL: URL
    let containerSize: CGSize

    @State private var rect = CGRect(origin: .zero, size: defaultSize)
    @State private var dragStartRect: CGRect?
    @State private var resizeStartRect: CGRect?
    @State private var didInitialize = false

    var body: some View {
        ZStack(alignment: .topLeading) {
            HistogramPanel(item: item, previewURL: previewURL, compact: true, showsTitle: false, fillsAvailableSpace: true, showsGraphChrome: true)
                .environmentObject(store)
                .frame(width: rect.width, height: rect.height)
                .contentShape(Rectangle())
                .overlay {
                    EdgeResizeZones(
                        size: rect.size,
                        onChanged: resizeChanged,
                        onEnded: resizeEnded
                    )
                }
                .position(x: rect.midX, y: rect.midY)
                .gesture(dragGesture)
        }
        .frame(width: containerSize.width, height: containerSize.height, alignment: .topLeading)
        .clipped()
        .transaction { transaction in
            if dragStartRect != nil || resizeStartRect != nil {
                transaction.animation = nil
            }
        }
        .onAppear {
            syncFromStoredLayoutIfNeeded()
        }
        .onChange(of: containerSize) { _, _ in
            syncForContainerChange()
        }
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 1)
            .onChanged { value in
                guard resizeStartRect == nil else { return }
                let start = dragStartRect ?? rect
                if dragStartRect == nil {
                    dragStartRect = rect
                }
                let proposed = start.offsetBy(dx: value.translation.width, dy: value.translation.height)
                rect = clampedRect(proposed)
            }
            .onEnded { _ in
                guard resizeStartRect == nil else { return }
                dragStartRect = nil
                let snapped = snappedRect(from: rect)
                if let anchor = snapped.anchor {
                    withAnimation(.easeOut(duration: 0.12)) {
                        rect = snapped.rect
                    }
                    persist(rect: snapped.rect, anchor: anchor)
                } else {
                    rect = snapped.rect
                    persist(rect: snapped.rect, anchor: nil)
                }
            }
    }

    private func resizeChanged(edge: HistogramResizeEdge, value: DragGesture.Value) {
        let start = resizeStartRect ?? rect
        if resizeStartRect == nil {
            resizeStartRect = rect
        }
        rect = resizedRect(from: start, edge: edge, translation: value.translation)
    }

    private func resizeEnded(edge: HistogramResizeEdge, value: DragGesture.Value) {
        let start = resizeStartRect ?? rect
        let finalRect = resizedRect(from: start, edge: edge, translation: value.translation)
        resizeStartRect = nil
        rect = finalRect
        persist(rect: finalRect, anchor: nil)
    }

    private func syncFromStoredLayoutIfNeeded() {
        guard !didInitialize else { return }
        didInitialize = true
        let size = clampedSize(CGSize(
            width: CGFloat(store.panelLayout.histogramFloatingWidth),
            height: CGFloat(store.panelLayout.histogramFloatingHeight)
        ))
        if let anchor = store.panelLayout.histogramFloatingAnchor {
            rect = rectForCorner(anchor, size: size)
        } else {
            rect = clampedRect(CGRect(
                x: CGFloat(store.panelLayout.histogramFloatingOffsetX),
                y: CGFloat(store.panelLayout.histogramFloatingOffsetY),
                width: size.width,
                height: size.height
            ))
        }
    }

    private func syncForContainerChange() {
        let size = clampedSize(rect.size)
        if let anchor = store.panelLayout.histogramFloatingAnchor {
            rect = rectForCorner(anchor, size: size)
        } else {
            rect = clampedRect(CGRect(origin: rect.origin, size: size))
        }
    }

    private func persist(rect: CGRect, anchor: HistogramCorner?) {
        store.panelLayout.histogramFloatingOffsetX = Double(rect.minX)
        store.panelLayout.histogramFloatingOffsetY = Double(rect.minY)
        store.panelLayout.histogramFloatingWidth = Double(rect.width)
        store.panelLayout.histogramFloatingHeight = Double(rect.height)
        store.panelLayout.histogramFloatingAnchor = anchor
        store.saveWorkspace()
    }

    private func clampedSize(_ proposed: CGSize) -> CGSize {
        let range = allowedSizeRange
        return CGSize(
            width: min(max(proposed.width, range.min.width), range.max.width),
            height: min(max(proposed.height, range.min.height), range.max.height)
        )
    }

    private var allowedSizeRange: (min: CGSize, max: CGSize) {
        let bounds = movementBounds
        let minWidth = min(Self.minimumSize.width, bounds.width)
        let minHeight = min(Self.minimumSize.height, bounds.height)
        let maxWidth = min(bounds.width, max(minWidth, min(420, bounds.width * 0.5)))
        let maxHeight = min(bounds.height, max(minHeight, min(260, bounds.height * 0.45)))
        return (CGSize(width: minWidth, height: minHeight), CGSize(width: maxWidth, height: maxHeight))
    }

    private func clampedRect(_ proposed: CGRect) -> CGRect {
        let size = clampedSize(proposed.size)
        let bounds = movementBounds
        let maxX = max(bounds.minX, bounds.maxX - size.width)
        let maxY = max(bounds.minY, bounds.maxY - size.height)
        return CGRect(
            x: min(max(proposed.minX, bounds.minX), maxX),
            y: min(max(proposed.minY, bounds.minY), maxY),
            width: size.width,
            height: size.height
        )
    }

    private func resizedRect(from start: CGRect, edge: HistogramResizeEdge, translation: CGSize) -> CGRect {
        let bounds = movementBounds
        let range = allowedSizeRange
        var minX = start.minX
        var maxX = start.maxX
        var minY = start.minY
        var maxY = start.maxY

        if edge.resizesLeft {
            minX += translation.width
            minX = min(max(minX, bounds.minX), maxX - range.min.width)
            if maxX - minX > range.max.width {
                minX = maxX - range.max.width
            }
        }
        if edge.resizesRight {
            maxX += translation.width
            maxX = max(min(maxX, bounds.maxX), minX + range.min.width)
            if maxX - minX > range.max.width {
                maxX = minX + range.max.width
            }
        }
        if edge.resizesTop {
            minY += translation.height
            minY = min(max(minY, bounds.minY), maxY - range.min.height)
            if maxY - minY > range.max.height {
                minY = maxY - range.max.height
            }
        }
        if edge.resizesBottom {
            maxY += translation.height
            maxY = max(min(maxY, bounds.maxY), minY + range.min.height)
            if maxY - minY > range.max.height {
                maxY = minY + range.max.height
            }
        }

        return clampedRect(CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY))
    }

    private func snappedRect(from proposed: CGRect) -> (rect: CGRect, anchor: HistogramCorner?) {
        let rect = clampedRect(proposed)
        let candidates = HistogramCorner.allCases.map { corner in
            (corner: corner, rect: rectForCorner(corner, size: rect.size))
        }
        guard let nearest = candidates.min(by: {
            distance(from: rect, to: $0.rect) < distance(from: rect, to: $1.rect)
        }) else {
            return (rect, nil)
        }

        if distance(from: rect, to: nearest.rect) <= Self.snapThreshold {
            return (nearest.rect, nearest.corner)
        }
        return (rect, nil)
    }

    private func rectForCorner(_ corner: HistogramCorner, size: CGSize) -> CGRect {
        let bounds = movementBounds
        let clampedSize = clampedSize(size)
        switch corner {
        case .topLeft:
            return CGRect(x: bounds.minX, y: bounds.minY, width: clampedSize.width, height: clampedSize.height)
        case .topRight:
            return CGRect(x: bounds.maxX - clampedSize.width, y: bounds.minY, width: clampedSize.width, height: clampedSize.height)
        case .bottomLeft:
            return CGRect(x: bounds.minX, y: bounds.maxY - clampedSize.height, width: clampedSize.width, height: clampedSize.height)
        case .bottomRight:
            return CGRect(x: bounds.maxX - clampedSize.width, y: bounds.maxY - clampedSize.height, width: clampedSize.width, height: clampedSize.height)
        }
    }

    private var movementBounds: CGRect {
        CGRect(
            x: Self.margin,
            y: Self.margin,
            width: max(1, containerSize.width - Self.margin * 2),
            height: max(1, containerSize.height - Self.margin * 2)
        )
    }

    private func distance(from lhs: CGRect, to rhs: CGRect) -> CGFloat {
        hypot(lhs.minX - rhs.minX, lhs.minY - rhs.minY)
    }
}

enum HistogramResizeEdge: CaseIterable, Identifiable {
    case top
    case bottom
    case left
    case right
    case topLeft
    case topRight
    case bottomLeft
    case bottomRight

    var id: String {
        switch self {
        case .top: "top"
        case .bottom: "bottom"
        case .left: "left"
        case .right: "right"
        case .topLeft: "topLeft"
        case .topRight: "topRight"
        case .bottomLeft: "bottomLeft"
        case .bottomRight: "bottomRight"
        }
    }

    var resizesLeft: Bool {
        self == .left || self == .topLeft || self == .bottomLeft
    }

    var resizesRight: Bool {
        self == .right || self == .topRight || self == .bottomRight
    }

    var resizesTop: Bool {
        self == .top || self == .topLeft || self == .topRight
    }

    var resizesBottom: Bool {
        self == .bottom || self == .bottomLeft || self == .bottomRight
    }

    var cursor: NSCursor {
        switch self {
        case .left, .right:
            .resizeLeftRight
        case .top, .bottom:
            .resizeUpDown
        case .topLeft, .bottomRight:
            .histogramDiagonalDownResize
        case .topRight, .bottomLeft:
            .histogramDiagonalUpResize
        }
    }
}

struct EdgeResizeZones: View {
    private static let edgeThickness: CGFloat = 8
    private static let cornerSize: CGFloat = 18

    let size: CGSize
    let onChanged: (HistogramResizeEdge, DragGesture.Value) -> Void
    let onEnded: (HistogramResizeEdge, DragGesture.Value) -> Void

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(HistogramResizeEdge.allCases) { edge in
                Rectangle()
                    .fill(.clear)
                    .frame(width: frame(for: edge).width, height: frame(for: edge).height)
                    .contentShape(Rectangle())
                    .position(position(for: edge))
                    .highPriorityGesture(
                        DragGesture(minimumDistance: 1)
                            .onChanged { value in onChanged(edge, value) }
                            .onEnded { value in onEnded(edge, value) }
                    )
            }

            HistogramResizeCursorRects(size: size)
                .frame(width: size.width, height: size.height)
        }
        .frame(width: size.width, height: size.height)
        .accessibilityHidden(true)
    }

    private func frame(for edge: HistogramResizeEdge) -> CGSize {
        let corner = Self.cornerSize
        let thickness = Self.edgeThickness
        switch edge {
        case .top, .bottom:
            return CGSize(width: max(1, size.width - corner * 2), height: thickness)
        case .left, .right:
            return CGSize(width: thickness, height: max(1, size.height - corner * 2))
        case .topLeft, .topRight, .bottomLeft, .bottomRight:
            return CGSize(width: corner, height: corner)
        }
    }

    private func position(for edge: HistogramResizeEdge) -> CGPoint {
        let corner = Self.cornerSize
        let thickness = Self.edgeThickness
        switch edge {
        case .top:
            return CGPoint(x: size.width / 2, y: thickness / 2)
        case .bottom:
            return CGPoint(x: size.width / 2, y: size.height - thickness / 2)
        case .left:
            return CGPoint(x: thickness / 2, y: size.height / 2)
        case .right:
            return CGPoint(x: size.width - thickness / 2, y: size.height / 2)
        case .topLeft:
            return CGPoint(x: corner / 2, y: corner / 2)
        case .topRight:
            return CGPoint(x: size.width - corner / 2, y: corner / 2)
        case .bottomLeft:
            return CGPoint(x: corner / 2, y: size.height - corner / 2)
        case .bottomRight:
            return CGPoint(x: size.width - corner / 2, y: size.height - corner / 2)
        }
    }
}

private struct HistogramResizeCursorRects: NSViewRepresentable {
    let size: CGSize

    func makeNSView(context: Context) -> CursorRectView {
        let view = CursorRectView()
        view.zoneSize = size
        return view
    }

    func updateNSView(_ nsView: CursorRectView, context: Context) {
        nsView.zoneSize = size
        nsView.window?.invalidateCursorRects(for: nsView)
    }

    final class CursorRectView: NSView {
        private static let edgeThickness: CGFloat = 8
        private static let cornerSize: CGFloat = 18

        var zoneSize: CGSize = .zero {
            didSet {
                needsLayout = true
                window?.invalidateCursorRects(for: self)
            }
        }

        override var isFlipped: Bool { true }

        override func hitTest(_ point: NSPoint) -> NSView? {
            nil
        }

        override func resetCursorRects() {
            super.resetCursorRects()
            for edge in HistogramResizeEdge.allCases {
                addCursorRect(frame(for: edge), cursor: edge.cursor)
            }
        }

        private func frame(for edge: HistogramResizeEdge) -> CGRect {
            let corner = Self.cornerSize
            let thickness = Self.edgeThickness
            switch edge {
            case .top:
                return CGRect(x: corner, y: 0, width: max(1, zoneSize.width - corner * 2), height: thickness)
            case .bottom:
                return CGRect(x: corner, y: max(0, zoneSize.height - thickness), width: max(1, zoneSize.width - corner * 2), height: thickness)
            case .left:
                return CGRect(x: 0, y: corner, width: thickness, height: max(1, zoneSize.height - corner * 2))
            case .right:
                return CGRect(x: max(0, zoneSize.width - thickness), y: corner, width: thickness, height: max(1, zoneSize.height - corner * 2))
            case .topLeft:
                return CGRect(x: 0, y: 0, width: corner, height: corner)
            case .topRight:
                return CGRect(x: max(0, zoneSize.width - corner), y: 0, width: corner, height: corner)
            case .bottomLeft:
                return CGRect(x: 0, y: max(0, zoneSize.height - corner), width: corner, height: corner)
            case .bottomRight:
                return CGRect(x: max(0, zoneSize.width - corner), y: max(0, zoneSize.height - corner), width: corner, height: corner)
            }
        }
    }
}

private extension NSCursor {
    static let histogramDiagonalDownResize = diagonalResizeCursor(isRising: false)
    static let histogramDiagonalUpResize = diagonalResizeCursor(isRising: true)

    static func diagonalResizeCursor(isRising: Bool) -> NSCursor {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size)
        image.lockFocus()
        defer { image.unlockFocus() }

        NSColor.clear.setFill()
        NSRect(origin: .zero, size: size).fill()

        let start = isRising ? NSPoint(x: 4, y: 4) : NSPoint(x: 4, y: 14)
        let end = isRising ? NSPoint(x: 14, y: 14) : NSPoint(x: 14, y: 4)
        drawDiagonalCursorStroke(from: start, to: end, color: .white, lineWidth: 4.2)
        drawDiagonalCursorStroke(from: start, to: end, color: .black, lineWidth: 2.0)

        return NSCursor(image: image, hotSpot: NSPoint(x: size.width / 2, y: size.height / 2))
    }

    static func drawDiagonalCursorStroke(from start: NSPoint, to end: NSPoint, color: NSColor, lineWidth: CGFloat) {
        color.setStroke()
        let path = NSBezierPath()
        path.lineCapStyle = .round
        path.lineJoinStyle = .round
        path.lineWidth = lineWidth
        path.move(to: start)
        path.line(to: end)
        path.stroke()

        drawArrowhead(at: start, toward: end, color: color, lineWidth: lineWidth)
        drawArrowhead(at: end, toward: start, color: color, lineWidth: lineWidth)
    }

    static func drawArrowhead(at point: NSPoint, toward other: NSPoint, color: NSColor, lineWidth: CGFloat) {
        let dx = other.x - point.x
        let dy = other.y - point.y
        let length = max(1, hypot(dx, dy))
        let unit = CGPoint(x: dx / length, y: dy / length)
        let normal = CGPoint(x: -unit.y, y: unit.x)
        let arrowLength: CGFloat = 4.6
        let arrowWidth: CGFloat = 3.4

        let base = CGPoint(
            x: point.x + unit.x * arrowLength,
            y: point.y + unit.y * arrowLength
        )
        let first = NSPoint(
            x: base.x + normal.x * arrowWidth,
            y: base.y + normal.y * arrowWidth
        )
        let second = NSPoint(
            x: base.x - normal.x * arrowWidth,
            y: base.y - normal.y * arrowWidth
        )

        color.setStroke()
        let path = NSBezierPath()
        path.lineCapStyle = .round
        path.lineJoinStyle = .round
        path.lineWidth = lineWidth
        path.move(to: first)
        path.line(to: point)
        path.line(to: second)
        path.stroke()
    }
}
