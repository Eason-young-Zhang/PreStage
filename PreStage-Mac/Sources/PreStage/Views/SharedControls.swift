import AppKit
import SwiftUI

struct EmptyStateView: View {
    let title: String
    let systemImage: String
    let message: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 42))
                .foregroundStyle(.secondary)
            Text(L10n.tr(title))
                .font(.headline)
            Text(L10n.tr(message))
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 320)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }
}

struct ThumbnailImage: View {
    @EnvironmentObject private var store: AppStore
    let item: MediaItem
    let size: CGSize
    var contentMode: ContentMode = .fill
    var transform = MediaTransform()
    @State private var image: NSImage?

    init(item: MediaItem, size: CGSize, contentMode: ContentMode = .fill, transform: MediaTransform = MediaTransform()) {
        self.item = item
        self.size = size
        self.contentMode = contentMode
        self.transform = transform
    }

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
                    .rotationEffect(.degrees(transform.rotationDegrees))
                    .scaleEffect(x: transform.flippedHorizontally ? -1 : 1, y: transform.flippedVertically ? -1 : 1)
            } else {
                ZStack {
                    Rectangle().fill(.quaternary)
                    Image(systemName: item.mediaType == .video ? "film" : "photo")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .task(id: "\(item.thumbnailCacheKey)-\(Int(size.width))x\(Int(size.height))") {
            if let cached = store.thumbnails.image(for: item, size: size) {
                image = cached
                return
            }
            store.thumbnails.thumbnail(for: item, size: size) { loadedImage in
                image = loadedImage
            }
        }
    }
}

struct RatingStars: View {
    let rating: Int

    var body: some View {
        HStack(spacing: 1) {
            ForEach(1...5, id: \.self) { value in
                Image(systemName: value <= rating ? "star.fill" : "star")
                    .foregroundStyle(value <= rating ? .yellow : .secondary)
            }
        }
        .font(.caption2)
    }
}

struct PickBadge: View {
    let state: PickState

    var body: some View {
        switch state {
        case .unmarked:
            EmptyView()
        case .picked:
            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
        case .rejected:
            Image(systemName: "xmark.circle.fill").foregroundStyle(.red)
        }
    }
}

struct CopyStatusBadge: View {
    let status: CopyStatus

    var body: some View {
        if status != .notCopied {
            Text(status.label)
                .font(.caption2)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(.regularMaterial)
                .clipShape(Capsule())
        }
    }
}

struct RatingMenu: View {
    @EnvironmentObject private var store: AppStore
    var item: MediaItem?

    var body: some View {
        Menu(L10n.tr("Rating")) {
            ForEach(0...5, id: \.self) { value in
                Button(value == 0 ? L10n.tr("Clear") : "\(value) \(L10n.tr("Star"))") {
                    store.prepareContextAction(for: item)
                    store.setRating(value)
                }
            }
        }
    }
}

struct PickMenu: View {
    @EnvironmentObject private var store: AppStore
    var item: MediaItem?

    var body: some View {
        Menu(L10n.tr("Pick State")) {
            Button(L10n.tr("Pick")) {
                store.prepareContextAction(for: item)
                store.setPickState(.picked)
            }
            Button(L10n.tr("Reject")) {
                store.prepareContextAction(for: item)
                store.setPickState(.rejected)
            }
            Button(L10n.tr("Unmark")) {
                store.prepareContextAction(for: item)
                store.setPickState(.unmarked)
            }
        }
    }
}

struct ColorLabelMenu: View {
    @EnvironmentObject private var store: AppStore
    var item: MediaItem?

    var body: some View {
        Menu(L10n.tr("Color Label")) {
            Button(L10n.tr("None")) {
                store.prepareContextAction(for: item)
                store.setColorLabel(nil)
            }
            ForEach(ColorLabel.allCases) { label in
                Button(label.displayName) {
                    store.prepareContextAction(for: item)
                    store.setColorLabel(label)
                }
            }
        }
    }
}

struct FinderStyleContextMenu: View {
    @EnvironmentObject private var store: AppStore
    var item: MediaItem?

    var body: some View {
        Button(L10n.tr("Open")) { perform(store.openSelectedItems) }
        Button(L10n.tr("Reveal in Finder")) { perform(store.revealSelectedInFinder) }
        Divider()
        Button(L10n.tr("Move to Trash"), role: .destructive) { perform(store.moveSelectedItemsToTrash) }
        Divider()
        Button(L10n.tr("Duplicate")) { perform(store.duplicateSelectedItems) }
        Button(L10n.tr("Copy")) { perform(store.startCopySelected) }
        Button(L10n.tr("Share...")) { perform(store.shareSelectedItems) }
        Divider()
        RatingMenu(item: item)
        PickMenu(item: item)
        ColorLabelMenu(item: item)
        Divider()
        Button(L10n.tr("Rotate Left")) { perform { store.rotateFocusedItem(clockwise: false) } }
        Button(L10n.tr("Rotate Right")) { perform { store.rotateFocusedItem(clockwise: true) } }
        Button(L10n.tr("Flip Horizontal")) { perform { store.flipFocusedItem(horizontal: true) } }
    }

    private func perform(_ action: () -> Void) {
        store.prepareContextAction(for: item)
        action()
    }
}

struct ShortcutHintModifier: ViewModifier {
    let title: String
    let shortcut: String?

    func body(content: Content) -> some View {
        content
            .help(helpText)
    }

    private var helpText: String {
        guard let shortcut, !shortcut.isEmpty else { return title }
        return "\(title) \(shortcut)"
    }
}

extension View {
    func shortcutHelp(_ title: String, shortcut: String? = nil) -> some View {
        modifier(ShortcutHintModifier(title: title, shortcut: shortcut))
    }
}

struct SpaceKeyHandler: NSViewRepresentable {
    let action: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(action: action)
    }

    func makeNSView(context: Context) -> NSView {
        context.coordinator.installMonitor()
        return NSView(frame: .zero)
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.action = action
    }

    final class Coordinator {
        var action: () -> Void
        private var monitor: Any?

        init(action: @escaping () -> Void) {
            self.action = action
        }

        deinit {
            if let monitor {
                NSEvent.removeMonitor(monitor)
            }
        }

        func installMonitor() {
            guard monitor == nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self else { return event }
                guard event.keyCode == 49,
                      event.modifierFlags.intersection([.command, .option, .control]).isEmpty,
                      !isTextInputActive(in: event.window) else {
                    return event
                }
                action()
                return nil
            }
        }

        private func isTextInputActive(in window: NSWindow?) -> Bool {
            guard let responder = window?.firstResponder else { return false }
            return responder is NSTextView || responder is NSTextField
        }
    }
}

struct BrowserShortcutHandler: NSViewRepresentable {
    @EnvironmentObject private var store: AppStore

    func makeCoordinator() -> Coordinator {
        Coordinator(store: store)
    }

    func makeNSView(context: Context) -> NSView {
        context.coordinator.installMonitor()
        return NSView(frame: .zero)
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.store = store
    }

    @MainActor
    final class Coordinator {
        var store: AppStore
        private var monitor: Any?

        init(store: AppStore) {
            self.store = store
        }

        deinit {
            if let monitor {
                NSEvent.removeMonitor(monitor)
            }
        }

        func installMonitor() {
            guard monitor == nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self else { return event }
                guard !isTextInputActive(in: event.window) else { return event }

                let flags = event.modifierFlags.intersection([.command, .option, .control, .shift])
                switch (event.keyCode, flags) {
                case (0, [.command]):
                    store.selectAllVisibleItems()
                    return nil
                case (53, []):
                    store.clearSelection()
                    return nil
                case (18, [.command]):
                    store.viewMode = .grid
                    store.saveWorkspace()
                    return nil
                case (19, [.command]):
                    store.viewMode = .list
                    store.saveWorkspace()
                    return nil
                case (20, [.command]):
                    store.viewMode = .gallery
                    store.saveWorkspace()
                    return nil
                case (31, [.command, .option]):
                    store.openSelectedItems()
                    return nil
                case (15, [.command, .shift]):
                    store.revealSelectedInFinder()
                    return nil
                case (51, [.command]):
                    store.moveSelectedItemsToTrash()
                    return nil
                case (35, [.command, .option]):
                    store.toggleCopyPause()
                    return nil
                case (47, [.command]):
                    store.cancelCopy()
                    return nil
                default:
                    return event
                }
            }
        }

        private func isTextInputActive(in window: NSWindow?) -> Bool {
            guard let responder = window?.firstResponder else { return false }
            return responder is NSTextView || responder is NSTextField
        }
    }
}
