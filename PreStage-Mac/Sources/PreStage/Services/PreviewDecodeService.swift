import AppKit
import Foundation
import ImageIO

enum PreviewDecodeSourceKind: String, Equatable {
    case original
    case proxy
    case rawMissingProxy
}

struct PreviewDecodeSource: Equatable {
    var url: URL
    var kind: PreviewDecodeSourceKind
}

protocol PreviewRasterDecodeProvider {
    var identifier: String { get }

    func supportsDirectRasterPreview(url: URL) -> Bool
    func imagePixelSize(at url: URL) -> CGSize?
    func downsampledImage(at url: URL, maxPixelSize: Int) -> CGImage?
}

final class PreviewDecodeService {
    static let shared = PreviewDecodeService()

    private let imageCache = NSCache<NSString, CachedCGImage>()
    private let proxyGenerator: ProxyGenerationService
    private let rasterProvider: any PreviewRasterDecodeProvider

    init(
        proxyGenerator: ProxyGenerationService = ProxyGenerationService(),
        rasterProvider: any PreviewRasterDecodeProvider = ImageIOPreviewRasterDecodeProvider()
    ) {
        self.proxyGenerator = proxyGenerator
        self.rasterProvider = rasterProvider
        imageCache.countLimit = 48
        imageCache.totalCostLimit = 192 * 1024 * 1024
    }

    func previewSource(for item: MediaItem, sourceRoot: URL?) -> PreviewDecodeSource {
        guard item.mediaType == .raw else {
            return PreviewDecodeSource(url: item.url, kind: .original)
        }
        guard let sourceRoot else {
            return PreviewDecodeSource(url: item.url, kind: .rawMissingProxy)
        }
        if let proxyURL = proxyGenerator.validProxyURL(for: item, sourceRoot: sourceRoot) {
            return PreviewDecodeSource(url: proxyURL, kind: .proxy)
        }
        return PreviewDecodeSource(url: item.url, kind: .rawMissingProxy)
    }

    func supportsDirectRasterPreview(url: URL) -> Bool {
        rasterProvider.supportsDirectRasterPreview(url: url)
    }

    func imageAspectRatio(at url: URL) -> CGFloat? {
        guard let dimensions = imagePixelSize(at: url) else { return nil }
        return CGFloat(dimensions.width) / CGFloat(dimensions.height)
    }

    func imagePixelSize(at url: URL) -> CGSize? {
        rasterProvider.imagePixelSize(at: url)
    }

    func downsampledImage(at url: URL, maxPixelSize: Int, useCache: Bool = true) -> CGImage? {
        Self.downsampledImage(
            at: url,
            maxPixelSize: maxPixelSize,
            provider: rasterProvider,
            cache: useCache ? imageCache : nil
        )
    }

    func downsampledImage(at url: URL, size: CGSize, scale: CGFloat, useCache: Bool = true) -> NSImage? {
        let maxPixelSize = max(Int(max(size.width, size.height) * scale), 64)
        guard let image = downsampledImage(at: url, maxPixelSize: maxPixelSize, useCache: useCache) else {
            return nil
        }
        return NSImage(cgImage: image, size: NSSize(width: CGFloat(image.width) / scale, height: CGFloat(image.height) / scale))
    }

    @discardableResult
    func warmImage(at url: URL, maxPixelSize: Int) -> Bool {
        downsampledImage(at: url, maxPixelSize: maxPixelSize) != nil
    }

    static func supportsDirectRasterPreview(url: URL) -> Bool {
        ImageIOPreviewRasterDecodeProvider().supportsDirectRasterPreview(url: url)
    }

    static func imageAspectRatio(at url: URL) -> CGFloat? {
        guard let dimensions = imagePixelSize(at: url) else { return nil }
        return CGFloat(dimensions.width) / CGFloat(dimensions.height)
    }

    static func imagePixelSize(at url: URL) -> CGSize? {
        ImageIOPreviewRasterDecodeProvider().imagePixelSize(at: url)
    }

    static func downsampledImage(at url: URL, maxPixelSize: Int, cache: NSCache<NSString, CachedCGImage>? = nil) -> CGImage? {
        downsampledImage(
            at: url,
            maxPixelSize: maxPixelSize,
            provider: ImageIOPreviewRasterDecodeProvider(),
            cache: cache
        )
    }

    private static func downsampledImage(
        at url: URL,
        maxPixelSize: Int,
        provider: any PreviewRasterDecodeProvider,
        cache: NSCache<NSString, CachedCGImage>?
    ) -> CGImage? {
        let maxPixelSize = max(maxPixelSize, 64)
        let key = Self.cacheKey(for: url, maxPixelSize: maxPixelSize)
        if let key, let cached = cache?.object(forKey: key as NSString) {
            return cached.image
        }
        guard let image = provider.downsampledImage(at: url, maxPixelSize: maxPixelSize) else {
            return nil
        }
        if let key, let cache {
            cache.setObject(CachedCGImage(image), forKey: key as NSString, cost: image.width * image.height * 4)
        }
        return image
    }

    private static func cacheKey(for url: URL, maxPixelSize: Int) -> String? {
        guard let values = try? url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey]) else {
            return nil
        }
        let modified = values.contentModificationDate?.timeIntervalSince1970 ?? 0
        let fileSize = values.fileSize ?? 0
        return "\(url.path)|\(Int(modified.rounded()))|\(fileSize)|\(maxPixelSize)"
    }
}

struct ImageIOPreviewRasterDecodeProvider: PreviewRasterDecodeProvider {
    let identifier = "imageio"

    func supportsDirectRasterPreview(url: URL) -> Bool {
        switch url.pathExtension.lowercased() {
        case "jpg", "jpeg", "heic", "heif", "png", "tif", "tiff",
             "arw", "cr2", "cr3", "dng", "nef", "orf", "raf", "rw2":
            return true
        default:
            return false
        }
    }

    func imagePixelSize(at url: URL) -> CGSize? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int,
              width > 0,
              height > 0 else {
            return nil
        }

        let orientationValue = properties[kCGImagePropertyOrientation]
        let rotation = displayRotationDegrees(from: orientationValue)
        let normalizedRotation = ((Int(rotation.rounded()) % 360) + 360) % 360
        if normalizedRotation == 90 || normalizedRotation == 270 {
            return CGSize(width: height, height: width)
        }
        return CGSize(width: width, height: height)
    }

    func downsampledImage(at url: URL, maxPixelSize: Int) -> CGImage? {
        let maxPixelSize = max(maxPixelSize, 64)
        let options: [CFString: Any] = [
            kCGImageSourceShouldCache: false
        ]
        guard let source = CGImageSourceCreateWithURL(url as CFURL, options as CFDictionary) else { return nil }
        let thumbnailOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions as CFDictionary) else {
            return nil
        }
        return image
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
}

final class CachedCGImage {
    let image: CGImage

    init(_ image: CGImage) {
        self.image = image
    }
}
