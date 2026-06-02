import AppKit
import SwiftUI

struct GalleryBrowserView: View {
    private static let minimumFilmstripHeight: CGFloat = 60
    private static let maximumFilmstripHeight: CGFloat = 220

    @EnvironmentObject private var store: AppStore
    @State private var inspectorDraftWidth: CGFloat?
    @State private var filmstripDraftHeight: CGFloat?

    var body: some View {
        GeometryReader { proxy in
            let filmstripHeight = currentFilmstripHeight
            let inspectorWidth = currentInspectorWidth(containerWidth: proxy.size.width)
            let bottomHeight = currentBottomHeight(containerHeight: proxy.size.height, filmstripHeight: filmstripHeight)
            let mainHeight = max(1, proxy.size.height - bottomHeight)
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                GalleryPreviewPane {
                    GalleryPreviewView(item: store.focusedItem)
                }
                .frame(width: max(360, proxy.size.width - inspectorWidth - 8))

                    SplitterHandle(axis: .vertical)
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    inspectorDraftWidth = clampedInspectorWidth(inspectorWidth - value.translation.width, containerWidth: proxy.size.width)
                                }
                                .onEnded { _ in
                                    store.panelLayout.previewWidth = Double(currentInspectorWidth(containerWidth: proxy.size.width))
                                    inspectorDraftWidth = nil
                                    store.saveWorkspace()
                                }
                        )

                InspectorView(item: store.focusedItem)
                    .frame(width: inspectorWidth)
            }
                .frame(height: mainHeight)
                .clipped()

            if !store.panelLayout.isFilmstripCollapsed {
                VStack(spacing: 0) {
                    GalleryFilmstripToolbar()
                        SplitterHandle(axis: .horizontal)
                            .gesture(
                                DragGesture(minimumDistance: 0)
                                    .onChanged { value in
                                        filmstripDraftHeight = clampedFilmstripHeight(filmstripHeight - value.translation.height)
                                    }
                                    .onEnded { _ in
                                        store.panelLayout.galleryStripHeight = Double(currentFilmstripHeight)
                                        filmstripDraftHeight = nil
                                        store.saveWorkspace()
                                    }
                            )
                    NativeFilmstripView(
                        items: store.browserItems,
                        focusedItemID: store.focusedBrowserItemID,
                        transforms: store.mediaTransforms,
                        isWindowLiveResizing: store.isWindowLiveResizing,
                        thumbnailService: store.thumbnails,
                        titleProvider: { item in
                            store.displayName(for: item, hidingProxyExtension: true)
                        },
                        onSelect: { id in
                            store.selectItem(id: id)
                        },
                        onMove: { offset in
                            store.moveSelection(by: offset)
                        },
                        onSetRating: { rating in
                            store.setRating(rating)
                        },
                        onSetPickState: { state in
                            store.setPickState(state)
                        }
                    )
                }
                    .frame(height: bottomHeight)
                    .clipped()
            } else {
                GalleryFilmstripToolbar()
                    .frame(height: bottomHeight)
            }
        }
        .clipped()
        }
    }

    private var currentFilmstripHeight: CGFloat {
        clampedFilmstripHeight(filmstripDraftHeight ?? CGFloat(store.panelLayout.galleryStripHeight))
    }

    private func currentInspectorWidth(containerWidth: CGFloat) -> CGFloat {
        clampedInspectorWidth(inspectorDraftWidth ?? CGFloat(store.panelLayout.previewWidth), containerWidth: containerWidth)
    }

    private func clampedInspectorWidth(_ width: CGFloat, containerWidth: CGFloat) -> CGFloat {
        min(max(width, 220), max(220, min(460, containerWidth - 420)))
    }

    private func clampedFilmstripHeight(_ height: CGFloat) -> CGFloat {
        min(max(height, Self.minimumFilmstripHeight), Self.maximumFilmstripHeight)
    }

    private func currentBottomHeight(containerHeight: CGFloat, filmstripHeight: CGFloat) -> CGFloat {
        if store.panelLayout.isFilmstripCollapsed {
            return min(24, max(0, containerHeight))
        }
        return min(filmstripHeight, max(Self.minimumFilmstripHeight, containerHeight - 120))
    }
}

private extension PreviewBackgroundTone {
    var color: Color {
        Color(nsColor: nsColor)
    }

    var nsColor: NSColor {
        switch self {
        case .system:
            return .textBackgroundColor
        case .black:
            return .black
        case .white:
            return .white
        case .darkGray:
            return NSColor(calibratedWhite: 0.12, alpha: 1)
        case .middleGray:
            return NSColor(calibratedWhite: 0.45, alpha: 1)
        case .lightGray:
            return NSColor(calibratedWhite: 0.78, alpha: 1)
        }
    }
}

private enum SplitterAxis {
    case vertical
    case horizontal
}

private struct SplitterHandle: View {
    let axis: SplitterAxis

    var body: some View {
        Rectangle()
            .fill(Color(nsColor: .separatorColor))
            .frame(width: axis == .vertical ? 8 : nil, height: axis == .horizontal ? 8 : nil)
            .overlay {
                Capsule()
                    .fill(.secondary.opacity(0.35))
                    .frame(width: axis == .vertical ? 3 : 44, height: axis == .vertical ? 44 : 3)
            }
            .contentShape(Rectangle())
            .help(L10n.tr("Drag to resize"))
    }
}

private struct GalleryFilmstripToolbar: View {
    @EnvironmentObject private var store: AppStore
    @State private var isShowingCustomCropRatioEditor = false

    var body: some View {
        HStack(spacing: 10) {
            Button {
                store.panelLayout.isFilmstripCollapsed.toggle()
                store.saveWorkspace()
            } label: {
                Label(store.panelLayout.isFilmstripCollapsed ? L10n.tr("Show Filmstrip") : L10n.tr("Hide Filmstrip"), systemImage: store.panelLayout.isFilmstripCollapsed ? "chevron.up" : "chevron.down")
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.borderless)

            Spacer()

            HStack(spacing: 6) {
                Menu {
                    ForEach(HistogramPlacement.allCases) { placement in
                        Button(placement.displayName) {
                            store.panelLayout.histogramPlacement = placement
                            store.saveWorkspace()
                        }
                    }
                } label: {
                    ToolbarIconLabel(title: L10n.tr("Histogram"), systemImage: "chart.bar.xaxis")
                }
                .help(L10n.tr("Histogram"))

                Menu {
                    Section(L10n.tr("Placement")) {
                        ForEach(HistogramPlacement.allCases) { placement in
                            Button(placement.displayName) {
                                store.panelLayout.waveformPlacement = placement
                                store.saveWorkspace()
                            }
                        }
                    }
                    Section(L10n.tr("Direction")) {
                        ForEach(WaveformDirection.allCases) { direction in
                            Button(direction.displayName) {
                                store.panelLayout.waveformDirection = direction
                                store.saveWorkspace()
                            }
                        }
                    }
                    Section(L10n.tr("Channel")) {
                        ForEach(WaveformChannelMode.allCases) { mode in
                            Button(mode.displayName) {
                                store.panelLayout.waveformChannelMode = mode
                                store.saveWorkspace()
                            }
                        }
                    }
                } label: {
                    ToolbarIconLabel(title: L10n.tr("Waveform"), systemImage: "waveform.path.ecg.rectangle")
                }
                .help(L10n.tr("Waveform"))
            }

            HStack(spacing: 6) {
                Menu {
                    Section(L10n.tr("Guides")) {
                        Button {
                            store.panelLayout.compositionGuidesFollowCrop.toggle()
                            store.saveWorkspace()
                        } label: {
                            if store.panelLayout.compositionGuidesFollowCrop {
                                Label(L10n.tr("Follow Crop Reference"), systemImage: "checkmark")
                            } else {
                                Text(L10n.tr("Follow Crop Reference"))
                            }
                        }

                        Button(L10n.tr("Clear Guides")) {
                            store.panelLayout.compositionOverlays.removeAll()
                            store.saveWorkspace()
                        }
                        .disabled(store.panelLayout.compositionOverlays.isEmpty)

                        ForEach(CompositionOverlay.allCases) { overlay in
                            Button {
                                if store.panelLayout.compositionOverlays.contains(overlay) {
                                    store.panelLayout.compositionOverlays.remove(overlay)
                                } else {
                                    store.panelLayout.compositionOverlays.insert(overlay)
                                }
                                store.saveWorkspace()
                            } label: {
                                if store.panelLayout.compositionOverlays.contains(overlay) {
                                    Label(overlay.displayName, systemImage: "checkmark")
                                } else {
                                    Text(overlay.displayName)
                                }
                            }
                        }
                    }

                    Section(L10n.tr("Color")) {
                        ForEach(CompositionOverlayColor.visibleCases) { color in
                            Button {
                                store.panelLayout.compositionOverlayColor = color
                                store.saveWorkspace()
                            } label: {
                                if color == store.panelLayout.compositionOverlayColor {
                                    Label(color.displayName, systemImage: "checkmark")
                                } else {
                                    Text(color.displayName)
                                }
                            }
                        }
                    }
                } label: {
                    ToolbarIconLabel(title: L10n.tr("Guides"), systemImage: "grid")
                }
                .help(L10n.tr("Guides"))

                Menu {
                    Section(L10n.tr("Aspect Ratio")) {
                        ForEach(CropGuideRatio.allCases) { ratio in
                            Button {
                                store.panelLayout.cropGuideRatio = ratio
                                store.panelLayout.activeCustomCropGuideRatioID = nil
                                store.saveWorkspace()
                            } label: {
                                if ratio == store.panelLayout.cropGuideRatio && store.panelLayout.activeCustomCropGuideRatioID == nil {
                                    Label(ratio.displayName, systemImage: "checkmark")
                                } else {
                                    Text(ratio.displayName)
                                }
                            }
                        }
                    }

                    Section(L10n.tr("Custom Ratios")) {
                        Button(L10n.tr("Edit Custom Ratios...")) {
                            isShowingCustomCropRatioEditor = true
                        }

                        ForEach(store.panelLayout.customCropGuideRatios) { ratio in
                            Button {
                                store.panelLayout.activeCustomCropGuideRatioID = ratio.id
                                store.panelLayout.cropGuideRatio = .hidden
                                store.saveWorkspace()
                            } label: {
                                if store.panelLayout.activeCustomCropGuideRatioID == ratio.id {
                                    Label(ratio.displayName, systemImage: "checkmark")
                                } else {
                                    Text(ratio.displayName)
                                }
                            }
                        }
                    }

                    Section(L10n.tr("Orientation")) {
                        ForEach(CropGuideOrientation.allCases) { orientation in
                            Button {
                                store.panelLayout.cropGuideOrientation = orientation
                                store.saveWorkspace()
                            } label: {
                                if orientation == store.panelLayout.cropGuideOrientation {
                                    Label(orientation.displayName, systemImage: "checkmark")
                                } else {
                                    Text(orientation.displayName)
                                }
                            }
                        }
                    }

                    Section(L10n.tr("Style")) {
                        ForEach(CropGuideStyle.allCases) { style in
                            Button {
                                store.panelLayout.cropGuideStyle = style
                                store.saveWorkspace()
                            } label: {
                                if style == store.panelLayout.cropGuideStyle {
                                    Label(style.displayName, systemImage: "checkmark")
                                } else {
                                    Text(style.displayName)
                                }
                            }
                        }
                    }
                } label: {
                    ToolbarIconLabel(title: L10n.tr("Crop Reference"), systemImage: "crop")
                }
                .help(L10n.tr("Crop Reference"))
            }

            HStack(spacing: 6) {
                Button { store.rotateFocusedItem(clockwise: false) } label: {
                    ToolbarIconLabel(title: L10n.tr("Rotate Left"), systemImage: "rotate.left")
                }
                .help(L10n.tr("Rotate Left"))
                Button { store.rotateFocusedItem(clockwise: true) } label: {
                    ToolbarIconLabel(title: L10n.tr("Rotate Right"), systemImage: "rotate.right")
                }
                .help(L10n.tr("Rotate Right"))
                Button { store.flipFocusedItem(horizontal: true) } label: {
                    ToolbarIconLabel(title: L10n.tr("Flip Horizontal"), systemImage: "arrow.left.and.right.righttriangle.left.righttriangle.right")
                }
                .help(L10n.tr("Flip Horizontal"))
            }
        }
            .buttonStyle(.borderless)
            .padding(.horizontal, 10)
            .frame(height: 28)
            .background(Color(nsColor: .windowBackgroundColor))
            .overlay(alignment: .top) { Divider() }
            .sheet(isPresented: $isShowingCustomCropRatioEditor) {
                CustomCropRatiosEditorSheet()
                    .environmentObject(store)
            }
    }
}

private struct ToolbarIconLabel: View {
    let title: String
    let systemImage: String

    var body: some View {
        Label(title, systemImage: systemImage)
            .labelStyle(.iconOnly)
            .font(.system(size: 14, weight: .medium))
            .frame(width: 24, height: 22)
            .contentShape(Rectangle())
    }
}

private struct CustomCropRatiosEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: AppStore
    @State private var name = ""
    @State private var width = 4.0
    @State private var height = 5.0

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(L10n.tr("Edit Custom Ratios"))
                .font(.headline)

            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    if store.panelLayout.customCropGuideRatios.isEmpty {
                        Text(L10n.tr("No custom ratios saved."))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        ForEach(store.panelLayout.customCropGuideRatios) { ratio in
                            HStack(spacing: 10) {
                                Button {
                                    select(ratio)
                                } label: {
                                    if store.panelLayout.activeCustomCropGuideRatioID == ratio.id {
                                        Image(systemName: "checkmark.circle.fill")
                                    } else {
                                        Image(systemName: "circle")
                                    }
                                }
                                .buttonStyle(.plain)

                                Text(ratio.displayName)
                                    .lineLimit(1)
                                    .truncationMode(.middle)

                                Spacer()

                                Button(role: .destructive) {
                                    delete(ratio)
                                } label: {
                                    Image(systemName: "trash")
                                }
                                .buttonStyle(.borderless)
                                .help(L10n.tr("Delete"))
                            }
                        }
                    }
                }
            }
            .frame(minHeight: 52, maxHeight: 150, alignment: .top)

            Divider()

            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 10) {
                GridRow {
                    Text(L10n.tr("Name"))
                    TextField(L10n.tr("Name"), text: $name)
                        .frame(width: 180)
                }
                GridRow {
                    Text(L10n.tr("Width"))
                    TextField(L10n.tr("Width"), value: $width, format: .number.precision(.fractionLength(0...2)))
                        .frame(width: 100)
                }
                GridRow {
                    Text(L10n.tr("Height"))
                    TextField(L10n.tr("Height"), value: $height, format: .number.precision(.fractionLength(0...2)))
                        .frame(width: 100)
                }
            }

            Text(String(format: L10n.tr("Custom ratio limit: %d"), CustomCropGuideRatio.maximumSavedCount))
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                Spacer()
                Button(L10n.tr("Done")) {
                    dismiss()
                }
                Button(L10n.tr("Add")) {
                    add()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!canAdd)
            }
        }
        .padding(18)
        .frame(width: 360)
    }

    private var canAdd: Bool {
        width > 0 && height > 0 && store.panelLayout.customCropGuideRatios.count < CustomCropGuideRatio.maximumSavedCount
    }

    private func add() {
        let ratio = CustomCropGuideRatio(name: name, width: width, height: height)
        store.panelLayout.customCropGuideRatios.append(ratio)
        select(ratio)
        name = ""
        store.saveWorkspace()
    }

    private func select(_ ratio: CustomCropGuideRatio) {
        store.panelLayout.activeCustomCropGuideRatioID = ratio.id
        store.panelLayout.cropGuideRatio = .hidden
        store.saveWorkspace()
    }

    private func delete(_ ratio: CustomCropGuideRatio) {
        store.panelLayout.customCropGuideRatios.removeAll { $0.id == ratio.id }
        if store.panelLayout.activeCustomCropGuideRatioID == ratio.id {
            store.panelLayout.activeCustomCropGuideRatioID = nil
            store.panelLayout.cropGuideRatio = .hidden
        }
        store.saveWorkspace()
    }
}

private struct GalleryPreviewPane<Content: View>: View {
    @EnvironmentObject private var store: AppStore
    @ViewBuilder var content: Content

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(store.panelLayout.previewBackground.color)
    }
}

private struct GalleryPreviewView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.displayScale) private var displayScale
    @State private var panOffset: CGSize = .zero
    @State private var dragStartOffset: CGSize?
    @State private var magnificationStartZoom: Double?
    let item: MediaItem?

    var body: some View {
        ZStack {
            store.panelLayout.previewBackground.color
            if let item {
                let previewURL = store.galleryPreviewURL(for: item)
                let preload = preloadPreview(for: item)
                let cropAspectRatio = store.panelLayout.activeCropGuideAspectRatio(for: item)
                GeometryReader { proxy in
                    let mattePadding = store.panelLayout.reviewMatteSize.padding
                    let contentSize = CGSize(
                        width: max(1, proxy.size.width - mattePadding * 2),
                        height: max(1, proxy.size.height - mattePadding * 2)
                    )
                    let contentOrigin = CGPoint(x: mattePadding, y: mattePadding)
                    let localImageRect = PreviewOverlayGeometry.previewImageRect(for: item, previewURL: previewURL, in: contentSize, scale: displayScale)
                    let zoom = CGFloat(store.panelLayout.galleryPreviewZoom)
                    let clampedPan = clampedPanOffset(panOffset, imageSize: localImageRect.size, contentSize: contentSize, zoom: zoom)
                    let zoomedImageRect = zoomedRect(localImageRect, zoom: zoom, pan: clampedPan)
                    let imageRect = zoomedImageRect.offsetBy(dx: contentOrigin.x, dy: contentOrigin.y)

                    ZStack {
                        previewView(item: item, previewURL: previewURL, preload: preload)
                        .frame(width: imageRect.width, height: imageRect.height)
                        .position(x: imageRect.midX, y: imageRect.midY)
                        .clipped()
                        .contextMenu { FinderStyleContextMenu(item: item) }

                        if !store.panelLayout.compositionOverlays.isEmpty {
                            CompositionOverlayView(
                                imageRect: imageRect,
                                overlays: store.panelLayout.compositionOverlays,
                                color: store.panelLayout.compositionOverlayColor,
                                opacity: store.panelLayout.compositionOverlayOpacity,
                                constrainedAspectRatio: store.panelLayout.compositionGuidesFollowCrop ? cropAspectRatio : nil
                            )
                        }

                        if let cropAspectRatio {
                            CropGuideOverlayView(
                                imageRect: imageRect,
                                aspectRatio: cropAspectRatio,
                                style: store.panelLayout.cropGuideStyle
                            )
                        }

                        if store.panelLayout.histogramPlacement == .floating {
                            FloatingHistogramOverlay(item: item, previewURL: previewURL, containerSize: proxy.size)
                                .environmentObject(store)
                        }

                        if store.panelLayout.waveformPlacement == .floating {
                            FloatingWaveformOverlay(item: item, previewURL: previewURL, containerSize: proxy.size)
                                .environmentObject(store)
                        }
                    }
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .contentShape(Rectangle())
                    .gesture(panGesture(imageSize: localImageRect.size, contentSize: contentSize, zoom: zoom))
                    .simultaneousGesture(magnificationGesture(imageSize: localImageRect.size, contentSize: contentSize))
                    .onChange(of: store.panelLayout.galleryPreviewZoom) {
                        panOffset = clampedPanOffset(panOffset, imageSize: localImageRect.size, contentSize: contentSize, zoom: zoom)
                    }
                    .onChange(of: item.id) {
                        panOffset = .zero
                        dragStartOffset = nil
                        magnificationStartZoom = nil
                    }
                }
            } else {
                EmptyStateView(title: L10n.tr("No Selection"), systemImage: "photo", message: L10n.tr("Select a file to preview it."))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
    }

    private func preloadPreview(for item: MediaItem) -> (url: URL, key: String)? {
        let items = store.browserItems
        guard let currentIndex = items.firstIndex(where: { $0.id == item.id }) else { return nil }
        let candidateIndex: Int?
        if currentIndex + 1 < items.count {
            candidateIndex = currentIndex + 1
        } else if currentIndex > 0 {
            candidateIndex = currentIndex - 1
        } else {
            candidateIndex = nil
        }
        guard let candidateIndex else { return nil }
        let candidate = items[candidateIndex]
        let url = store.galleryPreviewURL(for: candidate)
        return (url, "\(candidate.thumbnailCacheKey)|\(url.path)")
    }

    @ViewBuilder
    private func previewView(item: MediaItem, previewURL: URL, preload: (url: URL, key: String)?) -> some View {
        if PreviewSourceGeometry.supportsDirectRasterPreview(url: previewURL) {
            RasterMediaPreviewView(previewURL: previewURL, backgroundColor: store.panelLayout.previewBackground.nsColor)
        } else {
            NativeMediaPreviewView(
                item: item,
                previewURL: previewURL,
                preloadURL: preload?.url,
                preloadKey: preload?.key,
                backgroundColor: store.panelLayout.previewBackground.nsColor
            )
        }
    }

    private func zoomedRect(_ rect: CGRect, zoom: CGFloat, pan: CGSize) -> CGRect {
        guard zoom > 1 else { return rect }
        let size = CGSize(width: rect.width * zoom, height: rect.height * zoom)
        return CGRect(
            x: rect.midX - size.width / 2 + pan.width,
            y: rect.midY - size.height / 2 + pan.height,
            width: size.width,
            height: size.height
        )
    }

    private func panGesture(imageSize: CGSize, contentSize: CGSize, zoom: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 2)
            .onChanged { value in
                guard zoom > 1 else { return }
                let start = dragStartOffset ?? panOffset
                if dragStartOffset == nil {
                    dragStartOffset = start
                }
                let proposed = CGSize(width: start.width + value.translation.width, height: start.height + value.translation.height)
                panOffset = clampedPanOffset(proposed, imageSize: imageSize, contentSize: contentSize, zoom: zoom)
            }
            .onEnded { _ in
                panOffset = clampedPanOffset(panOffset, imageSize: imageSize, contentSize: contentSize, zoom: zoom)
                dragStartOffset = nil
            }
    }

    private func magnificationGesture(imageSize: CGSize, contentSize: CGSize) -> some Gesture {
        MagnificationGesture()
            .onChanged { value in
                let startZoom = magnificationStartZoom ?? store.panelLayout.galleryPreviewZoom
                if magnificationStartZoom == nil {
                    magnificationStartZoom = startZoom
                }
                store.setGalleryPreviewZoom(startZoom * Double(value))
            }
            .onEnded { _ in
                magnificationStartZoom = nil
                let zoom = CGFloat(store.panelLayout.galleryPreviewZoom)
                panOffset = clampedPanOffset(panOffset, imageSize: imageSize, contentSize: contentSize, zoom: zoom)
            }
    }

    private func clampedPanOffset(_ offset: CGSize, imageSize: CGSize, contentSize: CGSize, zoom: CGFloat) -> CGSize {
        guard zoom > 1 else { return .zero }
        let zoomedWidth = imageSize.width * zoom
        let zoomedHeight = imageSize.height * zoom
        let maxX = max(0, (zoomedWidth - contentSize.width) / 2)
        let maxY = max(0, (zoomedHeight - contentSize.height) / 2)
        return CGSize(
            width: min(max(offset.width, -maxX), maxX),
            height: min(max(offset.height, -maxY), maxY)
        )
    }
}
