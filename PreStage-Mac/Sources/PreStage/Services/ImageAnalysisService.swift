import AppKit
import Foundation

struct ImageAnalysisBuffer: Equatable, Sendable {
    var width: Int
    var height: Int
    var pixels: [UInt8]

    var isEmpty: Bool {
        width <= 0 || height <= 0 || pixels.isEmpty
    }
}

actor AnalysisCache {
    private var buffers = [String: ImageAnalysisBuffer]()

    func buffer(for key: String) -> ImageAnalysisBuffer? {
        buffers[key]
    }

    func insert(_ buffer: ImageAnalysisBuffer, for key: String) {
        buffers[key] = buffer
    }

    func removeAll() {
        buffers.removeAll()
    }
}

actor ImageAnalysisService {
    private let cache: AnalysisCache
    private let maxPixelSize: Int
    private let decoder: PreviewDecodeService

    init(maxPixelSize: Int = 1024, cache: AnalysisCache = AnalysisCache(), decoder: PreviewDecodeService = .shared) {
        self.maxPixelSize = max(64, maxPixelSize)
        self.cache = cache
        self.decoder = decoder
    }

    func buffer(for item: MediaItem, previewURL: URL) async -> ImageAnalysisBuffer? {
        let key = Self.cacheKey(for: item, previewURL: previewURL, maxPixelSize: maxPixelSize)
        if let cached = await cache.buffer(for: key) {
            return cached
        }

        let maxPixelSize = maxPixelSize
        let decoder = decoder
        let buffer = await Task.detached(priority: .utility) {
            Self.makeBuffer(for: previewURL, maxPixelSize: maxPixelSize, decoder: decoder)
        }.value
        if let buffer {
            await cache.insert(buffer, for: key)
        }
        return buffer
    }

    func removeAll() async {
        await cache.removeAll()
    }

    static func makeBuffer(
        for url: URL,
        maxPixelSize: Int = 1024,
        decoder: PreviewDecodeService = .shared
    ) -> ImageAnalysisBuffer? {
        guard let image = decoder.downsampledImage(at: url, maxPixelSize: max(64, maxPixelSize)),
              let pixels = rgbaPixels(from: image) else {
            return nil
        }
        return ImageAnalysisBuffer(width: image.width, height: image.height, pixels: pixels)
    }

    static func cacheKey(for item: MediaItem, previewURL: URL, maxPixelSize: Int) -> String {
        let modified = item.modifiedDate?.timeIntervalSince1970 ?? item.createdDate?.timeIntervalSince1970 ?? 0
        return "\(item.thumbnailCacheKey)|\(previewURL.path)|\(Int(modified.rounded()))|\(item.fileSize)|\(maxPixelSize)"
    }

    private static func rgbaPixels(from image: CGImage) -> [UInt8]? {
        let width = image.width
        let height = image.height
        guard width > 0, height > 0 else { return nil }

        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        var pixels = Array(repeating: UInt8(0), count: height * bytesPerRow)
        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }

        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return pixels
    }
}
