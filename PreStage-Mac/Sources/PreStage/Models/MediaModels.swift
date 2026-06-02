import Foundation
import CoreGraphics

struct MediaItem: Identifiable, Codable, Hashable {
    let id: UUID
    let url: URL
    let filename: String
    let fileExtension: String
    let mediaType: MediaType
    let fileSize: Int64
    var captureDate: Date?
    var addedDate: Date?
    var createdDate: Date?
    var modifiedDate: Date?
    var lastOpenedDate: Date?
    var cameraMake: String?
    var cameraModel: String?
    var lensModel: String?
    var focalLength: Double?
    var aperture: Double?
    var shutterSpeed: String?
    var iso: Int?
    var pixelWidth: Int?
    var pixelHeight: Int?
    var displayPixelWidth: Int?
    var displayPixelHeight: Int?
    var displayRotationDegrees: Double
    var colorSpaceName: String?
    var colorProfileName: String?
    var rating: Int
    var colorLabel: ColorLabel?
    var pickState: PickState
    var copyStatus: CopyStatus
    var xmpStatus: XMPStatus
    var thumbnailCacheKey: String
    var pairedAssetKey: String?
    var perceptualHash: String?
    var similarityGroupID: UUID?

    init(
        url: URL,
        mediaType: MediaType,
        fileSize: Int64,
        captureDate: Date?,
        addedDate: Date? = nil,
        createdDate: Date?,
        modifiedDate: Date?,
        lastOpenedDate: Date? = nil
    ) {
        self.id = UUID()
        self.url = url
        self.filename = url.lastPathComponent
        self.fileExtension = url.pathExtension.lowercased()
        self.mediaType = mediaType
        self.fileSize = fileSize
        self.captureDate = captureDate
        self.addedDate = addedDate
        self.createdDate = createdDate
        self.modifiedDate = modifiedDate
        self.lastOpenedDate = lastOpenedDate
        self.displayPixelWidth = nil
        self.displayPixelHeight = nil
        self.displayRotationDegrees = 0
        self.rating = 0
        self.colorLabel = nil
        self.pickState = .unmarked
        self.copyStatus = .notCopied
        self.xmpStatus = .none
        self.thumbnailCacheKey = url.path
        self.pairedAssetKey = nil
    }
}

struct MediaTransform: Codable, Hashable {
    var rotationDegrees: Double = 0
    var flippedHorizontally = false
    var flippedVertically = false
}

extension MediaItem {
    var displayAspectRatio: CGFloat? {
        let dimensions = displayDimensions
        guard dimensions.width > 0, dimensions.height > 0 else { return nil }
        return CGFloat(dimensions.width) / CGFloat(dimensions.height)
    }

    var displayDimensions: (width: Int, height: Int) {
        if let width = displayPixelWidth, let height = displayPixelHeight, width > 0, height > 0 {
            return (width, height)
        }
        guard let pixelWidth, let pixelHeight, pixelWidth > 0, pixelHeight > 0 else {
            return (0, 0)
        }
        let normalizedRotation = Self.normalizedQuarterTurn(displayRotationDegrees)
        if normalizedRotation == 90 || normalizedRotation == 270 {
            return (pixelHeight, pixelWidth)
        }
        return (pixelWidth, pixelHeight)
    }

    func displayAspectRatio(applying transform: MediaTransform) -> CGFloat? {
        guard let base = displayAspectRatio, base > 0 else { return nil }
        let normalizedRotation = Self.normalizedQuarterTurn(transform.rotationDegrees)
        return normalizedRotation == 90 || normalizedRotation == 270 ? 1 / base : base
    }

    private static func normalizedQuarterTurn(_ degrees: Double) -> Int {
        ((Int(degrees.rounded()) % 360) + 360) % 360
    }
}

enum MediaType: String, Codable, CaseIterable {
    case raw, jpeg, heic, tiff, png, video, unknown

    var displayName: String {
        rawValue.uppercased()
    }
}

enum PickState: String, Codable, CaseIterable {
    case unmarked, picked, rejected

    var displayName: String {
        switch self {
        case .unmarked: L10n.tr("Unmarked")
        case .picked: L10n.tr("Pick")
        case .rejected: L10n.tr("Reject")
        }
    }
}

enum CopyStatus: String, Codable, CaseIterable {
    case notCopied, queued, copying, copied, verified, failed, skipped, cancelled
}

enum XMPStatus: String, Codable, CaseIterable {
    case none, sidecarFound, sidecarWritten, conflict
}

enum ColorLabel: String, Codable, CaseIterable, Identifiable {
    case red, yellow, green, blue, purple

    var id: String { rawValue }

    var displayName: String {
        L10n.tr(rawValue.capitalized)
    }
}

struct SimilarityGroup: Identifiable, Codable {
    let id: UUID
    var items: [MediaItem]
    var groupLabel: String
    var similarityScore: Double?
}

struct CopyLogRecord: Identifiable, Codable, Hashable {
    let id: UUID
    var startedAt: Date
    var finishedAt: Date?
    var sourcePath: String?
    var destinationPath: String
    var rule: CopyOrganizationRule
    var totalItems: Int
    var totalBytes: Int64
    var entries: [CopyLogEntry]

    var isFinished: Bool { finishedAt != nil }
}

struct CopyLogEntry: Identifiable, Codable, Hashable {
    let id: UUID
    var timestamp: Date
    var filename: String
    var status: CopyStatus
    var message: String
}

struct BatchRenameLogRecord: Identifiable, Codable, Hashable {
    let id: UUID
    var createdAt: Date
    var sourcePath: String?
    var totalItems: Int
    var entries: [BatchRenameLogEntry]
}

struct BatchRenameLogEntry: Identifiable, Codable, Hashable {
    let id: UUID
    var originalName: String
    var newName: String
    var folderPath: String
}
