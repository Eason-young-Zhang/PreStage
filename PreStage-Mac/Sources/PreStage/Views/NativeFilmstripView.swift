import AppKit
import SwiftUI

struct NativeFilmstripView: NSViewRepresentable {
    let items: [MediaItem]
    let focusedItemID: UUID?
    let transforms: [String: MediaTransform]
    let isWindowLiveResizing: Bool
    let thumbnailService: ThumbnailService
    let titleProvider: (MediaItem) -> String
    let onSelect: (UUID) -> Void
    let onMove: (Int) -> Void
    let onSetRating: (Int) -> Void
    let onSetPickState: (PickState) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(
            items: items,
            transforms: transforms,
            thumbnailService: thumbnailService,
            titleProvider: titleProvider,
            onSelect: onSelect,
            onMove: onMove,
            onSetRating: onSetRating,
            onSetPickState: onSetPickState
        )
    }

    func makeNSView(context: Context) -> NSScrollView {
        let layout = FilmstripFlowLayout()
        layout.scrollDirection = .horizontal
        layout.itemSize = NSSize(width: 148, height: 108)
        layout.minimumInteritemSpacing = 10
        layout.minimumLineSpacing = 10
        layout.sectionInset = NSEdgeInsets(top: 10, left: 12, bottom: 10, right: 12)

        let collectionView = FilmstripCollectionView()
        collectionView.collectionViewLayout = layout
        collectionView.isSelectable = true
        collectionView.allowsMultipleSelection = false
        collectionView.backgroundColors = [.clear]
        collectionView.dataSource = context.coordinator
        collectionView.delegate = context.coordinator
        collectionView.onMove = onMove
        collectionView.onSetRating = onSetRating
        collectionView.onSetPickState = onSetPickState
        collectionView.register(FilmstripItemView.self, forItemWithIdentifier: FilmstripItemView.identifier)

        context.coordinator.collectionView = collectionView

        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.documentView = collectionView
        scrollView.borderType = .noBorder
        scrollView.scrollerStyle = .overlay

        DispatchQueue.main.async {
            collectionView.window?.makeFirstResponder(collectionView)
        }

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        context.coordinator.items = items
        context.coordinator.transforms = transforms
        context.coordinator.isWindowLiveResizing = isWindowLiveResizing
        context.coordinator.thumbnailService = thumbnailService
        context.coordinator.titleProvider = titleProvider
        context.coordinator.onSelect = onSelect
        context.coordinator.onMove = onMove
        context.coordinator.onSetRating = onSetRating
        context.coordinator.onSetPickState = onSetPickState
        context.coordinator.collectionView?.onMove = onMove
        context.coordinator.collectionView?.onSetRating = onSetRating
        context.coordinator.collectionView?.onSetPickState = onSetPickState
        context.coordinator.collectionView?.isWindowLiveResizing = isWindowLiveResizing
        context.coordinator.reloadIfNeeded()
        context.coordinator.syncSelection(focusedItemID)
    }

    final class Coordinator: NSObject, NSCollectionViewDataSource, NSCollectionViewDelegate, NSCollectionViewDelegateFlowLayout {
        var items: [MediaItem]
        var transforms: [String: MediaTransform]
        var isWindowLiveResizing = false
        var thumbnailService: ThumbnailService
        var titleProvider: (MediaItem) -> String
        var onSelect: (UUID) -> Void
        var onMove: (Int) -> Void
        var onSetRating: (Int) -> Void
        var onSetPickState: (PickState) -> Void
        weak var collectionView: FilmstripCollectionView?
        private var itemKeys: [String] = []
        private var renderedAspectRatios: [String: CGFloat] = [:]

        init(
            items: [MediaItem],
            transforms: [String: MediaTransform],
            thumbnailService: ThumbnailService,
            titleProvider: @escaping (MediaItem) -> String,
            onSelect: @escaping (UUID) -> Void,
            onMove: @escaping (Int) -> Void,
            onSetRating: @escaping (Int) -> Void,
            onSetPickState: @escaping (PickState) -> Void
        ) {
            self.items = items
            self.transforms = transforms
            self.thumbnailService = thumbnailService
            self.titleProvider = titleProvider
            self.onSelect = onSelect
            self.onMove = onMove
            self.onSetRating = onSetRating
            self.onSetPickState = onSetPickState
        }

        func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int {
            items.count
        }

        func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
            let collectionItem = collectionView.makeItem(withIdentifier: FilmstripItemView.identifier, for: indexPath)
            guard let filmstripItem = collectionItem as? FilmstripItemView else { return collectionItem }
            let mediaItem = items[indexPath.item]
            filmstripItem.configure(
                with: mediaItem,
                title: titleProvider(mediaItem),
                transform: transforms[mediaItem.thumbnailCacheKey, default: MediaTransform()],
                thumbnailService: thumbnailService,
                onRenderedAspectRatio: { [weak self] key, aspectRatio in
                    self?.recordRenderedAspectRatio(aspectRatio, for: key)
                }
            )
            return filmstripItem
        }

        func collectionView(_ collectionView: NSCollectionView, didSelectItemsAt indexPaths: Set<IndexPath>) {
            guard let index = indexPaths.first?.item, items.indices.contains(index) else { return }
            let selected = IndexPath(item: index, section: 0)
            let staleSelections = collectionView.selectionIndexPaths.subtracting([selected])
            if !staleSelections.isEmpty {
                collectionView.deselectItems(at: staleSelections)
            }
            onSelect(items[index].id)
            collectionView.window?.makeFirstResponder(collectionView)
        }

        func collectionView(
            _ collectionView: NSCollectionView,
            layout collectionViewLayout: NSCollectionViewLayout,
            sizeForItemAt indexPath: IndexPath
        ) -> NSSize {
            guard items.indices.contains(indexPath.item) else {
                return FilmstripFlowLayout.fallbackItemSize(for: collectionView)
            }
            let item = items[indexPath.item]
            return FilmstripFlowLayout.itemSize(
                for: item,
                transform: transforms[item.thumbnailCacheKey, default: MediaTransform()],
                renderedAspectRatio: renderedAspectRatios[item.thumbnailCacheKey],
                in: collectionView
            )
        }

        func reloadIfNeeded() {
            let nextKeys = Self.reloadKeys(for: items, transforms: transforms, titleProvider: titleProvider)
            guard nextKeys != itemKeys else { return }
            itemKeys = nextKeys
            collectionView?.collectionViewLayout?.invalidateLayout()
            collectionView?.reloadData()
        }

        private func recordRenderedAspectRatio(_ aspectRatio: CGFloat, for key: String) {
            guard aspectRatio.isFinite, aspectRatio > 0 else { return }
            if let current = renderedAspectRatios[key], abs(current - aspectRatio) < 0.01 {
                return
            }
            renderedAspectRatios[key] = aspectRatio
            guard !isWindowLiveResizing else { return }
            collectionView?.collectionViewLayout?.invalidateLayout()
        }

        static func reloadKeys(
            for items: [MediaItem],
            transforms: [String: MediaTransform],
            titleProvider: (MediaItem) -> String
        ) -> [String] {
            items.map { item in
                [
                    item.thumbnailCacheKey,
                    titleProvider(item),
                    "\(item.pixelWidth ?? 0)x\(item.pixelHeight ?? 0)",
                    "display:\(item.displayPixelWidth ?? 0)x\(item.displayPixelHeight ?? 0)",
                    "orientation:\(Int(item.displayRotationDegrees.rounded()))",
                    "rating:\(item.rating)",
                    "pick:\(item.pickState.rawValue)",
                    "label:\(item.colorLabel?.rawValue ?? "none")"
                ].joined(separator: "|")
            } + transforms
                .map { "\($0.key):\($0.value.rotationDegrees):\($0.value.flippedHorizontally):\($0.value.flippedVertically)" }
                .sorted()
        }

        func syncSelection(_ focusedItemID: UUID?) {
            guard let collectionView else { return }
            guard let focusedItemID, let index = items.firstIndex(where: { $0.id == focusedItemID }) else {
                collectionView.deselectAll(nil)
                return
            }
            let indexPath = IndexPath(item: index, section: 0)
            if collectionView.selectionIndexPaths != [indexPath] {
                collectionView.deselectAll(nil)
                collectionView.selectItems(at: [indexPath], scrollPosition: .centeredHorizontally)
            } else {
                collectionView.scrollToItems(at: [indexPath], scrollPosition: .centeredHorizontally)
            }
            DispatchQueue.main.async {
                collectionView.window?.makeFirstResponder(collectionView)
            }
        }
    }
}

final class FilmstripCollectionView: NSCollectionView {
    var onMove: ((Int) -> Void)?
    var onSetRating: ((Int) -> Void)?
    var onSetPickState: ((PickState) -> Void)?
    var isWindowLiveResizing = false {
        didSet {
            if oldValue, !isWindowLiveResizing {
                collectionViewLayout?.invalidateLayout()
            }
        }
    }

    override var acceptsFirstResponder: Bool { true }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        if !isWindowLiveResizing {
            collectionViewLayout?.invalidateLayout()
        }
    }

    override func keyDown(with event: NSEvent) {
        let modifiers = event.modifierFlags.intersection([.command, .option, .control])
        if modifiers.isEmpty, let characters = event.charactersIgnoringModifiers?.lowercased(), handleWorkflowShortcut(characters) {
            return
        }

        switch event.keyCode {
        case 123, 126:
            onMove?(-1)
        case 124, 125:
            onMove?(1)
        default:
            super.keyDown(with: event)
        }
    }

    private func handleWorkflowShortcut(_ characters: String) -> Bool {
        guard let character = characters.first else { return false }
        switch character {
        case "0"..."5":
            onSetRating?(Int(String(character)) ?? 0)
            return true
        case "p":
            onSetPickState?(.picked)
            return true
        case "x":
            onSetPickState?(.rejected)
            return true
        case "u":
            onSetPickState?(.unmarked)
            return true
        default:
            return false
        }
    }
}

final class FilmstripFlowLayout: NSCollectionViewFlowLayout {
    private static let verticalChrome: CGFloat = 8
    private static let horizontalChrome: CGFloat = 6
    private static let minimumItemWidth: CGFloat = 52
    private static let maximumItemWidth: CGFloat = 260
    private static let fallbackAspectRatio: CGFloat = 4.0 / 3.0

    override func prepare() {
        super.prepare()
        guard let collectionView else { return }
        itemSize = Self.fallbackItemSize(for: collectionView)
    }

    static func fallbackItemSize(for collectionView: NSCollectionView) -> NSSize {
        let itemHeight = itemHeight(for: collectionView)
        let imageHeight = max(24, itemHeight - verticalChrome)
        let width = clampedItemWidth(imageHeight * fallbackAspectRatio + horizontalChrome)
        return NSSize(width: width, height: itemHeight)
    }

    static func itemSize(
        for item: MediaItem,
        transform: MediaTransform,
        renderedAspectRatio: CGFloat? = nil,
        in collectionView: NSCollectionView
    ) -> NSSize {
        let itemHeight = itemHeight(for: collectionView)
        let imageHeight = max(24, itemHeight - verticalChrome)
        let aspectRatio = renderedAspectRatio ?? displayAspectRatio(for: item, transform: transform)
        let width = clampedItemWidth(imageHeight * aspectRatio + horizontalChrome)
        return NSSize(width: width, height: itemHeight)
    }

    private static func itemHeight(for collectionView: NSCollectionView) -> CGFloat {
        let flowLayout = collectionView.collectionViewLayout as? NSCollectionViewFlowLayout
        let insets = flowLayout?.sectionInset ?? NSEdgeInsets(top: 10, left: 12, bottom: 10, right: 12)
        return min(168, max(44, collectionView.bounds.height - insets.top - insets.bottom - 4))
    }

    static func displayAspectRatio(for item: MediaItem, transform: MediaTransform) -> CGFloat {
        item.displayAspectRatio(applying: transform) ?? fallbackAspectRatio
    }

    private static func clampedItemWidth(_ width: CGFloat) -> CGFloat {
        min(max(width, minimumItemWidth), maximumItemWidth)
    }
}

final class FilmstripItemView: NSCollectionViewItem {
    static let identifier = NSUserInterfaceItemIdentifier("FilmstripItemView")

    private let imageViewContainer = NSView()
    private let thumbnailImageView = TransformedThumbnailImageView()
    private let titleLabel = NSTextField(labelWithString: "")
    private let ratingLabel = NSTextField(labelWithString: "")
    private let pickBadge = NSTextField(labelWithString: "")
    private let colorDot = NSView()
    private let selectionRing = CALayer()
    private var representedURL: URL?

    override var isSelected: Bool {
        didSet {
            updateSelectionState()
        }
    }

    override func loadView() {
        view = NSView()
        view.wantsLayer = true
        view.layer?.cornerRadius = 7

        thumbnailImageView.wantsLayer = true

        imageViewContainer.translatesAutoresizingMaskIntoConstraints = false
        imageViewContainer.wantsLayer = true
        imageViewContainer.layer?.backgroundColor = NSColor.quaternaryLabelColor.withAlphaComponent(0.12).cgColor
        imageViewContainer.layer?.cornerRadius = 5

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = .systemFont(ofSize: 10)
        titleLabel.textColor = .secondaryLabelColor
        titleLabel.lineBreakMode = .byTruncatingMiddle
        titleLabel.alignment = .center
        titleLabel.isHidden = true

        ratingLabel.translatesAutoresizingMaskIntoConstraints = false
        ratingLabel.font = .systemFont(ofSize: 9, weight: .semibold)
        ratingLabel.textColor = .white
        ratingLabel.alignment = .left
        ratingLabel.isBezeled = false
        ratingLabel.drawsBackground = false
        ratingLabel.isEditable = false
        ratingLabel.isSelectable = false
        ratingLabel.wantsLayer = true
        ratingLabel.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.38).cgColor
        ratingLabel.layer?.cornerRadius = 5

        pickBadge.translatesAutoresizingMaskIntoConstraints = false
        pickBadge.font = .systemFont(ofSize: 9, weight: .bold)
        pickBadge.textColor = .white
        pickBadge.alignment = .center
        pickBadge.isBezeled = false
        pickBadge.drawsBackground = false
        pickBadge.isEditable = false
        pickBadge.isSelectable = false
        pickBadge.wantsLayer = true
        pickBadge.layer?.cornerRadius = 5

        colorDot.translatesAutoresizingMaskIntoConstraints = false
        colorDot.wantsLayer = true
        colorDot.layer?.cornerRadius = 4
        colorDot.layer?.borderColor = NSColor.black.withAlphaComponent(0.42).cgColor
        colorDot.layer?.borderWidth = 1

        thumbnailImageView.translatesAutoresizingMaskIntoConstraints = false
        imageViewContainer.addSubview(thumbnailImageView)
        imageViewContainer.addSubview(ratingLabel)
        imageViewContainer.addSubview(pickBadge)
        imageViewContainer.addSubview(colorDot)
        view.addSubview(imageViewContainer)
        view.addSubview(titleLabel)

        selectionRing.borderWidth = 0
        selectionRing.cornerRadius = 7
        view.layer?.addSublayer(selectionRing)

        NSLayoutConstraint.activate([
            imageViewContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 3),
            imageViewContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -3),
            imageViewContainer.topAnchor.constraint(equalTo: view.topAnchor, constant: 4),
            imageViewContainer.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -4),

            thumbnailImageView.topAnchor.constraint(equalTo: imageViewContainer.topAnchor),
            thumbnailImageView.leadingAnchor.constraint(equalTo: imageViewContainer.leadingAnchor),
            thumbnailImageView.trailingAnchor.constraint(equalTo: imageViewContainer.trailingAnchor),
            thumbnailImageView.bottomAnchor.constraint(equalTo: imageViewContainer.bottomAnchor),

            ratingLabel.leadingAnchor.constraint(equalTo: imageViewContainer.leadingAnchor, constant: 5),
            ratingLabel.bottomAnchor.constraint(equalTo: imageViewContainer.bottomAnchor, constant: -5),

            pickBadge.trailingAnchor.constraint(equalTo: imageViewContainer.trailingAnchor, constant: -5),
            pickBadge.topAnchor.constraint(equalTo: imageViewContainer.topAnchor, constant: 5),
            pickBadge.widthAnchor.constraint(greaterThanOrEqualToConstant: 16),
            pickBadge.heightAnchor.constraint(equalToConstant: 14),

            colorDot.leadingAnchor.constraint(equalTo: imageViewContainer.leadingAnchor, constant: 5),
            colorDot.topAnchor.constraint(equalTo: imageViewContainer.topAnchor, constant: 5),
            colorDot.widthAnchor.constraint(equalToConstant: 8),
            colorDot.heightAnchor.constraint(equalToConstant: 8),

            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 4),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -4),
            titleLabel.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -2),
            titleLabel.heightAnchor.constraint(equalToConstant: 14)
        ])
    }

    override func viewDidLayout() {
        super.viewDidLayout()
        titleLabel.isHidden = true
        selectionRing.frame = view.bounds.insetBy(dx: 1, dy: 1)
    }

    func configure(
        with item: MediaItem,
        title: String,
        transform: MediaTransform,
        thumbnailService: ThumbnailService,
        onRenderedAspectRatio: @escaping (String, CGFloat) -> Void
    ) {
        representedURL = item.url
        titleLabel.stringValue = title
        thumbnailImageView.image = NSImage(systemSymbolName: item.mediaType == .video ? "film" : "photo", accessibilityDescription: nil)
        thumbnailImageView.transform = transform
        updateBadges(for: item)
        updateSelectionState()
        loadThumbnail(for: item, transform: transform, thumbnailService: thumbnailService, onRenderedAspectRatio: onRenderedAspectRatio)
    }

    private func loadThumbnail(
        for item: MediaItem,
        transform: MediaTransform,
        thumbnailService: ThumbnailService,
        onRenderedAspectRatio: @escaping (String, CGFloat) -> Void
    ) {
        let size = thumbnailRequestSize(for: item, transform: transform)
        if let cached = thumbnailService.image(for: item, size: size) {
            thumbnailImageView.image = cached
            onRenderedAspectRatio(item.thumbnailCacheKey, TransformedThumbnailImageView.renderedAspectRatio(for: cached.size, transform: transform))
            return
        }

        thumbnailService.thumbnail(for: item, size: size) { [weak self] image in
            guard let self, self.representedURL == item.url else { return }
            self.thumbnailImageView.image = image
            if let image {
                onRenderedAspectRatio(item.thumbnailCacheKey, TransformedThumbnailImageView.renderedAspectRatio(for: image.size, transform: transform))
            }
        }
    }

    private func thumbnailRequestSize(for item: MediaItem, transform: MediaTransform) -> CGSize {
        let maxLength: CGFloat = 260
        let minLength: CGFloat = 64
        let aspectRatio = max(0.1, min(item.displayAspectRatio(applying: transform) ?? (4.0 / 3.0), 8))
        if aspectRatio >= 1 {
            return CGSize(width: maxLength, height: max(minLength, maxLength / aspectRatio))
        }
        return CGSize(width: max(minLength, maxLength * aspectRatio), height: maxLength)
    }

    private func updateSelectionState() {
        view.layer?.backgroundColor = isSelected ? NSColor.controlAccentColor.withAlphaComponent(0.16).cgColor : NSColor.clear.cgColor
        selectionRing.borderWidth = isSelected ? 2 : 0
        selectionRing.borderColor = NSColor.controlAccentColor.cgColor
    }

    private func updateBadges(for item: MediaItem) {
        if item.rating > 0 {
            ratingLabel.stringValue = String(repeating: "★", count: min(max(item.rating, 0), 5))
            ratingLabel.isHidden = false
        } else {
            ratingLabel.stringValue = ""
            ratingLabel.isHidden = true
        }

        switch item.pickState {
        case .picked:
            pickBadge.stringValue = "P"
            pickBadge.layer?.backgroundColor = NSColor.systemBlue.withAlphaComponent(0.72).cgColor
            pickBadge.isHidden = false
        case .rejected:
            pickBadge.stringValue = "X"
            pickBadge.layer?.backgroundColor = NSColor.systemRed.withAlphaComponent(0.72).cgColor
            pickBadge.isHidden = false
        case .unmarked:
            pickBadge.stringValue = ""
            pickBadge.isHidden = true
        }

        if let colorLabel = item.colorLabel {
            colorDot.layer?.backgroundColor = colorLabel.nsColor.cgColor
            colorDot.isHidden = false
        } else {
            colorDot.layer?.backgroundColor = NSColor.clear.cgColor
            colorDot.isHidden = true
        }
    }
}

private extension ColorLabel {
    var nsColor: NSColor {
        switch self {
        case .red: .systemRed
        case .yellow: .systemYellow
        case .green: .systemGreen
        case .blue: .systemBlue
        case .purple: .systemPurple
        }
    }
}

final class TransformedThumbnailImageView: NSView {
    var image: NSImage? {
        didSet { needsDisplay = true }
    }

    var transform = MediaTransform() {
        didSet { needsDisplay = true }
    }

    override var isFlipped: Bool { true }

    static func renderedAspectRatio(for size: CGSize, transform: MediaTransform) -> CGFloat {
        guard size.width > 0, size.height > 0 else { return 4.0 / 3.0 }
        let normalizedRotation = ((Int(transform.rotationDegrees) % 360) + 360) % 360
        let swapsAxes = normalizedRotation == 90 || normalizedRotation == 270
        let width = swapsAxes ? size.height : size.width
        let height = swapsAxes ? size.width : size.height
        return max(0.1, min(width / height, 12))
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let image else { return }
        let imageSize = image.size
        guard imageSize.width > 0, imageSize.height > 0, bounds.width > 0, bounds.height > 0 else { return }

        NSBezierPath(roundedRect: bounds, xRadius: 5, yRadius: 5).addClip()
        let normalizedRotation = ((Int(transform.rotationDegrees) % 360) + 360) % 360
        let swapsAxes = normalizedRotation == 90 || normalizedRotation == 270
        let fittedImageSize = swapsAxes ? NSSize(width: imageSize.height, height: imageSize.width) : imageSize
        let scale = min(bounds.width / fittedImageSize.width, bounds.height / fittedImageSize.height)
        let drawSize = NSSize(width: imageSize.width * scale, height: imageSize.height * scale)
        let drawRect = NSRect(
            x: bounds.midX - drawSize.width / 2,
            y: bounds.midY - drawSize.height / 2,
            width: drawSize.width,
            height: drawSize.height
        )

        guard let context = NSGraphicsContext.current?.cgContext else { return }
        context.saveGState()
        context.translateBy(x: bounds.midX, y: bounds.midY)
        context.rotate(by: transform.rotationDegrees * .pi / 180)
        context.scaleBy(x: transform.flippedHorizontally ? -1 : 1, y: transform.flippedVertically ? -1 : 1)
        context.translateBy(x: -bounds.midX, y: -bounds.midY)
        image.draw(
            in: drawRect,
            from: .zero,
            operation: .copy,
            fraction: 1,
            respectFlipped: true,
            hints: [.interpolation: NSImageInterpolation.high]
        )
        context.restoreGState()
    }
}
