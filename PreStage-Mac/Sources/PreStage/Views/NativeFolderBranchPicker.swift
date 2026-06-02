import AppKit
import SwiftUI

struct NativeFolderBranchPicker: NSViewRepresentable {
    let branch: FolderBranch?
    let scale: FolderBrowserScale
    let placeholder: String
    let emptyMessage: String
    let onSelect: (URL) -> Void
    let onChooseParent: (URL) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onSelect: onSelect)
    }

    func makeNSView(context: Context) -> FolderBranchPickerView {
        let view = FolderBranchPickerView()
        view.collectionView.dataSource = context.coordinator
        view.collectionView.delegate = context.coordinator
        view.collectionView.register(FolderBranchItem.self, forItemWithIdentifier: FolderBranchItem.identifier)
        view.pathControl.target = context.coordinator
        view.pathControl.action = #selector(Coordinator.pathClicked(_:))
        context.coordinator.hostView = view
        context.coordinator.onChooseParent = onChooseParent
        return view
    }

    func updateNSView(_ nsView: FolderBranchPickerView, context: Context) {
        context.coordinator.branch = branch
        context.coordinator.onSelect = onSelect
        context.coordinator.onChooseParent = onChooseParent
        nsView.update(branch: branch, scale: scale, placeholder: placeholder, emptyMessage: emptyMessage)
        nsView.collectionView.reloadData()
        context.coordinator.syncSelection()
    }

    final class Coordinator: NSObject, NSCollectionViewDataSource, NSCollectionViewDelegate {
        var branch: FolderBranch?
        var onSelect: (URL) -> Void
        var onChooseParent: ((URL) -> Void)?
        weak var hostView: FolderBranchPickerView?

        init(onSelect: @escaping (URL) -> Void) {
            self.onSelect = onSelect
        }

        func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int {
            branch?.folders.count ?? 0
        }

        func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
            let item = collectionView.makeItem(withIdentifier: FolderBranchItem.identifier, for: indexPath)
            guard let folderItem = item as? FolderBranchItem,
                  let url = branch?.folders[indexPath.item] else {
                return item
            }
            folderItem.configure(name: url.lastPathComponent)
            return folderItem
        }

        func collectionView(_ collectionView: NSCollectionView, didSelectItemsAt indexPaths: Set<IndexPath>) {
            guard let index = indexPaths.first?.item,
                  let url = branch?.folders[index] else { return }
            onSelect(url)
        }

        func syncSelection() {
            guard let collectionView = hostView?.collectionView, let branch else { return }
            guard let selectedURL = branch.selectedURL,
                  let index = branch.folders.firstIndex(where: { $0.standardizedFileURL == selectedURL.standardizedFileURL }) else {
                collectionView.deselectAll(nil)
                return
            }
            collectionView.selectItems(at: [IndexPath(item: index, section: 0)], scrollPosition: .centeredVertically)
        }

        @objc func pathClicked(_ sender: NSPathControl) {
            guard let url = sender.clickedPathItem?.url ?? sender.url else { return }
            onChooseParent?(url)
        }
    }
}

final class FolderBranchPickerView: NSView {
    let pathControl = NSPathControl()
    let collectionView = NSCollectionView()
    private let scrollView = NSScrollView()
    private let placeholderLabel = NSTextField(labelWithString: "")
    private let emptyLabel = NSTextField(labelWithString: "")
    private let collectionLayout = NSCollectionViewFlowLayout()
    private var currentScale: FolderBrowserScale = .small
    private var lastLaidOutWidth: CGFloat = 0
    private var lastLaidOutScale: FolderBrowserScale?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    func update(branch: FolderBranch?, scale: FolderBrowserScale, placeholder: String, emptyMessage: String) {
        placeholderLabel.stringValue = placeholder
        emptyLabel.stringValue = emptyMessage
        placeholderLabel.isHidden = branch != nil
        pathControl.isHidden = branch == nil
        scrollView.isHidden = branch == nil
        emptyLabel.isHidden = branch == nil || branch?.folders.isEmpty == false
        pathControl.url = branch?.pathURL
        currentScale = scale
        updateCollectionGeometry()
    }

    override func layout() {
        super.layout()
        updateCollectionGeometry()
    }

    private func setup() {
        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true
        layer?.masksToBounds = true

        pathControl.translatesAutoresizingMaskIntoConstraints = false
        pathControl.pathStyle = .standard
        pathControl.focusRingType = .none
        pathControl.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        placeholderLabel.translatesAutoresizingMaskIntoConstraints = false
        placeholderLabel.textColor = .secondaryLabelColor
        placeholderLabel.font = .systemFont(ofSize: NSFont.smallSystemFontSize)

        collectionLayout.scrollDirection = .vertical
        collectionLayout.minimumInteritemSpacing = 6
        collectionLayout.minimumLineSpacing = 6
        collectionLayout.sectionInset = NSEdgeInsets(top: 4, left: 0, bottom: 4, right: 4)

        collectionView.collectionViewLayout = collectionLayout
        collectionView.isSelectable = true
        collectionView.allowsMultipleSelection = false
        collectionView.backgroundColors = [.clear]
        collectionView.autoresizingMask = [.width]
        collectionView.wantsLayer = true
        collectionView.layer?.masksToBounds = true

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.documentView = collectionView
        scrollView.drawsBackground = false
        scrollView.hasHorizontalScroller = false
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.scrollerStyle = .overlay
        scrollView.borderType = .noBorder
        scrollView.wantsLayer = true
        scrollView.layer?.masksToBounds = true

        addSubview(pathControl)
        addSubview(scrollView)
        addSubview(placeholderLabel)
        addSubview(emptyLabel)

        emptyLabel.translatesAutoresizingMaskIntoConstraints = false
        emptyLabel.textColor = .secondaryLabelColor
        emptyLabel.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        emptyLabel.alignment = .center

        NSLayoutConstraint.activate([
            pathControl.topAnchor.constraint(equalTo: topAnchor),
            pathControl.leadingAnchor.constraint(equalTo: leadingAnchor),
            pathControl.trailingAnchor.constraint(equalTo: trailingAnchor),
            pathControl.heightAnchor.constraint(equalToConstant: 24),

            scrollView.topAnchor.constraint(equalTo: pathControl.bottomAnchor, constant: 4),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),

            placeholderLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            placeholderLabel.leadingAnchor.constraint(equalTo: leadingAnchor),
            placeholderLabel.trailingAnchor.constraint(equalTo: trailingAnchor),

            emptyLabel.centerXAnchor.constraint(equalTo: scrollView.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: scrollView.centerYAnchor),
            emptyLabel.leadingAnchor.constraint(greaterThanOrEqualTo: scrollView.leadingAnchor, constant: 8),
            emptyLabel.trailingAnchor.constraint(lessThanOrEqualTo: scrollView.trailingAnchor, constant: -8)
        ])
    }

    private func updateCollectionGeometry() {
        let availableWidth = max(scrollView.contentView.bounds.width - collectionLayout.sectionInset.left - collectionLayout.sectionInset.right - 10, 1)
        guard abs(availableWidth - lastLaidOutWidth) > 0.5 || lastLaidOutScale != currentScale || collectionLayout.itemSize == .zero else { return }
        lastLaidOutWidth = availableWidth
        lastLaidOutScale = currentScale

        let metrics = metrics(for: currentScale)
        let unconstrainedColumns = max(1, Int((availableWidth + collectionLayout.minimumInteritemSpacing) / (metrics.minimumWidth + collectionLayout.minimumInteritemSpacing)))
        let columns = min(maximumColumns(for: currentScale, availableWidth: availableWidth), unconstrainedColumns)
        let width = floor((availableWidth - CGFloat(columns - 1) * collectionLayout.minimumInteritemSpacing) / CGFloat(columns))
        collectionLayout.itemSize = NSSize(width: min(availableWidth, max(metrics.minimumWidth, width)), height: metrics.height)

        var frame = collectionView.frame
        frame.size.width = scrollView.contentView.bounds.width
        collectionView.frame = frame
        collectionLayout.invalidateLayout()
    }

    private func metrics(for scale: FolderBrowserScale) -> (minimumWidth: CGFloat, height: CGFloat, maximumColumns: Int) {
        switch scale {
        case .small:
            return (96, 20, 4)
        case .large:
            return (180, 24, 1)
        }
    }

    private func maximumColumns(for scale: FolderBrowserScale, availableWidth: CGFloat) -> Int {
        switch scale {
        case .large:
            return 1
        case .small:
            if availableWidth < 330 { return 2 }
            if availableWidth < 430 { return 3 }
            return 4
        }
    }
}

final class FolderBranchItem: NSCollectionViewItem {
    static let identifier = NSUserInterfaceItemIdentifier("FolderBranchItem")

    private let label = NSTextField(labelWithString: "")

    override var isSelected: Bool {
        didSet {
            updateSelection()
        }
    }

    override func loadView() {
        view = NSView()
        view.wantsLayer = true
        view.layer?.cornerRadius = 5

        let icon = NSImageView(image: NSImage(systemSymbolName: "folder.fill", accessibilityDescription: nil) ?? NSImage())
        icon.translatesAutoresizingMaskIntoConstraints = false
        icon.imageScaling = .scaleProportionallyDown
        icon.contentTintColor = .secondaryLabelColor

        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        label.lineBreakMode = .byTruncatingMiddle

        view.addSubview(icon)
        view.addSubview(label)

        NSLayoutConstraint.activate([
            icon.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 7),
            icon.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 15),
            icon.heightAnchor.constraint(equalToConstant: 15),

            label.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 5),
            label.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -7),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
        updateSelection()
    }

    func configure(name: String) {
        label.stringValue = name
    }

    private func updateSelection() {
        view.layer?.backgroundColor = isSelected ? NSColor.controlAccentColor.withAlphaComponent(0.20).cgColor : NSColor(calibratedWhite: 0.76, alpha: 0.28).cgColor
    }
}
