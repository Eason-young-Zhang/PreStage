import Foundation
import Quartz

final class QuickLookPreviewService: NSObject, QLPreviewPanelDataSource, QLPreviewPanelDelegate {
    struct PreviewEntry {
        let id: UUID
        let url: URL
    }

    private var previewEntries: [PreviewEntry] = []
    private var previewItems: [NSURL] = []
    private var eventMonitor: Any?
    private var selectionSyncTimer: Timer?
    private var lastSyncedIndex: Int?
    private var onSelectItem: ((UUID) -> Void)?
    private var onSetRating: ((Int) -> Void)?
    private var onSetPickState: ((PickState) -> Void)?

    deinit {
        if let eventMonitor {
            NSEvent.removeMonitor(eventMonitor)
        }
        selectionSyncTimer?.invalidate()
    }

    func preview(
        entries: [PreviewEntry],
        initialItemID: UUID?,
        onSelectItem: @escaping (UUID) -> Void,
        onSetRating: @escaping (Int) -> Void,
        onSetPickState: @escaping (PickState) -> Void
    ) {
        previewEntries = entries
        previewItems = entries.map { $0.url as NSURL }
        self.onSelectItem = onSelectItem
        self.onSetRating = onSetRating
        self.onSetPickState = onSetPickState
        guard let panel = QLPreviewPanel.shared() else { return }

        if panel.isVisible {
            panel.orderOut(nil)
            return
        }

        panel.dataSource = self
        panel.delegate = self
        panel.reloadData()
        panel.currentPreviewItemIndex = initialIndex(for: initialItemID)
        syncSelection(with: panel)
        startSelectionSyncTimer(for: panel)
        installEventMonitor()
        panel.makeKeyAndOrderFront(nil)
    }

    func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int {
        previewItems.count
    }

    func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> QLPreviewItem! {
        guard previewItems.indices.contains(index) else { return nil }
        return previewItems[index]
    }

    func windowWillClose(_ notification: Notification) {
        stopSelectionSyncTimer()
        onSelectItem = nil
        onSetRating = nil
        onSetPickState = nil
    }

    private func initialIndex(for itemID: UUID?) -> Int {
        guard let itemID, let index = previewEntries.firstIndex(where: { $0.id == itemID }) else {
            return 0
        }
        return index
    }

    private func installEventMonitor() {
        guard eventMonitor == nil else { return }
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKeyDown(event) ?? event
        }
    }

    private func handleKeyDown(_ event: NSEvent) -> NSEvent? {
        guard let panel = QLPreviewPanel.shared(), panel.isVisible else { return event }
        let modifiers = event.modifierFlags.intersection([.command, .option, .control])
        guard modifiers.isEmpty else { return event }

        if let shortcut = event.charactersIgnoringModifiers?.lowercased(), handleWorkflowShortcut(shortcut, panel: panel) {
            return nil
        }

        switch event.keyCode {
        case 123, 124, 125, 126, 115, 116, 119, 121:
            DispatchQueue.main.async { [weak self, weak panel] in
                guard let panel else { return }
                self?.syncSelection(with: panel)
            }
        default:
            break
        }
        return event
    }

    private func startSelectionSyncTimer(for panel: QLPreviewPanel) {
        stopSelectionSyncTimer()
        selectionSyncTimer = Timer.scheduledTimer(withTimeInterval: 0.12, repeats: true) { [weak self, weak panel] timer in
            guard let self, let panel, panel.isVisible else {
                timer.invalidate()
                return
            }
            self.syncSelection(with: panel)
        }
    }

    private func stopSelectionSyncTimer() {
        selectionSyncTimer?.invalidate()
        selectionSyncTimer = nil
        lastSyncedIndex = nil
    }

    private func handleWorkflowShortcut(_ shortcut: String, panel: QLPreviewPanel) -> Bool {
        guard let character = shortcut.first else { return false }
        switch character {
        case "0"..."5":
            syncSelection(with: panel)
            onSetRating?(Int(String(character)) ?? 0)
            return true
        case "p":
            syncSelection(with: panel)
            onSetPickState?(.picked)
            return true
        case "x":
            syncSelection(with: panel)
            onSetPickState?(.rejected)
            return true
        case "u":
            syncSelection(with: panel)
            onSetPickState?(.unmarked)
            return true
        default:
            return false
        }
    }

    private func syncSelection(with panel: QLPreviewPanel) {
        let index = panel.currentPreviewItemIndex
        guard previewEntries.indices.contains(index), lastSyncedIndex != index else { return }
        lastSyncedIndex = index
        onSelectItem?(previewEntries[index].id)
    }
}
