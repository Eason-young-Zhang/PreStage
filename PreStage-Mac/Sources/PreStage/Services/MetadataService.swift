import Foundation
import ImageIO

struct MetadataLoadProgress: Equatable {
    var completedCount = 0
    var totalCount = 0
    var currentFilename = ""
    var isRunning = false

    var fraction: Double {
        guard totalCount > 0 else { return 0 }
        return Double(completedCount) / Double(totalCount)
    }
}

struct MediaMetadataSnapshot: Codable, Equatable {
    var captureDate: Date?
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

    enum CodingKeys: String, CodingKey {
        case captureDate
        case cameraMake
        case cameraModel
        case lensModel
        case focalLength
        case aperture
        case shutterSpeed
        case iso
        case pixelWidth
        case pixelHeight
        case displayPixelWidth
        case displayPixelHeight
        case displayRotationDegrees
        case colorSpaceName
        case colorProfileName
    }

    init(item: MediaItem) {
        captureDate = item.captureDate
        cameraMake = item.cameraMake
        cameraModel = item.cameraModel
        lensModel = item.lensModel
        focalLength = item.focalLength
        aperture = item.aperture
        shutterSpeed = item.shutterSpeed
        iso = item.iso
        pixelWidth = item.pixelWidth
        pixelHeight = item.pixelHeight
        displayPixelWidth = item.displayPixelWidth
        displayPixelHeight = item.displayPixelHeight
        displayRotationDegrees = item.displayRotationDegrees
        colorSpaceName = item.colorSpaceName
        colorProfileName = item.colorProfileName
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        captureDate = try container.decodeIfPresent(Date.self, forKey: .captureDate)
        cameraMake = try container.decodeIfPresent(String.self, forKey: .cameraMake)
        cameraModel = try container.decodeIfPresent(String.self, forKey: .cameraModel)
        lensModel = try container.decodeIfPresent(String.self, forKey: .lensModel)
        focalLength = try container.decodeIfPresent(Double.self, forKey: .focalLength)
        aperture = try container.decodeIfPresent(Double.self, forKey: .aperture)
        shutterSpeed = try container.decodeIfPresent(String.self, forKey: .shutterSpeed)
        iso = try container.decodeIfPresent(Int.self, forKey: .iso)
        pixelWidth = try container.decodeIfPresent(Int.self, forKey: .pixelWidth)
        pixelHeight = try container.decodeIfPresent(Int.self, forKey: .pixelHeight)
        displayPixelWidth = try container.decodeIfPresent(Int.self, forKey: .displayPixelWidth)
        displayPixelHeight = try container.decodeIfPresent(Int.self, forKey: .displayPixelHeight)
        displayRotationDegrees = try container.decodeIfPresent(Double.self, forKey: .displayRotationDegrees) ?? 0
        colorSpaceName = try container.decodeIfPresent(String.self, forKey: .colorSpaceName)
        colorProfileName = try container.decodeIfPresent(String.self, forKey: .colorProfileName)
    }

    func applying(to item: MediaItem) -> MediaItem {
        var updated = item
        updated.captureDate = captureDate
        updated.cameraMake = cameraMake
        updated.cameraModel = cameraModel
        updated.lensModel = lensModel
        updated.focalLength = focalLength
        updated.aperture = aperture
        updated.shutterSpeed = shutterSpeed
        updated.iso = iso
        updated.pixelWidth = pixelWidth
        updated.pixelHeight = pixelHeight
        updated.displayPixelWidth = displayPixelWidth
        updated.displayPixelHeight = displayPixelHeight
        updated.displayRotationDegrees = displayRotationDegrees
        updated.colorSpaceName = colorSpaceName
        updated.colorProfileName = colorProfileName
        return updated
    }
}

actor MetadataDiskCache {
    private var entries: [String: MediaMetadataSnapshot] = [:]
    private var isLoaded = false
    private let cacheURL: URL

    init(cacheURL: URL? = nil) {
        self.cacheURL = cacheURL ?? MetadataDiskCache.defaultCacheURL()
    }

    func snapshots(for fingerprints: [String]) async -> [String: MediaMetadataSnapshot] {
        loadIfNeeded()
        var matches: [String: MediaMetadataSnapshot] = [:]
        for fingerprint in fingerprints {
            matches[fingerprint] = entries[fingerprint]
        }
        return matches
    }

    func store(_ updates: [(fingerprint: String, snapshot: MediaMetadataSnapshot)]) async {
        guard !updates.isEmpty else { return }
        loadIfNeeded()
        for update in updates {
            entries[update.fingerprint] = update.snapshot
        }
        persist()
    }

    private func loadIfNeeded() {
        guard !isLoaded else { return }
        isLoaded = true
        guard let data = try? Data(contentsOf: cacheURL),
              let decoded = try? JSONDecoder().decode([String: MediaMetadataSnapshot].self, from: data) else {
            entries = [:]
            return
        }
        entries = decoded
    }

    private func persist() {
        do {
            try FileManager.default.createDirectory(
                at: cacheURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let data = try JSONEncoder().encode(entries)
            try data.write(to: cacheURL, options: .atomic)
        } catch {
            // Cache writes are best-effort; failed writes should not affect browsing.
        }
    }

    static func defaultCacheURL() -> URL {
        do {
            let supportURL = try FileManager.default.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            return supportURL
                .appendingPathComponent("PreStage", isDirectory: true)
                .appendingPathComponent("MetadataCache", isDirectory: true)
                .appendingPathComponent("metadata-v2-display-geometry.json")
        } catch {
            return FileManager.default.temporaryDirectory
                .appendingPathComponent("PreStage", isDirectory: true)
                .appendingPathComponent("MetadataCache", isDirectory: true)
                .appendingPathComponent("metadata-v2-display-geometry.json")
        }
    }
}

struct MetadataService {
    func applyMetadata(to item: MediaItem) -> MediaItem {
        guard let source = CGImageSourceCreateWithURL(item.url as CFURL, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] else {
            return item
        }

        var updated = item
        let tiff = properties[kCGImagePropertyTIFFDictionary] as? [CFString: Any]
        let exif = properties[kCGImagePropertyExifDictionary] as? [CFString: Any]

        updated.pixelWidth = properties[kCGImagePropertyPixelWidth] as? Int
        updated.pixelHeight = properties[kCGImagePropertyPixelHeight] as? Int
        updated.displayRotationDegrees = displayRotationDegrees(from: properties[kCGImagePropertyOrientation])
        let displaySize = displayPixelSize(from: source, fallbackWidth: updated.pixelWidth, fallbackHeight: updated.pixelHeight, rotationDegrees: updated.displayRotationDegrees)
        updated.displayPixelWidth = displaySize?.width
        updated.displayPixelHeight = displaySize?.height
        updated.colorSpaceName = properties[kCGImagePropertyColorModel] as? String
        updated.colorProfileName = properties[kCGImagePropertyProfileName] as? String
        updated.cameraMake = tiff?[kCGImagePropertyTIFFMake] as? String
        updated.cameraModel = tiff?[kCGImagePropertyTIFFModel] as? String
        updated.lensModel = exif?[kCGImagePropertyExifLensModel] as? String
        updated.focalLength = exif?[kCGImagePropertyExifFocalLength] as? Double
        updated.aperture = exif?[kCGImagePropertyExifFNumber] as? Double
        updated.iso = (exif?[kCGImagePropertyExifISOSpeedRatings] as? [Int])?.first
        if let exposure = exif?[kCGImagePropertyExifExposureTime] as? Double {
            updated.shutterSpeed = formatExposureTime(exposure)
        }

        if let date = readCaptureDate(exif: exif, tiff: tiff) {
            updated.captureDate = date
        }

        return updated
    }

    private func displayPixelSize(
        from source: CGImageSource,
        fallbackWidth: Int?,
        fallbackHeight: Int?,
        rotationDegrees: Double
    ) -> (width: Int, height: Int)? {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageIfAbsent: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCache: false,
            kCGImageSourceShouldCacheImmediately: false,
            kCGImageSourceThumbnailMaxPixelSize: 1024
        ]

        if let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) {
            return (thumbnail.width, thumbnail.height)
        }

        guard let fallbackWidth, let fallbackHeight, fallbackWidth > 0, fallbackHeight > 0 else {
            return nil
        }
        let normalizedRotation = ((Int(rotationDegrees.rounded()) % 360) + 360) % 360
        if normalizedRotation == 90 || normalizedRotation == 270 {
            return (fallbackHeight, fallbackWidth)
        }
        return (fallbackWidth, fallbackHeight)
    }

    private func displayRotationDegrees(from value: Any?) -> Double {
        let orientation: Int?
        if let number = value as? NSNumber {
            orientation = number.intValue
        } else {
            orientation = value as? Int
        }

        switch orientation {
        case 3, 4:
            return 180
        case 5, 6:
            return 90
        case 7, 8:
            return 270
        default:
            return 0
        }
    }

    private func readCaptureDate(exif: [CFString: Any]?, tiff: [CFString: Any]?) -> Date? {
        let candidates = [
            exif?[kCGImagePropertyExifDateTimeOriginal] as? String,
            exif?[kCGImagePropertyExifDateTimeDigitized] as? String,
            tiff?[kCGImagePropertyTIFFDateTime] as? String
        ]

        for candidate in candidates.compactMap({ $0 }) {
            if let date = MetadataDateParser.parse(candidate) {
                return date
            }
        }
        return nil
    }

    private func formatExposureTime(_ seconds: Double) -> String {
        guard seconds > 0 else { return "" }
        if seconds < 1 {
            return "1/\(Int((1 / seconds).rounded()))"
        }
        return String(format: "%.1fs", seconds)
    }
}

private enum MetadataDateParser {
    private static let formatters: [DateFormatter] = {
        let formats = [
            "yyyy:MM:dd HH:mm:ss",
            "yyyy-MM-dd HH:mm:ss",
            "yyyy-MM-dd'T'HH:mm:ssZ",
            "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        ]
        return formats.map { format in
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = format
            return formatter
        }
    }()

    static func parse(_ value: String) -> Date? {
        for formatter in formatters {
            if let date = formatter.date(from: value) {
                return date
            }
        }
        return nil
    }
}
