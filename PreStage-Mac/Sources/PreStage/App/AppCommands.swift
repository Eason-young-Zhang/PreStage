import SwiftUI

struct AppCommands: Commands {
    @ObservedObject var store: AppStore

    var body: some Commands {
        CommandMenu(L10n.tr("Selection")) {
            Button(L10n.tr("Select All Visible")) {
                store.selectAllVisibleItems()
            }
            .keyboardShortcut("a", modifiers: [.command])
            .disabled(store.browserItems.isEmpty)

            Button(L10n.tr("Clear Selection")) {
                store.clearSelection()
            }
            .keyboardShortcut(.escape, modifiers: [])
            .disabled(store.selectedItemIDs.isEmpty)
        }

        CommandMenu(L10n.tr("Photo Workflow")) {
            Button(L10n.tr("Choose Source Folder...")) { store.chooseSourceFolder() }
                .keyboardShortcut("o", modifiers: [.command])

            Button(L10n.tr("Choose Target Folder...")) { store.chooseTargetFolder() }
                .keyboardShortcut("o", modifiers: [.command, .shift])

            Button(L10n.tr("Refresh Scan")) { Task { await store.scanSource() } }
                .keyboardShortcut("r", modifiers: [.command])

            Button(L10n.tr("Generate Proxy Files")) { store.generateProxyFiles() }
                .disabled(store.sourceURL == nil || store.mediaItems.isEmpty)

            Button(L10n.tr("Batch Rename...")) { store.isShowingBatchRename = true }
                .disabled(store.selectedItems.isEmpty)

            Button(L10n.tr("Undo Batch Rename")) { store.undoLastBatchRename() }
                .disabled(store.lastBatchRenameUndo == nil)

            Button(L10n.tr("Batch Rename Log")) { store.isShowingBatchRenameLog = true }

            Button(L10n.tr("Record Performance Baseline")) { store.recordPerformanceBaseline() }
                .disabled(store.sourceURL == nil)

            Button(L10n.tr("Record Gallery Preview Baseline")) { store.recordGalleryPreviewBaseline() }
                .disabled(store.sourceURL == nil || store.browserItems.isEmpty)

            Button(L10n.tr("Quick Look")) { store.quickLookSelectedItems() }
                .keyboardShortcut(.space, modifiers: [])
                .disabled(store.browserItems.isEmpty)

            Divider()

            Button(L10n.tr("Grid View")) {
                store.viewMode = .grid
                store.saveWorkspace()
            }
            .keyboardShortcut("1", modifiers: [.command])

            Button(L10n.tr("List View")) {
                store.viewMode = .list
                store.saveWorkspace()
            }
            .keyboardShortcut("2", modifiers: [.command])

            Button(L10n.tr("Gallery View")) {
                store.viewMode = .gallery
                store.saveWorkspace()
            }
            .keyboardShortcut("3", modifiers: [.command])

            Button(L10n.tr("Zoom In")) { store.adjustPreviewZoom(by: 0.12) }
                .keyboardShortcut("+", modifiers: [.command])

            Button(L10n.tr("Zoom Out")) { store.adjustPreviewZoom(by: -0.12) }
                .keyboardShortcut("-", modifiers: [.command])

            Button(L10n.tr("Reset Zoom")) { store.resetPreviewZoom() }
                .keyboardShortcut("0", modifiers: [.command])

            Divider()

            Button(L10n.tr("Copy Selected")) { store.startCopySelected() }
                .keyboardShortcut("c", modifiers: [.command])
                .disabled(store.copyProgress.isRunning || store.targetURL == nil || store.selectedItems.isEmpty)

            Button(store.copyProgress.isPaused ? L10n.tr("Resume Copy") : L10n.tr("Pause Copy")) {
                store.toggleCopyPause()
            }
            .keyboardShortcut("p", modifiers: [.command, .option])
            .disabled(!store.copyProgress.isRunning)

            Button(L10n.tr("Cancel Copy")) {
                store.cancelCopy()
            }
            .keyboardShortcut(".", modifiers: [.command])
            .disabled(!store.copyProgress.isRunning)

            Divider()

            Button(L10n.tr("Open")) { store.openSelectedItems() }
                .keyboardShortcut("o", modifiers: [.command, .option])
                .disabled(store.selectedItems.isEmpty)

            Button(L10n.tr("Reveal in Finder")) { store.revealSelectedInFinder() }
                .keyboardShortcut("r", modifiers: [.command, .shift])
                .disabled(store.selectedItems.isEmpty)

            Button(L10n.tr("Move to Trash")) { store.moveSelectedItemsToTrash() }
                .keyboardShortcut(.delete, modifiers: [.command])
                .disabled(store.selectedItems.isEmpty)

            Button(L10n.tr("Eject Camera Card")) { store.ejectSelectedVolume() }
                .keyboardShortcut("e", modifiers: [])
        }

        CommandMenu(L10n.tr("Rating")) {
            ForEach(0...5, id: \.self) { rating in
                Button(rating == 0 ? L10n.tr("Clear Rating") : "\(rating) \(L10n.tr("Star"))") {
                    store.setRating(rating)
                }
                .keyboardShortcut(KeyEquivalent(Character(String(rating))), modifiers: [])
            }

            Divider()

            Button(L10n.tr("Pick")) { store.setPickState(.picked) }
                .keyboardShortcut("p", modifiers: [])
            Button(L10n.tr("Reject")) { store.setPickState(.rejected) }
                .keyboardShortcut("x", modifiers: [])
            Button(L10n.tr("Unmark")) { store.setPickState(.unmarked) }
                .keyboardShortcut("u", modifiers: [])
        }
    }
}
