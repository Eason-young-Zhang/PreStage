import AppKit
import Foundation

@MainActor
final class AppStore: ObservableObject {
    @Published var sourceURL: URL?
    @Published var sourceSelectionURL: URL?
    @Published var targetURL: URL?
    @Published var targetSelectionURL: URL?
    @Published var cameraVolumes: [CameraVolume] = []
    @Published var mediaItems: [MediaItem] = []
    @Published var selectedItemIDs = Set<UUID>()
    @Published var focusedItemID: UUID?
    @Published var viewMode: ViewMode = .grid {
        didSet {
            guard oldValue != viewMode else { return }
            if viewMode == .gallery {
                schedulePreviewPreheatForFocus()
            } else {
                cancelPreviewPreheat(resetProgress: true)
            }
        }
    }
    @Published var filterState = FilterState()
    @Published var sortRule: SortRule = .default
    @Published var copyRule: CopyOrganizationRule = .captureDate
    @Published var copyConflictPolicy: CopyConflictPolicy = .autoRename
    @Published var copyContentMode: CopyContentMode = .allSupported
    @Published var copyVerificationMode: CopyVerificationMode = .sizeOnly
    @Published var panelLayout = PanelLayout()
    @Published var copyProgress = CopyProgress()
    @Published var proxyProgress = ProxyGenerationProgress()
    @Published var previewPreheatProgress = PreviewPreheatProgress()
    @Published var previewPreheatSummary: String?
    @Published var metadataProgress = MetadataLoadProgress()
    @Published var statusMessage = "Choose a source folder or scan a camera card."
    @Published var preservePaths = true
    @Published var appLanguage: AppLanguage = .system {
        didSet {
            L10n.currentLanguage = appLanguage
            L10n.applySystemPanelLanguagePreference(appLanguage)
        }
    }
    @Published var searchText = ""
    @Published var mediaTransforms: [String: MediaTransform] = [:]
    @Published var copyLogs: [CopyLogRecord] = []
    @Published var isShowingCopyLog = false
    @Published var batchRenameLogs: [BatchRenameLogRecord] = []
    @Published var isShowingBatchRenameLog = false
    @Published var isShowingBatchRename = false
    @Published var lastBatchRenameUndo: BatchRenameUndoRecord?
    @Published var includeSourceSubfolders = false
    @Published var expandedProxyStackKeys = Set<String>()
    @Published var cameraCardAction: CameraCardAction = .notify
    @Published var workspacePresets: [WorkspacePreset] = [.default]
    @Published var activeWorkspacePresetID: UUID = WorkspacePreset.default.id
    @Published var isWindowLiveResizing = false

    let thumbnails = ThumbnailService()
    let histograms = HistogramService()
    let waveforms = WaveformService()
    private let scanner = MediaScanner()
    private let folderBranches = FolderBranchService()
    private let volumes = VolumeDetectionService()
    private let batchRenamer = BatchRenameService()
    private let copier = CopyService()
    private let workspace = WorkspaceService()
    private let xmp = XMPService()
    private let imageOrientation = ImageOrientationService()
    private let proxyGenerator = ProxyGenerationService()
    private let previewDecoder = PreviewDecodeService.shared
    private let previewPreheater = PreviewPreheatService()
    private let performanceBaseline = PerformanceBaselineService()
    private let galleryPreviewBaseline = GalleryPreviewBaselineService()
    private let metadataCache = MetadataDiskCache()
    private let quickLook = QuickLookPreviewService()
    private let sorter = MediaSortService()
    private var scannedSourceSignature: String?
    private var workspaceSaveTask: Task<Void, Never>?
    private var knownCameraVolumeURLs = Set<URL>()
    private var copyTask: Task<Void, Never>?
    private var copyControl: CopyOperationControl?
    private var previewPreheatTask: Task<Void, Never>?
    private var previewPreheatSummaryTask: Task<Void, Never>?
    private var previewPreheatGeneration = 0
    private var performanceBaselineTask: Task<Void, Never>?
    private var galleryPreviewBaselineTask: Task<Void, Never>?
    private var metadataTask: Task<Void, Never>?
    private var metadataGeneration = 0
    private var loadedMetadataFingerprints = Set<String>()

    init() {
        restoreWorkspace()
        refreshVolumes()
        knownCameraVolumeURLs = Set(cameraVolumes.map(\.url))
        volumes.startMonitoring { [weak self] in
            self?.handleCameraVolumesChanged()
        }
        if sourceURL != nil {
            Task { await scanSource() }
        }
    }

    var filteredItems: [MediaItem] {
        var activeFilter = filterState
        activeFilter.searchText = searchText
        let filtered = mediaItems.filter(activeFilter.includes)
        return sorter.sorted(filtered, using: sortRule)
    }

    var browserItems: [MediaItem] {
        switch viewMode {
        case .list:
            return filteredItems
        case .grid:
            return proxyCollapsedItems(from: filteredItems, expandedPairKeys: expandedProxyStackKeys)
        case .gallery:
            return proxyCollapsedItems(from: filteredItems)
        }
    }

    var selectedItems: [MediaItem] {
        mediaItems.filter { selectedItemIDs.contains($0.id) }
    }

    var focusedItem: MediaItem? {
        let items = browserItems
        if let focusedItemID, let selected = items.first(where: { $0.id == focusedItemID }) {
            return selected
        }
        if let focusedItemID,
           let source = mediaItems.first(where: { $0.id == focusedItemID }),
           let displayItem = proxyDisplayItem(matching: source, in: items) {
            return displayItem
        }
        if let selected = selectedItemIDs.compactMap({ id in items.first(where: { $0.id == id }) }).first {
            return selected
        }
        if let selected = selectedItemIDs.compactMap({ id in mediaItems.first(where: { $0.id == id }) }).compactMap({ proxyDisplayItem(matching: $0, in: items) }).first {
            return selected
        }
        return items.first
    }

    var focusedBrowserItemID: UUID? {
        focusedItem?.id
    }

    func galleryPreviewURL(for item: MediaItem) -> URL {
        previewDecoder.previewSource(for: item, sourceRoot: activeSourceURL).url
    }

    var activeSourceURL: URL? {
        sourceSelectionURL ?? sourceURL
    }

    var sourceBranch: FolderBranch? {
        folderBranches.sourceBranch(for: sourceURL, selectedURL: sourceSelectionURL)
    }

    var targetBranch: FolderBranch? {
        folderBranches.targetBranch(for: targetURL, selectedURL: targetSelectionURL)
    }

    func chooseSourceFolder() {
        chooseFolder(titleKey: "Choose Source Folder") { [weak self] url in
            guard let self else { return }
            sourceURL = url
            sourceSelectionURL = nil
            saveWorkspace()
            Task { await self.scanSource() }
        }
    }

    func chooseTargetFolder() {
        chooseFolder(titleKey: "Choose Target Folder") { [weak self] url in
            guard let self else { return }
            targetURL = url
            targetSelectionURL = nil
            saveWorkspace()
        }
    }

    func useCameraVolume(_ volume: CameraVolume) {
        selectCameraVolume(volume, shouldScan: false)
        Task { await scanSource() }
    }

    func selectSourceFolder(_ url: URL) {
        sourceURL = url
        sourceSelectionURL = nil
        saveWorkspace()
        Task { await scanSource() }
    }

    func selectSourceLocation(_ url: URL) {
        sourceSelectionURL = url
        saveWorkspace()
        Task { await scanSource() }
    }

    func selectTargetFolder(_ url: URL) {
        targetURL = url
        targetSelectionURL = nil
        saveWorkspace()
    }

    func selectTargetLocation(_ url: URL) {
        targetSelectionURL = url
        saveWorkspace()
        statusMessage = "Selected target location \(url.lastPathComponent)."
    }

    func createFolderInTarget() {
        guard let targetURL else {
            chooseTargetFolder()
            return
        }

        let alert = NSAlert()
        alert.messageText = "New Folder"
        alert.informativeText = "Create a folder inside \(targetURL.lastPathComponent)."
        alert.addButton(withTitle: "Create")
        alert.addButton(withTitle: "Cancel")

        let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 260, height: 24))
        input.stringValue = defaultNewFolderName(in: targetURL)
        alert.accessoryView = input

        guard alert.runModal() == .alertFirstButtonReturn else { return }

        let trimmedName = input.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        let newURL = targetURL.appendingPathComponent(trimmedName, isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: newURL, withIntermediateDirectories: false)
            targetSelectionURL = newURL
            saveWorkspace()
            statusMessage = "Created target folder \(trimmedName)."
        } catch {
            statusMessage = "Could not create folder: \(error.localizedDescription)"
        }
    }

    func refreshVolumes() {
        cameraVolumes = volumes.detectCameraVolumes()
        if cameraVolumes.isEmpty {
            statusMessage = "No camera storage cards detected."
        } else {
            statusMessage = "Detected \(cameraVolumes.count) removable volume\(cameraVolumes.count == 1 ? "" : "s")."
        }
    }

    func setCameraCardAction(_ action: CameraCardAction) {
        guard cameraCardAction != action else { return }
        cameraCardAction = action
        saveWorkspace()
    }

    func handleCameraVolumesChanged() {
        let previousURLs = knownCameraVolumeURLs
        refreshVolumes()
        let currentURLs = Set(cameraVolumes.map(\.url))
        knownCameraVolumeURLs = currentURLs
        guard let inserted = cameraVolumes.first(where: { !previousURLs.contains($0.url) }) else { return }
        handleInsertedCameraVolume(inserted)
    }

    private func handleInsertedCameraVolume(_ volume: CameraVolume) {
        switch cameraCardAction {
        case .off:
            break
        case .notify:
            statusMessage = String(format: L10n.tr("Detected camera card %@."), volume.name)
        case .selectDCIM:
            selectCameraVolume(volume, shouldScan: false)
            statusMessage = String(format: L10n.tr("Selected camera card %@."), volume.name)
        case .selectAndScan:
            selectCameraVolume(volume, shouldScan: true)
        }
    }

    private func selectCameraVolume(_ volume: CameraVolume, shouldScan: Bool) {
        sourceURL = volume.hasDCIM ? volume.url.appendingPathComponent("DCIM", isDirectory: true) : volume.url
        sourceSelectionURL = nil
        saveWorkspace()
        if shouldScan {
            Task { await scanSource() }
        }
    }

    func ejectSelectedVolume() {
        guard let activeSourceURL,
              let volume = cameraVolumes.first(where: { activeSourceURL.path.hasPrefix($0.url.path) }) else {
            statusMessage = "No mounted camera volume is selected."
            return
        }
        volumes.eject(volume) { [weak self] success in
            self?.statusMessage = success ? "Ejected \(volume.name)." : "Could not eject \(volume.name)."
            self?.refreshVolumes()
        }
    }

    func scanSource() async {
        guard let activeSourceURL else { return }
        cancelPreviewPreheat(resetProgress: true)
        cancelMetadataLoading(resetProgress: true)
        loadedMetadataFingerprints.removeAll()
        let sourceSignature = scanSignature(for: activeSourceURL)
        if scannedSourceSignature != sourceSignature {
            thumbnails.removeAll()
            scannedSourceSignature = sourceSignature
        }

        statusMessage = "Scanning \(activeSourceURL.lastPathComponent)..."
        do {
            let includeSourceSubfolders = includeSourceSubfolders
            let items = try await Task.detached(priority: .userInitiated) {
                let xmpService = XMPService()
                let pairingService = MediaPairingService()
                let scannedItems = try self.scanner.scan(directory: activeSourceURL, recursive: includeSourceSubfolders)
                let enrichedItems = scannedItems
                    .map { xmpService.applySidecarMetadata(to: $0) }
                return pairingService.assignPairingKeys(to: enrichedItems)
            }.value
            mediaItems = items
            pruneMediaTransforms(for: items)
            let firstID = browserItems.first?.id
            focusedItemID = firstID
            selectedItemIDs = firstID.map { [$0] } ?? []
            schedulePreviewPreheatForFocus()
            scheduleMetadataLoading()
            statusMessage = includeSourceSubfolders
                ? String(format: L10n.tr("Found %d supported media files including subfolders."), items.count)
                : String(format: L10n.tr("Found %d supported media files in this folder."), items.count)
        } catch {
            statusMessage = "Scan failed: \(error.localizedDescription)"
        }
    }

    func scanSourceKeepingSelection(itemID: UUID?) async {
        let selectedURL = itemID.flatMap { id in mediaItems.first(where: { $0.id == id })?.url }
        await scanSource()
        if let selectedURL, let item = mediaItems.first(where: { $0.url == selectedURL }) {
            selectItem(id: item.id)
        }
    }

    func selectItem(id: UUID, extendingSelection: Bool = false) {
        focusedItemID = id
        if extendingSelection {
            if selectedItemIDs.contains(id) {
                selectedItemIDs.remove(id)
                if selectedItemIDs.isEmpty {
                    selectedItemIDs.insert(id)
                }
            } else {
                selectedItemIDs.insert(id)
            }
        } else {
            selectedItemIDs = [id]
        }
        schedulePreviewPreheatForFocus()
        scheduleMetadataLoading()
    }

    func prepareContextAction(for item: MediaItem?) {
        guard let item else { return }
        if isSelectedForDisplay(item) {
            focusedItemID = item.id
            schedulePreviewPreheatForFocus()
            scheduleMetadataLoading()
        } else {
            selectItem(id: item.id)
        }
    }

    func selectItems(_ ids: Set<UUID>) {
        selectedItemIDs = ids
        syncFocusedItemToSelection()
        schedulePreviewPreheatForFocus()
        scheduleMetadataLoading()
    }

    func selectAllVisibleItems() {
        let ids = Set(browserItems.map(\.id))
        guard !ids.isEmpty else { return }
        selectedItemIDs = ids
        syncFocusedItemToSelection()
        statusMessage = String(format: L10n.tr("Selected %d visible files."), ids.count)
    }

    func clearSelection() {
        selectedItemIDs.removeAll()
        focusedItemID = browserItems.first?.id
        schedulePreviewPreheatForFocus()
        scheduleMetadataLoading()
        statusMessage = L10n.tr("Selection cleared.")
    }

    func syncFocusedItemToSelection() {
        let items = browserItems
        if let focusedItemID, selectedItemIDs.contains(focusedItemID), items.contains(where: { $0.id == focusedItemID }) {
            return
        }
        focusedItemID = selectedItemIDs.compactMap { id in
            items.first(where: { $0.id == id })?.id
        }.first ?? selectedItemIDs.compactMap { id in
            mediaItems.first(where: { $0.id == id }).flatMap { proxyDisplayItem(matching: $0, in: items) }?.id
        }.first ?? items.first?.id
    }

    func moveSelection(by offset: Int) {
        let items = browserItems
        guard !items.isEmpty else { return }

        let currentID = focusedItemID ?? selectedItemIDs.first ?? items.first?.id
        let currentIndex = currentID.flatMap { id in
            items.firstIndex { $0.id == id } ?? mediaItems.first(where: { $0.id == id })
                .flatMap { proxyDisplayItem(matching: $0, in: items) }
                .flatMap { displayItem in items.firstIndex { $0.id == displayItem.id } }
        } ?? 0
        let nextIndex = min(max(currentIndex + offset, 0), items.count - 1)
        selectItem(id: items[nextIndex].id)
    }

    func setSortField(_ field: SortField) {
        sortRule = SortRule(field: field, direction: sortRule.direction)
        saveWorkspace()
        schedulePreviewPreheatForFocus()
    }

    func toggleSortDirection() {
        sortRule = SortRule(field: sortRule.field, direction: sortRule.direction.toggled)
        saveWorkspace()
        schedulePreviewPreheatForFocus()
    }

    func setRating(_ rating: Int) {
        mutateSelected { $0.rating = max(0, min(5, rating)) }
        writeSelectedXMP()
    }

    func setPickState(_ state: PickState) {
        mutateSelected { $0.pickState = state }
        writeSelectedXMP()
    }

    func setColorLabel(_ label: ColorLabel?) {
        mutateSelected { $0.colorLabel = label }
        writeSelectedXMP()
    }

    func startCopySelected() {
        guard copyProgress.isRunning == false else {
            statusMessage = L10n.tr("A copy operation is already running.")
            return
        }
        guard let targetURL else {
            statusMessage = "Choose a target folder before copying."
            return
        }
        let destinationURL = targetSelectionURL ?? targetURL
        let items = copyItems(from: selectedItems)
        guard !items.isEmpty else {
            statusMessage = "Select files before copying."
            return
        }

        let logID = beginCopyLog(items: items, destinationURL: destinationURL)
        let control = CopyOperationControl()
        copyControl = control
        copyTask = Task {
            await copier.copyItems(
                items,
                to: destinationURL,
                sourceRoot: activeSourceURL,
                rule: copyRule,
                conflictPolicy: copyConflictPolicy,
                verificationMode: copyVerificationMode,
                control: control
            ) { [weak self] progress, itemID, status in
                guard let self else { return }
                copyProgress = progress
                statusMessage = progress.message
                if let itemID, let status, let index = mediaItems.firstIndex(where: { $0.id == itemID }) {
                    mediaItems[index].copyStatus = status
                    if status.isFinalLogStatus {
                        appendCopyLogEntry(logID: logID, item: mediaItems[index], status: status, message: status.label)
                    }
                }
                if !progress.isRunning {
                    finishCopyLog(logID: logID, message: progress.message)
                    copyTask = nil
                    copyControl = nil
                }
            }
        }
    }

    func pauseCopy() {
        guard copyProgress.isRunning, copyProgress.isPaused == false else { return }
        Task {
            await copyControl?.pause()
            await MainActor.run {
                copyProgress.isPaused = true
                copyProgress.message = L10n.tr("Copy paused.")
                statusMessage = copyProgress.message
            }
        }
    }

    func resumeCopy() {
        guard copyProgress.isRunning, copyProgress.isPaused else { return }
        Task {
            await copyControl?.resume()
            await MainActor.run {
                copyProgress.isPaused = false
                copyProgress.message = L10n.tr("Copying")
                statusMessage = copyProgress.message
            }
        }
    }

    func toggleCopyPause() {
        copyProgress.isPaused ? resumeCopy() : pauseCopy()
    }

    func cancelCopy() {
        guard copyProgress.isRunning else { return }
        Task {
            await copyControl?.cancel()
            await MainActor.run {
                copyProgress.isPaused = false
                statusMessage = L10n.tr("Cancelling copy...")
            }
        }
    }

    func batchRenamePlan(for rule: BatchRenameRule) -> BatchRenamePlan {
        batchRenamer.makePlan(items: expandedItemsForCopy(selectedItems), rule: rule)
    }

    func applyBatchRename(rule: BatchRenameRule) async -> Bool {
        let plan = batchRenamePlan(for: rule)
        guard plan.canApply else {
            statusMessage = plan.issues.first?.message ?? L10n.tr("Fix rename conflicts before applying.")
            return false
        }

        do {
            let result = try batchRenamer.apply(plan)
            lastBatchRenameUndo = result.undoActions.isEmpty
                ? nil
                : BatchRenameUndoRecord(renamedMediaCount: result.renamedMediaCount, actions: result.undoActions)
            appendBatchRenameLog(plan: plan, renamedMediaCount: result.renamedMediaCount)
            statusMessage = String(format: L10n.tr("Renamed %d files. Undo is available."), result.renamedMediaCount)
            await scanSource()
            return true
        } catch {
            statusMessage = String(format: L10n.tr("Batch rename failed: %@"), error.localizedDescription)
            return false
        }
    }

    func clearBatchRenameLogs() {
        batchRenameLogs.removeAll()
        saveWorkspace()
    }

    func undoLastBatchRename() {
        guard let undoRecord = lastBatchRenameUndo else {
            statusMessage = L10n.tr("No batch rename operation is available to undo.")
            return
        }

        do {
            try batchRenamer.undo(undoRecord)
            lastBatchRenameUndo = nil
            statusMessage = String(format: L10n.tr("Undid rename for %d files."), undoRecord.renamedMediaCount)
            Task { await scanSource() }
        } catch {
            statusMessage = String(format: L10n.tr("Undo batch rename failed: %@"), error.localizedDescription)
        }
    }

    func generateProxyFiles() {
        guard let activeSourceURL else {
            statusMessage = L10n.tr("Choose a source folder before generating proxy files.")
            return
        }
        let imageItems = mediaItems.filter { $0.mediaType != .video }
        guard !imageItems.isEmpty else {
            statusMessage = L10n.tr("No image files are available for proxy generation.")
            return
        }

        proxyProgress = ProxyGenerationProgress(totalCount: imageItems.count, isRunning: true)
        statusMessage = String(format: L10n.tr("Generating proxy files for %d images..."), imageItems.count)
        Task {
            await proxyGenerator.generateProxies(for: imageItems, sourceRoot: activeSourceURL) { [weak self] progress in
                guard let self else { return }
                proxyProgress = progress
                if progress.isRunning {
                    statusMessage = String(
                        format: L10n.tr("Generating proxy files: %d of %d%@"),
                        progress.completedCount,
                        progress.totalCount,
                        progress.currentFilename.isEmpty ? "" : " · \(progress.currentFilename)"
                    )
                } else {
                    statusMessage = String(
                        format: L10n.tr("Generated %d proxy files, skipped %d, failed %d."),
                        progress.createdCount,
                        progress.skippedCount,
                        progress.failedCount
                    )
                    Task { await self.scanSource() }
                }
            }
        }
    }

    func recordPerformanceBaseline() {
        guard performanceBaselineTask == nil else {
            statusMessage = L10n.tr("A performance baseline is already running.")
            return
        }
        guard let activeSourceURL else {
            statusMessage = L10n.tr("Choose a source folder before recording a performance baseline.")
            return
        }

        let recursive = includeSourceSubfolders
        statusMessage = String(format: L10n.tr("Recording performance baseline for %@..."), activeSourceURL.lastPathComponent)
        performanceBaselineTask = Task { [weak self, performanceBaseline] in
            do {
                let result = try await performanceBaseline.recordBaseline(sourceURL: activeSourceURL, recursive: recursive)
                await MainActor.run {
                    guard let self else { return }
                    self.performanceBaselineTask = nil
                    self.statusMessage = String(
                        format: L10n.tr("Baseline: %d files, %@, total %.1fs, scan %.1fs, metadata %.1fs, proxies %d/%d"),
                        result.totalItems,
                        AppFormatters.byteCount.string(fromByteCount: result.totalBytes),
                        result.totalDuration,
                        result.scanDuration,
                        result.metadataDuration + result.xmpDuration,
                        result.rawProxyValidCount,
                        result.rawProxyTotalCount
                    )
                    self.showPerformanceBaselineReport(result)
                }
            } catch {
                await MainActor.run {
                    self?.performanceBaselineTask = nil
                    self?.statusMessage = String(format: L10n.tr("Performance baseline failed: %@"), error.localizedDescription)
                }
            }
        }
    }

    func recordGalleryPreviewBaseline() {
        guard galleryPreviewBaselineTask == nil else {
            statusMessage = L10n.tr("A gallery preview baseline is already running.")
            return
        }
        guard let activeSourceURL else {
            statusMessage = L10n.tr("Choose a source folder before recording a gallery preview baseline.")
            return
        }
        let items = browserItems.filter { $0.mediaType != .video }
        guard !items.isEmpty else {
            statusMessage = L10n.tr("No image files are available for gallery preview baseline.")
            return
        }

        statusMessage = String(format: L10n.tr("Recording gallery preview baseline for %d images..."), min(items.count, 40))
        galleryPreviewBaselineTask = Task { [weak self, galleryPreviewBaseline] in
            let result = await galleryPreviewBaseline.recordBaseline(items: items, sourceRoot: activeSourceURL)
            await MainActor.run {
                guard let self else { return }
                self.galleryPreviewBaselineTask = nil
                self.statusMessage = String(
                    format: L10n.tr("Gallery baseline: %d images, avg %.2fs, failures %d, RAW proxies %d/%d"),
                    result.sampledItems,
                    result.averageWarmDuration,
                    result.failedCount,
                    result.rawProxyHitCount,
                    result.rawItems
                )
                self.showGalleryPreviewBaselineReport(result)
            }
        }
    }

    func shareSelectedItems() {
        let urls = selectedItems.map(\.url)
        guard !urls.isEmpty else {
            statusMessage = "Select at least one file to share."
            return
        }
        guard let view = NSApp.keyWindow?.contentView else { return }
        NSSharingServicePicker(items: urls).show(relativeTo: view.bounds, of: view, preferredEdge: .minY)
    }

    func openSelectedItems() {
        selectedItems.forEach { NSWorkspace.shared.open($0.url) }
    }

    func revealSelectedInFinder() {
        let urls = selectedItems.map(\.url)
        guard !urls.isEmpty else { return }
        NSWorkspace.shared.activateFileViewerSelecting(urls)
    }

    func quickLookSelectedItems() {
        let items = browserItems
        guard !items.isEmpty else { return }
        let previewItems = quickLookPreviewItems(from: items)
        guard !previewItems.isEmpty else { return }
        let initialItemID = focusedBrowserItemID ?? selectedItemIDs.first ?? items.first?.id
        quickLook.preview(
            entries: previewItems.map { QuickLookPreviewService.PreviewEntry(id: $0.id, url: $0.url) },
            initialItemID: initialItemID,
            onSelectItem: { [weak self] id in
                self?.selectItem(id: id)
            },
            onSetRating: { [weak self] rating in
                self?.setRating(rating)
            },
            onSetPickState: { [weak self] state in
                self?.setPickState(state)
            }
        )
    }

    func rotateFocusedItem(clockwise: Bool) {
        guard let item = focusedItem else { return }
        let targets = metadataTargets(for: item)
        do {
            for target in targets {
                try imageOrientation.rotateMetadata(at: target.url, clockwise: clockwise)
                mediaTransforms[target.thumbnailCacheKey] = nil
                thumbnails.invalidate(target)
            }
            statusMessage = "Updated orientation metadata for \(item.filename)."
            saveWorkspace()
            Task { await scanSourceKeepingSelection(itemID: item.id) }
        } catch {
            statusMessage = "Could not rotate \(item.filename): \(error.localizedDescription)"
        }
    }

    func flipFocusedItem(horizontal: Bool) {
        guard let item = focusedItem else { return }
        let targets = metadataTargets(for: item)
        do {
            for target in targets {
                try imageOrientation.flipMetadata(at: target.url, horizontal: horizontal)
                mediaTransforms[target.thumbnailCacheKey] = nil
                thumbnails.invalidate(target)
            }
            statusMessage = "Updated orientation metadata for \(item.filename)."
            saveWorkspace()
            Task { await scanSourceKeepingSelection(itemID: item.id) }
        } catch {
            statusMessage = "Could not flip \(item.filename): \(error.localizedDescription)"
        }
    }

    func transform(for item: MediaItem) -> MediaTransform {
        mediaTransforms[item.thumbnailCacheKey, default: MediaTransform()]
    }

    func isProxyStackRepresentative(_ item: MediaItem) -> Bool {
        guard item.mediaType == .jpeg, let key = item.pairedAssetKey else { return false }
        return mediaItems.contains { $0.pairedAssetKey == key && $0.mediaType == .raw }
    }

    func isCollapsedProxyStackRepresentative(_ item: MediaItem) -> Bool {
        guard let key = item.pairedAssetKey else { return false }
        return isProxyStackRepresentative(item) && !expandedProxyStackKeys.contains(key)
    }

    func expandProxyStackIfNeeded(for item: MediaItem) {
        guard isCollapsedProxyStackRepresentative(item), let key = item.pairedAssetKey else { return }
        expandedProxyStackKeys.insert(key)
    }

    func displayName(for item: MediaItem, hidingProxyExtension: Bool = false) -> String {
        if hidingProxyExtension && isProxyStackRepresentative(item) {
            return item.url.deletingPathExtension().lastPathComponent
        }
        return item.filename
    }

    func isSelectedForDisplay(_ item: MediaItem) -> Bool {
        if viewMode == .grid, let key = item.pairedAssetKey, expandedProxyStackKeys.contains(key) {
            return selectedItemIDs.contains(item.id)
        }
        return !selectedItemIDs.isDisjoint(with: metadataTargetIDs(for: item))
    }

    func isFocusedForDisplay(_ item: MediaItem) -> Bool {
        guard let focusedItemID else { return false }
        if viewMode == .grid, let key = item.pairedAssetKey, expandedProxyStackKeys.contains(key) {
            return focusedItemID == item.id
        }
        return metadataTargetIDs(for: item).contains(focusedItemID)
    }

    func adjustGridScale(by delta: Double) {
        panelLayout.gridThumbnailScale = min(max(panelLayout.gridThumbnailScale + delta, 0.72), 1.6)
        saveWorkspace()
    }

    func adjustPreviewZoom(by delta: Double) {
        if viewMode == .gallery {
            setGalleryPreviewZoom(panelLayout.galleryPreviewZoom + delta, shouldSave: false)
        } else {
            panelLayout.gridThumbnailScale = min(max(panelLayout.gridThumbnailScale + delta, 0.72), 1.6)
        }
        saveWorkspace()
    }

    func resetPreviewZoom() {
        if viewMode == .gallery {
            setGalleryPreviewZoom(1.0, shouldSave: false)
        } else {
            panelLayout.gridThumbnailScale = 1.0
        }
        saveWorkspace()
    }

    func setGalleryPreviewZoom(_ zoom: Double, shouldSave: Bool = true) {
        panelLayout.galleryPreviewZoom = min(max(zoom, 1.0), 4.0)
        if shouldSave {
            scheduleWorkspaceSave()
        }
    }

    func moveSelectedItemsToTrash() {
        let items = selectedItems
        guard !items.isEmpty else {
            statusMessage = "Select files before moving them to Trash."
            return
        }

        var movedCount = 0
        var failureCount = 0
        var sidecarFailureCount = 0
        for item in items {
            do {
                try FileManager.default.trashItem(at: item.url, resultingItemURL: nil)
                movedCount += 1
            } catch {
                failureCount += 1
                continue
            }

            let sidecar = sidecarURL(for: item.url)
            guard FileManager.default.fileExists(atPath: sidecar.path) else { continue }
            do {
                try FileManager.default.trashItem(at: sidecar, resultingItemURL: nil)
            } catch {
                sidecarFailureCount += 1
            }
        }
        statusMessage = fileOperationMessage(
            successCount: movedCount,
            failureCount: failureCount,
            sidecarFailureCount: sidecarFailureCount,
            successSingular: "Moved 1 file to Trash.",
            successPlural: "Moved %d files to Trash."
        )
        Task { await scanSource() }
    }

    func duplicateSelectedItems() {
        let items = selectedItems
        guard !items.isEmpty else {
            statusMessage = "Select files before duplicating."
            return
        }

        var duplicatedCount = 0
        var failureCount = 0
        var sidecarFailureCount = 0
        for item in items {
            let destination = duplicateURL(for: item.url)
            do {
                try FileManager.default.copyItem(at: item.url, to: destination)
                duplicatedCount += 1
            } catch {
                failureCount += 1
                continue
            }

            do {
                try duplicateSidecarIfNeeded(from: item.url, to: destination)
            } catch {
                sidecarFailureCount += 1
            }
        }
        statusMessage = fileOperationMessage(
            successCount: duplicatedCount,
            failureCount: failureCount,
            sidecarFailureCount: sidecarFailureCount,
            successSingular: "Duplicated 1 file.",
            successPlural: "Duplicated %d files."
        )
        Task { await scanSource() }
    }

    func clearCopyLogs() {
        copyLogs.removeAll()
        saveWorkspace()
    }

    func clearThumbnailCache() {
        let size = thumbnails.diskCacheSize()
        thumbnails.clearAllCaches()
        statusMessage = String(
            format: L10n.tr("Cleared thumbnail cache (%@)."),
            AppFormatters.byteCount.string(fromByteCount: size)
        )
    }

    func saveCurrentWorkspaceAsNewPreset() {
        let alert = NSAlert()
        alert.messageText = L10n.tr("Save Workspace")
        alert.informativeText = L10n.tr("Name this workspace preset.")
        alert.addButton(withTitle: L10n.tr("Save"))
        alert.addButton(withTitle: L10n.tr("Cancel"))

        let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 260, height: 24))
        input.stringValue = defaultWorkspacePresetName()
        alert.accessoryView = input

        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let name = input.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }

        let preset = makeWorkspacePreset(id: UUID(), name: name)
        workspacePresets.append(preset)
        activeWorkspacePresetID = preset.id
        workspace.saveLibrary(WorkspaceLibrary(activePresetID: preset.id, presets: workspacePresets))
        statusMessage = String(format: L10n.tr("Saved workspace %@."), name)
    }

    func updateActiveWorkspacePreset() {
        guard let index = workspacePresets.firstIndex(where: { $0.id == activeWorkspacePresetID }) else { return }
        let name = workspacePresets[index].name
        workspacePresets[index] = makeWorkspacePreset(id: activeWorkspacePresetID, name: name)
        workspace.saveLibrary(WorkspaceLibrary(activePresetID: activeWorkspacePresetID, presets: workspacePresets))
        statusMessage = String(format: L10n.tr("Updated workspace %@."), name)
    }

    func applyWorkspacePreset(id: UUID) {
        guard id != activeWorkspacePresetID,
              let preset = workspacePresets.first(where: { $0.id == id }) else { return }
        applyWorkspacePreset(preset)
        activeWorkspacePresetID = id
        workspace.saveLibrary(WorkspaceLibrary(activePresetID: id, presets: workspacePresets))
        if sourceURL != nil {
            Task { await scanSource() }
        }
    }

    func deleteActiveWorkspacePreset() {
        guard workspacePresets.count > 1,
              let index = workspacePresets.firstIndex(where: { $0.id == activeWorkspacePresetID }) else { return }
        let removed = workspacePresets.remove(at: index)
        let fallback = workspacePresets[max(0, min(index, workspacePresets.count - 1))]
        applyWorkspacePreset(fallback)
        activeWorkspacePresetID = fallback.id
        workspace.saveLibrary(WorkspaceLibrary(activePresetID: fallback.id, presets: workspacePresets))
        statusMessage = String(format: L10n.tr("Deleted workspace %@."), removed.name)
        if sourceURL != nil {
            Task { await scanSource() }
        }
    }

    func setIncludeSourceSubfolders(_ include: Bool) {
        guard includeSourceSubfolders != include else { return }
        let currentItemID = focusedItemID
        includeSourceSubfolders = include
        saveWorkspace()
        Task { await scanSourceKeepingSelection(itemID: currentItemID) }
    }

    func saveWorkspace() {
        workspaceSaveTask?.cancel()
        workspaceSaveTask = nil
        persistWorkspace()
    }

    func scheduleWorkspaceSave(after nanoseconds: UInt64 = 350_000_000) {
        workspaceSaveTask?.cancel()
        workspaceSaveTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: nanoseconds)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self?.persistWorkspace()
                self?.workspaceSaveTask = nil
            }
        }
    }

    private func persistWorkspace() {
        let currentName = workspacePresets.first(where: { $0.id == activeWorkspacePresetID })?.name ?? "Default"
        let preset = makeWorkspacePreset(id: activeWorkspacePresetID, name: currentName)
        if let index = workspacePresets.firstIndex(where: { $0.id == activeWorkspacePresetID }) {
            workspacePresets[index] = preset
        } else {
            workspacePresets.append(preset)
        }
        workspace.saveLibrary(WorkspaceLibrary(activePresetID: activeWorkspacePresetID, presets: workspacePresets))
    }

    private func makeWorkspacePreset(id: UUID, name: String) -> WorkspacePreset {
        WorkspacePreset(
            id: id,
            name: name,
            panelLayout: panelLayout,
            viewMode: viewMode,
            filterState: filterState,
            sortRule: sortRule,
            copyRule: copyRule,
            copyConflictPolicy: copyConflictPolicy,
            copyContentMode: copyContentMode,
            copyVerificationMode: copyVerificationMode,
            localSourcePath: preservePaths ? sourceURL : nil,
            localSourceSelectionPath: preservePaths ? sourceSelectionURL : nil,
            localTargetPath: preservePaths ? targetURL : nil,
            localTargetSelectionPath: preservePaths ? targetSelectionURL : nil,
            mediaTransforms: mediaTransforms,
            copyLogs: Array(copyLogs.prefix(30)),
            batchRenameLogs: Array(batchRenameLogs.prefix(30)),
            preservePaths: preservePaths,
            appLanguage: appLanguage,
            includeSourceSubfolders: includeSourceSubfolders,
            cameraCardAction: cameraCardAction
        )
    }

    private func defaultWorkspacePresetName() -> String {
        let base = L10n.tr("Workspace")
        var index = workspacePresets.count + 1
        var candidate = "\(base) \(index)"
        let existing = Set(workspacePresets.map(\.name))
        while existing.contains(candidate) {
            index += 1
            candidate = "\(base) \(index)"
        }
        return candidate
    }

    var availableCameraModels: [String] {
        sortedUniqueValues(mediaItems.compactMap(\.cameraModel))
    }

    var availableLensModels: [String] {
        sortedUniqueValues(mediaItems.compactMap(\.lensModel))
    }

    private func restoreWorkspace() {
        let library = workspace.loadLibrary()
        workspacePresets = library.presets
        activeWorkspacePresetID = library.activePresetID
        let preset = library.presets.first(where: { $0.id == library.activePresetID }) ?? library.presets.first ?? .default
        activeWorkspacePresetID = preset.id
        applyWorkspacePreset(preset)
    }

    private func applyWorkspacePreset(_ preset: WorkspacePreset) {
        panelLayout = preset.panelLayout
        viewMode = preset.viewMode
        filterState = preset.filterState
        sortRule = preset.sortRule
        copyRule = preset.copyRule
        copyConflictPolicy = preset.copyConflictPolicy
        copyContentMode = preset.copyContentMode
        copyVerificationMode = preset.copyVerificationMode
        mediaTransforms = preset.mediaTransforms
        copyLogs = preset.copyLogs
        batchRenameLogs = preset.batchRenameLogs
        preservePaths = preset.preservePaths
        appLanguage = preset.appLanguage
        includeSourceSubfolders = preset.includeSourceSubfolders
        cameraCardAction = preset.cameraCardAction
        L10n.currentLanguage = appLanguage
        L10n.applySystemPanelLanguagePreference(appLanguage)
        if preset.preservePaths {
            sourceURL = preset.localSourcePath
            sourceSelectionURL = preset.localSourceSelectionPath
            targetURL = preset.localTargetPath
            targetSelectionURL = preset.localTargetSelectionPath
        } else {
            sourceURL = nil
            sourceSelectionURL = nil
            targetURL = nil
            targetSelectionURL = nil
        }
    }

    private func mutateSelected(_ update: (inout MediaItem) -> Void) {
        let targetIDs = expandedMetadataTargetIDs(for: selectedItemIDs)
        guard !targetIDs.isEmpty else { return }
        for index in mediaItems.indices where targetIDs.contains(mediaItems[index].id) {
            update(&mediaItems[index])
        }
    }

    private func writeSelectedXMP() {
        let targetIDs = expandedMetadataTargetIDs(for: selectedItemIDs)
        guard !targetIDs.isEmpty else { return }
        for index in mediaItems.indices where targetIDs.contains(mediaItems[index].id) {
            do {
                try xmp.writeSidecar(for: mediaItems[index])
                mediaItems[index].xmpStatus = .sidecarWritten
            } catch {
                mediaItems[index].xmpStatus = .conflict
                statusMessage = "Could not write XMP for \(mediaItems[index].filename): \(error.localizedDescription)"
            }
        }
    }

    private func proxyCollapsedItems(from items: [MediaItem], expandedPairKeys: Set<String> = []) -> [MediaItem] {
        var collapsed: [MediaItem] = []
        var consumedPairKeys = Set<String>()
        let membersByPairKey = Dictionary(grouping: items.filter { $0.pairedAssetKey != nil }) { item in
            item.pairedAssetKey ?? ""
        }

        for item in items {
            guard let key = item.pairedAssetKey else {
                collapsed.append(item)
                continue
            }
            if expandedPairKeys.contains(key) {
                collapsed.append(item)
                continue
            }
            guard !consumedPairKeys.contains(key) else { continue }
            consumedPairKeys.insert(key)
            let pairMembers = membersByPairKey[key] ?? []
            if let jpeg = pairMembers.first(where: { $0.mediaType == .jpeg }),
               pairMembers.contains(where: { $0.mediaType == .raw }) {
                collapsed.append(jpeg)
            } else {
                collapsed.append(item)
            }
        }

        return collapsed
    }

    private func proxyDisplayItem(matching item: MediaItem, in items: [MediaItem]) -> MediaItem? {
        guard let key = item.pairedAssetKey else {
            return items.first { $0.id == item.id }
        }
        return items.first { $0.pairedAssetKey == key } ?? items.first { $0.id == item.id }
    }

    private func scheduleMetadataLoading() {
        let candidates = metadataLoadCandidates().map { item in
            (fingerprint: metadataFingerprint(for: item), item: item)
        }
        guard !candidates.isEmpty else {
            cancelMetadataLoading(resetProgress: true)
            return
        }

        metadataTask?.cancel()
        metadataGeneration += 1
        let generation = metadataGeneration
        metadataProgress = MetadataLoadProgress(totalCount: candidates.count, isRunning: true)

        metadataTask = Task { [weak self, metadataCache] in
            try? await Task.sleep(nanoseconds: 120_000_000)
            guard !Task.isCancelled else { return }

            let metadataService = MetadataService()
            let batchSize = 16
            var completedCount = 0
            var pendingUpdates: [(fingerprint: String, item: MediaItem)] = []
            var pendingCacheUpdates: [(fingerprint: String, snapshot: MediaMetadataSnapshot)] = []
            let cachedSnapshots = await metadataCache.snapshots(for: candidates.map(\.fingerprint))

            for candidate in candidates where !Task.isCancelled {
                let loadedItem: MediaItem
                if let cachedSnapshot = cachedSnapshots[candidate.fingerprint] {
                    loadedItem = cachedSnapshot.applying(to: candidate.item)
                } else {
                    loadedItem = await Task.detached(priority: .utility) {
                        metadataService.applyMetadata(to: candidate.item)
                    }.value
                    pendingCacheUpdates.append((candidate.fingerprint, MediaMetadataSnapshot(item: loadedItem)))
                }
                completedCount += 1
                pendingUpdates.append((candidate.fingerprint, loadedItem))

                if pendingUpdates.count >= batchSize || completedCount == candidates.count {
                    let updates = pendingUpdates
                    let cacheUpdates = pendingCacheUpdates
                    pendingUpdates.removeAll()
                    pendingCacheUpdates.removeAll()
                    await MainActor.run { [weak self] in
                        guard let self, self.metadataGeneration == generation else { return }
                        self.applyLoadedMetadata(updates)
                        self.metadataProgress = MetadataLoadProgress(
                            completedCount: completedCount,
                            totalCount: candidates.count,
                            currentFilename: loadedItem.filename,
                            isRunning: true
                        )
                    }
                    await metadataCache.store(cacheUpdates)
                }
            }

            guard !Task.isCancelled else { return }
            await MainActor.run { [weak self] in
                guard let self, self.metadataGeneration == generation else { return }
                self.metadataProgress = MetadataLoadProgress(
                    completedCount: candidates.count,
                    totalCount: candidates.count,
                    isRunning: false
                )
                self.metadataTask = nil
            }
        }
    }

    private func cancelMetadataLoading(resetProgress: Bool) {
        metadataTask?.cancel()
        metadataTask = nil
        metadataGeneration += 1
        if resetProgress {
            metadataProgress = MetadataLoadProgress()
        }
    }

    private func metadataLoadCandidates() -> [MediaItem] {
        var ordered: [MediaItem] = []
        var seenFingerprints = Set<String>()

        func append(_ item: MediaItem?) {
            guard let item, item.mediaType != .video else { return }
            let fingerprint = metadataFingerprint(for: item)
            guard !loadedMetadataFingerprints.contains(fingerprint),
                  !seenFingerprints.contains(fingerprint) else { return }
            seenFingerprints.insert(fingerprint)
            ordered.append(item)
        }

        func appendTargets(for item: MediaItem?) {
            guard let item else { return }
            metadataTargets(for: item).forEach { append($0) }
        }

        appendTargets(for: focusedItem)
        selectedItemIDs.forEach { id in
            appendTargets(for: mediaItems.first { $0.id == id })
        }

        let displayItems = browserItems
        if let focusedItem, let index = displayItems.firstIndex(where: { $0.id == focusedItem.id }) {
            for offset in [0, 1, -1, 2, -2, 3, -3, 4, -4, 5, -5] {
                let candidateIndex = index + offset
                guard displayItems.indices.contains(candidateIndex) else { continue }
                appendTargets(for: displayItems[candidateIndex])
            }
        }

        displayItems.prefix(96).forEach { appendTargets(for: $0) }
        mediaItems.forEach { append($0) }
        return ordered
    }

    private func applyLoadedMetadata(_ updates: [(fingerprint: String, item: MediaItem)]) {
        for update in updates {
            loadedMetadataFingerprints.insert(update.fingerprint)
            guard let index = mediaItems.firstIndex(where: { $0.url == update.item.url }) else { continue }
            mediaItems[index].captureDate = update.item.captureDate
            mediaItems[index].cameraMake = update.item.cameraMake
            mediaItems[index].cameraModel = update.item.cameraModel
            mediaItems[index].lensModel = update.item.lensModel
            mediaItems[index].focalLength = update.item.focalLength
            mediaItems[index].aperture = update.item.aperture
            mediaItems[index].shutterSpeed = update.item.shutterSpeed
            mediaItems[index].iso = update.item.iso
            mediaItems[index].pixelWidth = update.item.pixelWidth
            mediaItems[index].pixelHeight = update.item.pixelHeight
            mediaItems[index].displayPixelWidth = update.item.displayPixelWidth
            mediaItems[index].displayPixelHeight = update.item.displayPixelHeight
            mediaItems[index].displayRotationDegrees = update.item.displayRotationDegrees
            mediaItems[index].colorSpaceName = update.item.colorSpaceName
            mediaItems[index].colorProfileName = update.item.colorProfileName
        }
    }

    private func metadataFingerprint(for item: MediaItem) -> String {
        let modified = item.modifiedDate?.timeIntervalSince1970 ?? 0
        return "\(item.url.standardizedFileURL.path)|\(item.fileSize)|\(modified)"
    }

    private func schedulePreviewPreheatForFocus() {
        guard viewMode == .gallery,
              let activeSourceURL,
              let focusedItem else {
            cancelPreviewPreheat(resetProgress: true)
            return
        }

        let candidates = previewPreheatCandidates(around: focusedItem)
        guard !candidates.isEmpty else {
            cancelPreviewPreheat(resetProgress: true)
            return
        }

        previewPreheatTask?.cancel()
        previewPreheatGeneration += 1
        let generation = previewPreheatGeneration
        let sourceRoot = activeSourceURL
        previewPreheatSummary = nil
        previewPreheatSummaryTask?.cancel()
        previewPreheatSummaryTask = nil
        previewPreheatProgress = PreviewPreheatProgress(totalCount: candidates.count, isRunning: true, startedAt: Date())

        previewPreheatTask = Task { [weak self, previewPreheater] in
            try? await Task.sleep(nanoseconds: 240_000_000)
            guard !Task.isCancelled else { return }
            await previewPreheater.preheat(items: candidates, sourceRoot: sourceRoot) { progress in
                guard let self, self.previewPreheatGeneration == generation else { return }
                self.previewPreheatProgress = progress
                if !progress.isRunning {
                    self.previewPreheatTask = nil
                    self.showPreviewPreheatSummary(for: progress)
                }
            }
        }
    }

    private func cancelPreviewPreheat(resetProgress: Bool) {
        previewPreheatTask?.cancel()
        previewPreheatTask = nil
        previewPreheatGeneration += 1
        if resetProgress {
            previewPreheatProgress = PreviewPreheatProgress()
            previewPreheatSummary = nil
            previewPreheatSummaryTask?.cancel()
            previewPreheatSummaryTask = nil
        }
    }

    private func showPreviewPreheatSummary(for progress: PreviewPreheatProgress) {
        guard progress.completedCount > 0 else { return }
        previewPreheatSummary = String(
            format: L10n.tr("Preheated previews: %d in %.1fs · %d new · %d reused · %d failed"),
            progress.completedCount,
            progress.elapsedSeconds,
            progress.createdProxyCount,
            progress.skippedProxyCount + progress.warmedCount,
            progress.failedCount
        )
        previewPreheatSummaryTask?.cancel()
        previewPreheatSummaryTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self?.previewPreheatSummary = nil
                self?.previewPreheatSummaryTask = nil
            }
        }
    }

    private func showPerformanceBaselineReport(_ result: PerformanceBaselineResult) {
        let report = performanceBaselineReport(for: result)
        let alert = NSAlert()
        alert.messageText = L10n.tr("Performance Baseline")
        alert.informativeText = report
        alert.addButton(withTitle: L10n.tr("Copy Report"))
        alert.addButton(withTitle: L10n.tr("OK"))
        if alert.runModal() == .alertFirstButtonReturn {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(report, forType: .string)
            statusMessage = L10n.tr("Performance baseline report copied.")
        }
    }

    private func showGalleryPreviewBaselineReport(_ result: GalleryPreviewBaselineResult) {
        let report = galleryPreviewBaselineReport(for: result)
        let alert = NSAlert()
        alert.messageText = L10n.tr("Gallery Preview Baseline")
        alert.informativeText = report
        alert.addButton(withTitle: L10n.tr("Copy Report"))
        alert.addButton(withTitle: L10n.tr("OK"))
        if alert.runModal() == .alertFirstButtonReturn {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(report, forType: .string)
            statusMessage = L10n.tr("Gallery preview baseline report copied.")
        }
    }

    private func performanceBaselineReport(for result: PerformanceBaselineResult) -> String {
        let counts = result.mediaCounts
        return """
        Source / 源文件夹:
        \(result.sourceURL.path)

        Scope / 范围:
        \(result.recursive ? "Including subfolders / 包含子文件夹" : "Current folder only / 仅当前文件夹")

        Files / 文件:
        Total: \(result.totalItems)
        RAW: \(counts.raw)
        RAW-only: \(result.rawOnlyCount)
        JPEG: \(counts.jpeg)
        HEIC: \(counts.heic)
        TIFF: \(counts.tiff)
        PNG: \(counts.png)
        Video: \(counts.video)
        Size: \(AppFormatters.byteCount.string(fromByteCount: result.totalBytes))

        Proxy Readiness / 代理就绪度:
        Valid RAW proxies: \(result.rawProxyValidCount)/\(result.rawProxyTotalCount)
        Missing or stale RAW proxies: \(result.rawProxyMissingCount)

        Timings / 耗时:
        Scan: \(formatSeconds(result.scanDuration))
        Metadata: \(formatSeconds(result.metadataDuration))
        XMP: \(formatSeconds(result.xmpDuration))
        Pairing: \(formatSeconds(result.pairingDuration))
        Proxy check: \(formatSeconds(result.proxyCheckDuration))
        Total: \(formatSeconds(result.totalDuration))
        """
    }

    private func galleryPreviewBaselineReport(for result: GalleryPreviewBaselineResult) -> String {
        let slowSamples = result.slowestSamples.map { sample in
            "- \(sample.filename): \(formatSeconds(sample.warmDuration)), \(sample.previewSource.displayName), \(sample.didWarm ? "OK" : "Failed")"
        }.joined(separator: "\n")

        return """
        Source / 源文件夹:
        \(result.sourceURL.path)

        Sample / 抽样:
        Images: \(result.sampledItems)
        RAW: \(result.rawItems)
        Original preview sources: \(result.originalSourceCount)
        Proxy preview sources: \(result.proxySourceCount)
        Failed warms: \(result.failedCount)

        RAW Proxy Readiness / RAW 代理就绪度:
        Valid RAW proxies: \(result.rawProxyHitCount)/\(result.rawItems)
        Missing or stale RAW proxies: \(result.rawProxyMissingCount)

        Preview Warm Timings / 预览预热耗时:
        Average: \(formatSeconds(result.averageWarmDuration))
        Total: \(formatSeconds(result.totalDuration))

        Slowest Samples / 最慢样本:
        \(slowSamples.isEmpty ? "None / 无" : slowSamples)
        """
    }

    private func formatSeconds(_ value: TimeInterval) -> String {
        String(format: "%.2fs", value)
    }

    private func previewPreheatCandidates(around item: MediaItem) -> [MediaItem] {
        let items = browserItems
        guard let currentIndex = items.firstIndex(where: { $0.id == item.id }) else { return [] }
        let offsets = [1, 2, -1, 3, 0, -2]
        var seen = Set<UUID>()
        return offsets.compactMap { offset in
            let index = currentIndex + offset
            guard items.indices.contains(index) else { return nil }
            let candidate = items[index]
            guard candidate.mediaType != .video, !seen.contains(candidate.id) else { return nil }
            seen.insert(candidate.id)
            return candidate
        }
    }

    private func quickLookPreviewItems(from items: [MediaItem]) -> [MediaItem] {
        guard selectedItemIDs.count > 1 else { return items }
        let selectedDisplayIDs = selectedItemIDs.reduce(into: Set<UUID>()) { result, id in
            if let item = items.first(where: { $0.id == id }) {
                result.insert(item.id)
            } else if let source = mediaItems.first(where: { $0.id == id }),
                      let displayItem = proxyDisplayItem(matching: source, in: items) {
                result.insert(displayItem.id)
            }
        }
        return items.filter { selectedDisplayIDs.contains($0.id) }
    }

    private func expandedMetadataTargetIDs(for ids: Set<UUID>) -> Set<UUID> {
        ids.reduce(into: Set<UUID>()) { result, id in
            guard let item = mediaItems.first(where: { $0.id == id }) else { return }
            result.formUnion(metadataTargetIDs(for: item))
        }
    }

    private func metadataTargetIDs(for item: MediaItem) -> Set<UUID> {
        Set(metadataTargets(for: item).map(\.id))
    }

    private func metadataTargets(for item: MediaItem) -> [MediaItem] {
        guard let key = item.pairedAssetKey else { return [item] }
        let targets = mediaItems.filter { candidate in
            candidate.pairedAssetKey == key && (candidate.mediaType == .raw || candidate.mediaType == .jpeg)
        }
        return targets.isEmpty ? [item] : targets
    }

    private func expandedItemsForCopy(_ baseItems: [MediaItem]) -> [MediaItem] {
        var expanded = baseItems
        let pairKeys = Set(baseItems.compactMap(\.pairedAssetKey))
        if !pairKeys.isEmpty {
            expanded.append(contentsOf: mediaItems.filter { item in
                guard let key = item.pairedAssetKey else { return false }
                return pairKeys.contains(key)
            })
        }

        var seen = Set<UUID>()
        return expanded.filter { item in
            guard !seen.contains(item.id) else { return false }
            seen.insert(item.id)
            return true
        }
    }

    private func copyItems(from baseItems: [MediaItem]) -> [MediaItem] {
        expandedItemsForCopy(baseItems).filter(copyContentMode.includes)
    }

    private func sortedUniqueValues(_ values: [String]) -> [String] {
        Array(Set(values.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }))
            .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }

    private func pruneMediaTransforms(for items: [MediaItem]) {
        guard !mediaTransforms.isEmpty else { return }
        let currentKeys = Set(items.map(\.thumbnailCacheKey))
        mediaTransforms = mediaTransforms.filter { currentKeys.contains($0.key) }
    }

    private func scanSignature(for sourceURL: URL) -> String {
        "\(sourceURL.standardizedFileURL.path)|recursive:\(includeSourceSubfolders)"
    }

    private func chooseFolder(titleKey: String, completion: @escaping (URL) -> Void) {
        let panel = NSOpenPanel()
        panel.title = L10n.tr(titleKey)
        panel.prompt = L10n.tr("Choose")
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            completion(url)
        }
    }

    private func defaultNewFolderName(in parentURL: URL) -> String {
        let base = "New Folder"
        var candidate = base
        var index = 2
        while FileManager.default.fileExists(atPath: parentURL.appendingPathComponent(candidate, isDirectory: true).path) {
            candidate = "\(base) \(index)"
            index += 1
        }
        return candidate
    }

    private func beginCopyLog(items: [MediaItem], destinationURL: URL) -> UUID {
        let id = UUID()
        let record = CopyLogRecord(
            id: id,
            startedAt: Date(),
            finishedAt: nil,
            sourcePath: activeSourceURL?.path,
            destinationPath: destinationURL.path,
            rule: copyRule,
            totalItems: items.count,
            totalBytes: items.reduce(Int64(0)) { $0 + $1.fileSize },
            entries: []
        )
        copyLogs.insert(record, at: 0)
        copyLogs = Array(copyLogs.prefix(30))
        saveWorkspace()
        return id
    }

    private func appendCopyLogEntry(logID: UUID, item: MediaItem, status: CopyStatus, message: String) {
        guard let index = copyLogs.firstIndex(where: { $0.id == logID }) else { return }
        let entry = CopyLogEntry(
            id: UUID(),
            timestamp: Date(),
            filename: item.filename,
            status: status,
            message: message
        )
        copyLogs[index].entries.insert(entry, at: 0)
        scheduleWorkspaceSave()
    }

    private func finishCopyLog(logID: UUID, message: String) {
        guard let index = copyLogs.firstIndex(where: { $0.id == logID }),
              copyLogs[index].finishedAt == nil else { return }
        copyLogs[index].finishedAt = Date()
        let summary = copyLogSummary(entries: copyLogs[index].entries, fallbackMessage: message)
        let entry = CopyLogEntry(
            id: UUID(),
            timestamp: Date(),
            filename: "Copy",
            status: summary.status,
            message: summary.message
        )
        copyLogs[index].entries.insert(entry, at: 0)
        saveWorkspace()
    }

    private func appendBatchRenameLog(plan: BatchRenamePlan, renamedMediaCount: Int) {
        let entries = plan.entries
            .filter { !$0.isNoOp }
            .map {
                BatchRenameLogEntry(
                    id: UUID(),
                    originalName: $0.sourceURL.lastPathComponent,
                    newName: $0.destinationURL.lastPathComponent,
                    folderPath: $0.sourceURL.deletingLastPathComponent().path
                )
            }
        guard !entries.isEmpty else { return }

        let record = BatchRenameLogRecord(
            id: UUID(),
            createdAt: Date(),
            sourcePath: activeSourceURL?.path,
            totalItems: renamedMediaCount,
            entries: entries
        )
        batchRenameLogs.insert(record, at: 0)
        batchRenameLogs = Array(batchRenameLogs.prefix(30))
        saveWorkspace()
    }

    private func duplicateURL(for url: URL) -> URL {
        let folder = url.deletingLastPathComponent()
        let baseName = url.deletingPathExtension().lastPathComponent
        let fileExtension = url.pathExtension
        var index = 2
        var candidate = folder.appendingPathComponent("\(baseName) copy").appendingPathExtension(fileExtension)
        while mediaOrSidecarExists(for: candidate) {
            candidate = folder.appendingPathComponent("\(baseName) copy \(index)").appendingPathExtension(fileExtension)
            index += 1
        }
        return candidate
    }

    private func sidecarURL(for mediaURL: URL) -> URL {
        mediaURL.deletingPathExtension().appendingPathExtension("xmp")
    }

    private func mediaOrSidecarExists(for mediaURL: URL) -> Bool {
        FileManager.default.fileExists(atPath: mediaURL.path) || FileManager.default.fileExists(atPath: sidecarURL(for: mediaURL).path)
    }

    private func duplicateSidecarIfNeeded(from sourceMediaURL: URL, to destinationMediaURL: URL) throws {
        let sourceSidecar = sidecarURL(for: sourceMediaURL)
        guard FileManager.default.fileExists(atPath: sourceSidecar.path) else { return }
        try FileManager.default.copyItem(at: sourceSidecar, to: sidecarURL(for: destinationMediaURL))
    }

    private func fileOperationMessage(
        successCount: Int,
        failureCount: Int,
        sidecarFailureCount: Int,
        successSingular: String,
        successPlural: String
    ) -> String {
        var message = successCount == 1 ? successSingular : String(format: successPlural, successCount)
        if failureCount > 0 {
            message += " \(failureCount) failed."
        }
        if sidecarFailureCount > 0 {
            message += " \(sidecarFailureCount) sidecars failed."
        }
        return message
    }

    private func copyLogSummary(entries: [CopyLogEntry], fallbackMessage: String) -> (status: CopyStatus, message: String) {
        let verified = entries.filter { $0.status == .verified }.count
        let skipped = entries.filter { $0.status == .skipped }.count
        let failed = entries.filter { $0.status == .failed }.count
        let cancelled = entries.filter { $0.status == .cancelled }.count
        guard verified + skipped + failed + cancelled > 0 else {
            return (.verified, fallbackMessage)
        }

        let status: CopyStatus
        if cancelled > 0 {
            status = .cancelled
        } else if failed > 0 {
            status = .failed
        } else {
            status = .verified
        }
        return (
            status,
            "Finished: \(verified) verified, \(skipped) skipped, \(failed) failed, \(cancelled) cancelled."
        )
    }
}
