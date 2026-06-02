import SwiftUI

struct FloatingWaveformOverlay: View {
    private static let margin: CGFloat = 8
    private static let snapThreshold: CGFloat = 34
    private static let defaultSize = CGSize(width: 260, height: 128)
    private static let minimumSize = CGSize(width: 200, height: 96)

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
            WaveformPanel(item: item, previewURL: previewURL, compact: true, showsTitle: false, fillsAvailableSpace: true, showsGraphChrome: true)
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
            width: CGFloat(store.panelLayout.waveformFloatingWidth),
            height: CGFloat(store.panelLayout.waveformFloatingHeight)
        ))
        if let anchor = store.panelLayout.waveformFloatingAnchor {
            rect = rectForCorner(anchor, size: size)
        } else {
            rect = clampedRect(CGRect(
                x: CGFloat(store.panelLayout.waveformFloatingOffsetX),
                y: CGFloat(store.panelLayout.waveformFloatingOffsetY),
                width: size.width,
                height: size.height
            ))
        }
    }

    private func syncForContainerChange() {
        let size = clampedSize(rect.size)
        if let anchor = store.panelLayout.waveformFloatingAnchor {
            rect = rectForCorner(anchor, size: size)
        } else {
            rect = clampedRect(CGRect(origin: rect.origin, size: size))
        }
    }

    private func persist(rect: CGRect, anchor: HistogramCorner?) {
        store.panelLayout.waveformFloatingOffsetX = Double(rect.minX)
        store.panelLayout.waveformFloatingOffsetY = Double(rect.minY)
        store.panelLayout.waveformFloatingWidth = Double(rect.width)
        store.panelLayout.waveformFloatingHeight = Double(rect.height)
        store.panelLayout.waveformFloatingAnchor = anchor
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
        let maxWidth = min(bounds.width, max(minWidth, min(500, bounds.width * 0.55)))
        let maxHeight = min(bounds.height, max(minHeight, min(300, bounds.height * 0.5)))
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
