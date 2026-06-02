import Foundation
import CoreGraphics

struct WorkspacePreset: Identifiable, Codable {
    let id: UUID
    var name: String
    var panelLayout: PanelLayout
    var viewMode: ViewMode
    var filterState: FilterState
    var sortRule: SortRule
    var copyRule: CopyOrganizationRule
    var copyConflictPolicy: CopyConflictPolicy
    var copyContentMode: CopyContentMode
    var copyVerificationMode: CopyVerificationMode
    var localSourcePath: URL?
    var localSourceSelectionPath: URL?
    var localTargetPath: URL?
    var localTargetSelectionPath: URL?
    var mediaTransforms: [String: MediaTransform]
    var copyLogs: [CopyLogRecord]
    var batchRenameLogs: [BatchRenameLogRecord]
    var preservePaths: Bool
    var appLanguage: AppLanguage
    var includeSourceSubfolders: Bool
    var cameraCardAction: CameraCardAction

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case panelLayout
        case viewMode
        case filterState
        case sortRule
        case copyRule
        case copyConflictPolicy
        case copyContentMode
        case copyVerificationMode
        case localSourcePath
        case localSourceSelectionPath
        case localTargetPath
        case localTargetSelectionPath
        case mediaTransforms
        case copyLogs
        case batchRenameLogs
        case preservePaths
        case appLanguage
        case includeSourceSubfolders
        case cameraCardAction
    }

    init(
        id: UUID,
        name: String,
        panelLayout: PanelLayout,
        viewMode: ViewMode,
        filterState: FilterState,
        sortRule: SortRule,
        copyRule: CopyOrganizationRule,
        copyConflictPolicy: CopyConflictPolicy = .autoRename,
        copyContentMode: CopyContentMode = .allSupported,
        copyVerificationMode: CopyVerificationMode = .sizeOnly,
        localSourcePath: URL?,
        localSourceSelectionPath: URL? = nil,
        localTargetPath: URL?,
        localTargetSelectionPath: URL? = nil,
        mediaTransforms: [String: MediaTransform] = [:],
        copyLogs: [CopyLogRecord] = [],
        batchRenameLogs: [BatchRenameLogRecord] = [],
        preservePaths: Bool,
        appLanguage: AppLanguage = .system,
        includeSourceSubfolders: Bool = false,
        cameraCardAction: CameraCardAction = .notify
    ) {
        self.id = id
        self.name = name
        self.panelLayout = panelLayout
        self.viewMode = viewMode
        self.filterState = filterState
        self.sortRule = sortRule
        self.copyRule = copyRule
        self.copyConflictPolicy = copyConflictPolicy
        self.copyContentMode = copyContentMode
        self.copyVerificationMode = copyVerificationMode
        self.localSourcePath = localSourcePath
        self.localSourceSelectionPath = localSourceSelectionPath
        self.localTargetPath = localTargetPath
        self.localTargetSelectionPath = localTargetSelectionPath
        self.mediaTransforms = mediaTransforms
        self.copyLogs = copyLogs
        self.batchRenameLogs = batchRenameLogs
        self.preservePaths = preservePaths
        self.appLanguage = appLanguage
        self.includeSourceSubfolders = includeSourceSubfolders
        self.cameraCardAction = cameraCardAction
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        panelLayout = try container.decode(PanelLayout.self, forKey: .panelLayout)
        viewMode = try container.decode(ViewMode.self, forKey: .viewMode)
        filterState = try container.decode(FilterState.self, forKey: .filterState)
        sortRule = try container.decodeIfPresent(SortRule.self, forKey: .sortRule) ?? .default
        copyRule = try container.decodeIfPresent(CopyOrganizationRule.self, forKey: .copyRule) ?? .captureDate
        copyConflictPolicy = try container.decodeIfPresent(CopyConflictPolicy.self, forKey: .copyConflictPolicy) ?? .autoRename
        copyContentMode = try container.decodeIfPresent(CopyContentMode.self, forKey: .copyContentMode) ?? .allSupported
        copyVerificationMode = try container.decodeIfPresent(CopyVerificationMode.self, forKey: .copyVerificationMode) ?? .sizeOnly
        localSourcePath = try container.decodeIfPresent(URL.self, forKey: .localSourcePath)
        localSourceSelectionPath = try container.decodeIfPresent(URL.self, forKey: .localSourceSelectionPath)
        localTargetPath = try container.decodeIfPresent(URL.self, forKey: .localTargetPath)
        localTargetSelectionPath = try container.decodeIfPresent(URL.self, forKey: .localTargetSelectionPath)
        mediaTransforms = try container.decodeIfPresent([String: MediaTransform].self, forKey: .mediaTransforms) ?? [:]
        copyLogs = try container.decodeIfPresent([CopyLogRecord].self, forKey: .copyLogs) ?? []
        batchRenameLogs = try container.decodeIfPresent([BatchRenameLogRecord].self, forKey: .batchRenameLogs) ?? []
        preservePaths = try container.decode(Bool.self, forKey: .preservePaths)
        appLanguage = try container.decodeIfPresent(AppLanguage.self, forKey: .appLanguage) ?? .system
        includeSourceSubfolders = try container.decodeIfPresent(Bool.self, forKey: .includeSourceSubfolders) ?? false
        cameraCardAction = try container.decodeIfPresent(CameraCardAction.self, forKey: .cameraCardAction) ?? .notify
    }

    static let `default` = WorkspacePreset(
        id: UUID(),
        name: "Default",
        panelLayout: PanelLayout(),
        viewMode: .grid,
        filterState: FilterState(),
        sortRule: .default,
        copyRule: .captureDate,
        copyConflictPolicy: .autoRename,
        copyContentMode: .allSupported,
        copyVerificationMode: .sizeOnly,
        localSourcePath: nil,
        localSourceSelectionPath: nil,
        localTargetPath: nil,
        localTargetSelectionPath: nil,
        mediaTransforms: [:],
        copyLogs: [],
        batchRenameLogs: [],
        preservePaths: true,
        appLanguage: .system,
        includeSourceSubfolders: false,
        cameraCardAction: .notify
    )
}

struct WorkspaceLibrary: Codable {
    var activePresetID: UUID
    var presets: [WorkspacePreset]

    static let `default` = WorkspaceLibrary(activePresetID: WorkspacePreset.default.id, presets: [.default])
}

enum CameraCardAction: String, Codable, CaseIterable, Identifiable {
    case off
    case notify
    case selectDCIM
    case selectAndScan

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .off: L10n.tr("Off")
        case .notify: L10n.tr("Notify Only")
        case .selectDCIM: L10n.tr("Select DCIM")
        case .selectAndScan: L10n.tr("Select DCIM and Scan")
        }
    }
}

enum HistogramPlacement: String, Codable, CaseIterable, Identifiable {
    case hidden
    case floating
    case inspector

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .hidden: L10n.tr("Hidden")
        case .floating: L10n.tr("Floating")
        case .inspector: L10n.tr("Inspector")
        }
    }
}

enum HistogramDisplayMode: String, Codable, CaseIterable, Identifiable {
    case rgbAndLuminance
    case rgb
    case luminance
    case red
    case green
    case blue

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .rgbAndLuminance: L10n.tr("RGB + Luminance")
        case .rgb: L10n.tr("RGB Only")
        case .luminance: L10n.tr("Luminance Only")
        case .red: L10n.tr("Red Channel")
        case .green: L10n.tr("Green Channel")
        case .blue: L10n.tr("Blue Channel")
        }
    }
}

enum HistogramCorner: String, Codable, CaseIterable {
    case topLeft
    case topRight
    case bottomLeft
    case bottomRight
}

enum CompositionOverlay: String, Codable, CaseIterable, Identifiable, Hashable {
    case thirds
    case center
    case diagonals
    case goldenRatio

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .thirds: L10n.tr("Rule of Thirds")
        case .center: L10n.tr("Center Lines")
        case .diagonals: L10n.tr("Diagonals")
        case .goldenRatio: L10n.tr("Golden Ratio")
        }
    }
}

enum CompositionOverlayColor: String, Codable, CaseIterable, Identifiable, Hashable {
    case gray
    case white
    case black
    case accent

    var id: String { rawValue }

    static let visibleCases: [CompositionOverlayColor] = [.gray, .white, .black]

    var displayName: String {
        switch self {
        case .gray: L10n.tr("Gray")
        case .white: L10n.tr("White")
        case .black: L10n.tr("Black")
        case .accent: L10n.tr("Accent")
        }
    }
}

enum CropGuideRatio: String, Codable, CaseIterable, Identifiable, Hashable {
    case hidden
    case original
    case oneToOne
    case fourThree
    case threeTwo
    case sixteenNine
    case fiveFour
    case nineSixteen

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .hidden: L10n.tr("Hidden")
        case .original: L10n.tr("Original")
        case .oneToOne: "1:1"
        case .fourThree: "4:3"
        case .threeTwo: "3:2"
        case .sixteenNine: "16:9"
        case .fiveFour: "5:4"
        case .nineSixteen: "9:16"
        }
    }

    func aspectRatio(for item: MediaItem, orientation: CropGuideOrientation = .automatic) -> CGFloat? {
        switch self {
        case .hidden:
            return nil
        case .original:
            return item.displayAspectRatio
        case .oneToOne:
            return 1
        case .fourThree:
            return orientedAspect(width: 4, height: 3, for: item, orientation: orientation)
        case .threeTwo:
            return orientedAspect(width: 3, height: 2, for: item, orientation: orientation)
        case .sixteenNine:
            return orientedAspect(width: 16, height: 9, for: item, orientation: orientation)
        case .fiveFour:
            return orientedAspect(width: 5, height: 4, for: item, orientation: orientation)
        case .nineSixteen:
            return orientedAspect(width: 9, height: 16, for: item, orientation: orientation)
        }
    }

    private func orientedAspect(width: CGFloat, height: CGFloat, for item: MediaItem, orientation: CropGuideOrientation) -> CGFloat {
        let base = width / height
        switch orientation {
        case .automatic:
            break
        case .landscape:
            return max(base, 1 / base)
        case .portrait:
            return min(base, 1 / base)
        }
        let isPortrait = (item.displayAspectRatio ?? base) < 1
        if isPortrait, base > 1 {
            return 1 / base
        }
        if !isPortrait, base < 1 {
            return 1 / base
        }
        return base
    }
}

enum CropGuideOrientation: String, Codable, CaseIterable, Identifiable, Hashable {
    case automatic
    case landscape
    case portrait

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .automatic: L10n.tr("Automatic")
        case .landscape: L10n.tr("Landscape")
        case .portrait: L10n.tr("Portrait")
        }
    }
}

enum CropGuideStyle: String, Codable, CaseIterable, Identifiable, Hashable {
    case mask
    case frame

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .mask: L10n.tr("Mask")
        case .frame: L10n.tr("Frame")
        }
    }
}

struct CustomCropGuideRatio: Identifiable, Codable, Hashable {
    static let maximumSavedCount = 10

    var id: UUID
    var name: String
    var width: Double
    var height: Double

    init(id: UUID = UUID(), name: String, width: Double, height: Double) {
        self.id = id
        self.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        self.width = max(0.1, width)
        self.height = max(0.1, height)
    }

    var displayName: String {
        if name.isEmpty {
            return "\(formatted(width)):\(formatted(height))"
        }
        return "\(name) (\(formatted(width)):\(formatted(height)))"
    }

    func aspectRatio(for item: MediaItem, orientation: CropGuideOrientation) -> CGFloat {
        let base = CGFloat(width / height)
        switch orientation {
        case .automatic:
            let isPortrait = (item.displayAspectRatio ?? base) < 1
            if isPortrait, base > 1 {
                return 1 / base
            }
            if !isPortrait, base < 1 {
                return 1 / base
            }
            return base
        case .landscape:
            return max(base, 1 / base)
        case .portrait:
            return min(base, 1 / base)
        }
    }

    private func formatted(_ value: Double) -> String {
        let rounded = value.rounded()
        if abs(value - rounded) < 0.0001 {
            return String(Int(rounded))
        }
        return String(format: "%.2f", value)
    }
}

struct PanelLayout: Codable, Hashable {
    static let minimumSidebarWidth: Double = 340
    static let defaultSidebarWidth: Double = minimumSidebarWidth * 1.2
    static let maximumSidebarWidth: Double = 560

    var sidebarWidth: Double = defaultSidebarWidth
    var previewWidth: Double = 260
    var galleryStripHeight: Double = 84
    var isFilmstripCollapsed: Bool = false
    var gridThumbnailScale: Double = 1.0
    var galleryPreviewZoom: Double = 1.0
    var sourceSectionExpanded: Bool?
    var targetSectionExpanded: Bool?
    var filtersSectionExpanded: Bool?
    var folderBrowserScale: FolderBrowserScale = .small
    var sourceFolderBrowserHeight: Double?
    var targetFolderBrowserHeight: Double?
    var histogramPlacement: HistogramPlacement = .floating
    var histogramFloatingOffsetX: Double = 0
    var histogramFloatingOffsetY: Double = 0
    var histogramFloatingWidth: Double = 230
    var histogramFloatingHeight: Double = 112
    var histogramFloatingAnchor: HistogramCorner? = .topRight
    var histogramDisplayMode: HistogramDisplayMode = .rgbAndLuminance
    var waveformPlacement: HistogramPlacement = .hidden
    var waveformFloatingOffsetX: Double = 0
    var waveformFloatingOffsetY: Double = 0
    var waveformFloatingWidth: Double = 260
    var waveformFloatingHeight: Double = 128
    var waveformFloatingAnchor: HistogramCorner? = .topLeft
    var waveformDirection: WaveformDirection = .horizontalX
    var waveformChannelMode: WaveformChannelMode = .luminance
    var compositionOverlays: Set<CompositionOverlay> = []
    var compositionOverlayColor: CompositionOverlayColor = .gray
    var compositionOverlayOpacity: Double = 0.46
    var compositionGuidesFollowCrop: Bool = false
    var cropGuideRatio: CropGuideRatio = .hidden
    var cropGuideStyle: CropGuideStyle = .mask
    var cropGuideOrientation: CropGuideOrientation = .automatic
    var customCropGuideRatios: [CustomCropGuideRatio] = []
    var activeCustomCropGuideRatioID: UUID?
    var appAppearance: AppAppearanceMode = .system
    var previewBackground: PreviewBackgroundTone = .system
    var reviewMatteSize: ReviewMatteSize = .none

    enum CodingKeys: String, CodingKey {
        case sidebarWidth
        case previewWidth
        case galleryStripHeight
        case isFilmstripCollapsed
        case gridThumbnailScale
        case galleryPreviewZoom
        case sourceSectionExpanded
        case targetSectionExpanded
        case filtersSectionExpanded
        case folderBrowserScale
        case sourceFolderBrowserHeight
        case targetFolderBrowserHeight
        case histogramPlacement
        case histogramFloatingOffsetX
        case histogramFloatingOffsetY
        case histogramFloatingWidth
        case histogramFloatingHeight
        case histogramFloatingAnchor
        case histogramDisplayMode
        case waveformPlacement
        case waveformFloatingOffsetX
        case waveformFloatingOffsetY
        case waveformFloatingWidth
        case waveformFloatingHeight
        case waveformFloatingAnchor
        case waveformDirection
        case waveformChannelMode
        case compositionOverlays
        case compositionOverlayColor
        case compositionOverlayOpacity
        case compositionGuidesFollowCrop
        case cropGuideRatio
        case cropGuideStyle
        case cropGuideOrientation
        case customCropGuideRatios
        case activeCustomCropGuideRatioID
        case appAppearance
        case previewBackground
        case reviewMatteSize
    }

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let decodedSidebarWidth = try container.decodeIfPresent(Double.self, forKey: .sidebarWidth) ?? Self.defaultSidebarWidth
        sidebarWidth = min(max(decodedSidebarWidth, Self.minimumSidebarWidth), Self.maximumSidebarWidth)
        previewWidth = try container.decodeIfPresent(Double.self, forKey: .previewWidth) ?? 260
        galleryStripHeight = try container.decodeIfPresent(Double.self, forKey: .galleryStripHeight) ?? 84
        isFilmstripCollapsed = try container.decodeIfPresent(Bool.self, forKey: .isFilmstripCollapsed) ?? false
        gridThumbnailScale = try container.decodeIfPresent(Double.self, forKey: .gridThumbnailScale) ?? 1.0
        let decodedGalleryPreviewZoom = try container.decodeIfPresent(Double.self, forKey: .galleryPreviewZoom) ?? 1.0
        galleryPreviewZoom = min(max(decodedGalleryPreviewZoom, 1.0), 4.0)
        sourceSectionExpanded = try container.decodeIfPresent(Bool.self, forKey: .sourceSectionExpanded)
        targetSectionExpanded = try container.decodeIfPresent(Bool.self, forKey: .targetSectionExpanded)
        filtersSectionExpanded = try container.decodeIfPresent(Bool.self, forKey: .filtersSectionExpanded)
        folderBrowserScale = try container.decodeIfPresent(FolderBrowserScale.self, forKey: .folderBrowserScale) ?? .small
        sourceFolderBrowserHeight = try container.decodeIfPresent(Double.self, forKey: .sourceFolderBrowserHeight)
        targetFolderBrowserHeight = try container.decodeIfPresent(Double.self, forKey: .targetFolderBrowserHeight)
        histogramPlacement = try container.decodeIfPresent(HistogramPlacement.self, forKey: .histogramPlacement) ?? .floating
        histogramFloatingOffsetX = try container.decodeIfPresent(Double.self, forKey: .histogramFloatingOffsetX) ?? 0
        histogramFloatingOffsetY = try container.decodeIfPresent(Double.self, forKey: .histogramFloatingOffsetY) ?? 0
        histogramFloatingWidth = try container.decodeIfPresent(Double.self, forKey: .histogramFloatingWidth) ?? 230
        histogramFloatingHeight = try container.decodeIfPresent(Double.self, forKey: .histogramFloatingHeight) ?? 112
        histogramFloatingAnchor = try container.decodeIfPresent(HistogramCorner.self, forKey: .histogramFloatingAnchor) ?? .topRight
        histogramDisplayMode = try container.decodeIfPresent(HistogramDisplayMode.self, forKey: .histogramDisplayMode) ?? .rgbAndLuminance
        waveformPlacement = try container.decodeIfPresent(HistogramPlacement.self, forKey: .waveformPlacement) ?? .hidden
        waveformFloatingOffsetX = try container.decodeIfPresent(Double.self, forKey: .waveformFloatingOffsetX) ?? 0
        waveformFloatingOffsetY = try container.decodeIfPresent(Double.self, forKey: .waveformFloatingOffsetY) ?? 0
        waveformFloatingWidth = try container.decodeIfPresent(Double.self, forKey: .waveformFloatingWidth) ?? 260
        waveformFloatingHeight = try container.decodeIfPresent(Double.self, forKey: .waveformFloatingHeight) ?? 128
        waveformFloatingAnchor = try container.decodeIfPresent(HistogramCorner.self, forKey: .waveformFloatingAnchor) ?? .topLeft
        waveformDirection = try container.decodeIfPresent(WaveformDirection.self, forKey: .waveformDirection) ?? .horizontalX
        waveformChannelMode = try container.decodeIfPresent(WaveformChannelMode.self, forKey: .waveformChannelMode) ?? .luminance
        compositionOverlays = try container.decodeIfPresent(Set<CompositionOverlay>.self, forKey: .compositionOverlays) ?? []
        compositionOverlayColor = try container.decodeIfPresent(CompositionOverlayColor.self, forKey: .compositionOverlayColor) ?? .gray
        let decodedOverlayOpacity = try container.decodeIfPresent(Double.self, forKey: .compositionOverlayOpacity) ?? 0.46
        compositionOverlayOpacity = min(max(decodedOverlayOpacity, 0.2), 1.0)
        compositionGuidesFollowCrop = try container.decodeIfPresent(Bool.self, forKey: .compositionGuidesFollowCrop) ?? false
        cropGuideRatio = try container.decodeIfPresent(CropGuideRatio.self, forKey: .cropGuideRatio) ?? .hidden
        cropGuideStyle = try container.decodeIfPresent(CropGuideStyle.self, forKey: .cropGuideStyle) ?? .mask
        cropGuideOrientation = try container.decodeIfPresent(CropGuideOrientation.self, forKey: .cropGuideOrientation) ?? .automatic
        let decodedCustomRatios = try container.decodeIfPresent([CustomCropGuideRatio].self, forKey: .customCropGuideRatios) ?? []
        customCropGuideRatios = Array(decodedCustomRatios.prefix(CustomCropGuideRatio.maximumSavedCount))
        let decodedActiveCustomRatioID = try container.decodeIfPresent(UUID.self, forKey: .activeCustomCropGuideRatioID)
        activeCustomCropGuideRatioID = customCropGuideRatios.contains(where: { $0.id == decodedActiveCustomRatioID }) ? decodedActiveCustomRatioID : nil
        appAppearance = try container.decodeIfPresent(AppAppearanceMode.self, forKey: .appAppearance) ?? .system
        previewBackground = try container.decodeIfPresent(PreviewBackgroundTone.self, forKey: .previewBackground) ?? .system
        reviewMatteSize = try container.decodeIfPresent(ReviewMatteSize.self, forKey: .reviewMatteSize) ?? .none
    }

    func activeCropGuideAspectRatio(for item: MediaItem) -> CGFloat? {
        if let activeCustomCropGuideRatioID,
           let customRatio = customCropGuideRatios.first(where: { $0.id == activeCustomCropGuideRatioID }) {
            return customRatio.aspectRatio(for: item, orientation: cropGuideOrientation)
        }
        return cropGuideRatio.aspectRatio(for: item, orientation: cropGuideOrientation)
    }
}

enum AppAppearanceMode: String, Codable, CaseIterable, Identifiable, Hashable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system: L10n.tr("Follow System")
        case .light: L10n.tr("Light")
        case .dark: L10n.tr("Dark")
        }
    }
}

enum PreviewBackgroundTone: String, Codable, CaseIterable, Identifiable, Hashable {
    case system
    case black
    case white
    case darkGray
    case middleGray
    case lightGray

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system: L10n.tr("System")
        case .black: L10n.tr("Black")
        case .white: L10n.tr("White")
        case .darkGray: L10n.tr("Dark Gray")
        case .middleGray: L10n.tr("Middle Gray")
        case .lightGray: L10n.tr("Light Gray")
        }
    }
}

enum ReviewMatteSize: String, Codable, CaseIterable, Identifiable, Hashable {
    case none
    case small
    case medium
    case large

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .none: L10n.tr("None")
        case .small: L10n.tr("Small")
        case .medium: L10n.tr("Medium")
        case .large: L10n.tr("Large")
        }
    }

    var padding: CGFloat {
        switch self {
        case .none: 0
        case .small: 16
        case .medium: 36
        case .large: 64
        }
    }
}

enum FolderBrowserScale: String, Codable, CaseIterable, Identifiable {
    case small
    case large

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .small: L10n.tr("Small")
        case .large: L10n.tr("Large")
        }
    }
}

enum ViewMode: String, Codable, CaseIterable, Identifiable {
    case grid, list, gallery

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .grid: L10n.tr("Grid")
        case .list: L10n.tr("List")
        case .gallery: L10n.tr("Gallery")
        }
    }

    var systemImage: String {
        switch self {
        case .grid: "square.grid.3x3"
        case .list: "list.bullet.rectangle"
        case .gallery: "rectangle.bottomthird.inset.filled"
        }
    }
}

struct FilterState: Codable, Hashable {
    var minimumRating: Int = 0
    var colorLabel: ColorLabel?
    var pickState: PickState?
    var startDate: Date?
    var endDate: Date?
    var cameraModel: String?
    var lensModel: String?
    var searchText: String = ""

    func includes(_ item: MediaItem) -> Bool {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !query.isEmpty, !item.filename.localizedCaseInsensitiveContains(query) { return false }
        if item.rating < minimumRating { return false }
        if let colorLabel, item.colorLabel != colorLabel { return false }
        if let pickState, item.pickState != pickState { return false }
        if let startDate {
            guard let captureDate = item.captureDate, captureDate >= startDate else { return false }
        }
        if let endDate {
            guard let captureDate = item.captureDate, captureDate <= endDate else { return false }
        }
        if let cameraModel, item.cameraModel != cameraModel { return false }
        if let lensModel, item.lensModel != lensModel { return false }
        return true
    }
}

struct SortRule: Codable, Hashable, Identifiable {
    var field: SortField
    var direction: SortDirection

    var id: String { "\(field.rawValue)-\(direction.rawValue)" }

    static let `default` = SortRule(field: .addedDate, direction: .descending)

    init(field: SortField, direction: SortDirection) {
        self.field = field
        self.direction = direction
    }

    init(from decoder: Decoder) throws {
        if let legacyValue = try? decoder.singleValueContainer().decode(String.self) {
            self = Self.legacyRule(for: legacyValue)
            return
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)
        field = try container.decodeIfPresent(SortField.self, forKey: .field) ?? Self.default.field
        direction = try container.decodeIfPresent(SortDirection.self, forKey: .direction) ?? Self.default.direction
    }

    private static func legacyRule(for value: String) -> SortRule {
        switch value {
        case "filenameAscending":
            SortRule(field: .name, direction: .ascending)
        case "fileSizeDescending":
            SortRule(field: .size, direction: .descending)
        case "captureDateDescending":
            SortRule(field: .addedDate, direction: .descending)
        default:
            .default
        }
    }
}

enum SortField: String, Codable, CaseIterable, Identifiable {
    case name
    case kind
    case addedDate
    case modifiedDate
    case createdDate
    case lastOpenedDate
    case size

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .name: L10n.tr("Name")
        case .kind: L10n.tr("Kind")
        case .addedDate: L10n.tr("Date Added")
        case .modifiedDate: L10n.tr("Date Modified")
        case .createdDate: L10n.tr("Date Created")
        case .lastOpenedDate: L10n.tr("Last Opened")
        case .size: L10n.tr("Size")
        }
    }
}

enum SortDirection: String, Codable {
    case ascending
    case descending

    var toggled: SortDirection {
        switch self {
        case .ascending: .descending
        case .descending: .ascending
        }
    }

    var systemImage: String {
        switch self {
        case .ascending: "arrow.up"
        case .descending: "arrow.down"
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .ascending: L10n.tr("Ascending")
        case .descending: L10n.tr("Descending")
        }
    }
}

enum CopyOrganizationRule: String, Codable, CaseIterable, Identifiable {
    case captureDate
    case preserveStructure
    case cameraModel
    case rating

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .captureDate: L10n.tr("Capture Date")
        case .preserveStructure: L10n.tr("Preserve Structure")
        case .cameraModel: L10n.tr("Camera Model")
        case .rating: L10n.tr("Rating")
        }
    }
}

enum CopyConflictPolicy: String, Codable, CaseIterable, Identifiable {
    case autoRename
    case skipExisting
    case overwrite

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .autoRename: L10n.tr("Auto Rename")
        case .skipExisting: L10n.tr("Skip Existing")
        case .overwrite: L10n.tr("Overwrite")
        }
    }
}

enum CopyContentMode: String, Codable, CaseIterable, Identifiable {
    case allSupported
    case rawOnly

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .allSupported: L10n.tr("All Supported Files")
        case .rawOnly: L10n.tr("RAW Files Only")
        }
    }

    func includes(_ item: MediaItem) -> Bool {
        switch self {
        case .allSupported:
            return true
        case .rawOnly:
            return item.mediaType == .raw
        }
    }
}

enum CopyVerificationMode: String, Codable, CaseIterable, Identifiable {
    case sizeOnly
    case sha256

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .sizeOnly: L10n.tr("Size Only")
        case .sha256: L10n.tr("SHA-256 Hash")
        }
    }

    var completionDescription: String {
        switch self {
        case .sizeOnly:
            L10n.tr("count and size")
        case .sha256:
            L10n.tr("count, size, and SHA-256")
        }
    }
}

struct CopyProgress: Equatable {
    var currentItem: String = ""
    var completedCount: Int = 0
    var totalCount: Int = 0
    var completedBytes: Int64 = 0
    var totalBytes: Int64 = 0
    var isRunning = false
    var isPaused = false
    var isCancelled = false
    var message = "Idle"

    var fraction: Double {
        guard totalBytes > 0 else { return totalCount == 0 ? 0 : Double(completedCount) / Double(totalCount) }
        return min(1, Double(completedBytes) / Double(totalBytes))
    }
}
