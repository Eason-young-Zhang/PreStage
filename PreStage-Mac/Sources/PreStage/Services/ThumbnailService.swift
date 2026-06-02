import AppKit
import Foundation
import QuickLookThumbnailing

final class ThumbnailService: ObservableObject {
    private let cache = NSCache<NSString, NSImage>()
    private let diskCache: ThumbnailDiskCache
    private let decoder: PreviewDecodeService
    private var inFlight = Set<String>()
    private var completions: [String: [(NSImage?) -> Void]] = [:]
    private var keysByItem = [String: Set<String>]()

    init(
        diskCache: ThumbnailDiskCache = .default,
        decoder: PreviewDecodeService = .shared,
        memoryCountLimit: Int = 360,
        memoryTotalCostLimit: Int = 96 * 1024 * 1024
    ) {
        self.diskCache = diskCache
        self.decoder = decoder
        cache.countLimit = memoryCountLimit
        cache.totalCostLimit = memoryTotalCostLimit
    }

    func thumbnail(for item: MediaItem, size: CGSize, completion: ((NSImage?) -> Void)? = nil) {
        let quantizedSize = quantizedSize(for: size)
        let key = cacheKey(for: item, quantizedSize: quantizedSize)
        if let image = cache.object(forKey: key as NSString) {
            completion?(image)
            return
        }
        if let completion {
            completions[key, default: []].append(completion)
        }
        if inFlight.contains(key) { return }
        inFlight.insert(key)

        let diskKey = diskCache.key(for: item, quantizedWidth: quantizedSize.width, quantizedHeight: quantizedSize.height)
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let diskImage = self?.diskCache.image(for: diskKey)
            DispatchQueue.main.async {
                guard let self else { return }
                if let diskImage {
                    self.inFlight.remove(key)
                    self.store(diskImage, key: key, itemKey: item.thumbnailCacheKey, size: size)
                    self.finish(key: key, image: diskImage)
                    return
                }
                self.generateThumbnail(for: item, size: size, key: key, diskKey: diskKey)
            }
        }
    }

    func image(for item: MediaItem, size: CGSize) -> NSImage? {
        cache.object(forKey: cacheKey(for: item, quantizedSize: quantizedSize(for: size)) as NSString)
    }

    func invalidate(_ item: MediaItem) {
        let keys = keysByItem.removeValue(forKey: item.thumbnailCacheKey) ?? []
        keys.forEach { cache.removeObject(forKey: $0 as NSString) }
        let prefix = "\(item.thumbnailCacheKey)-"
        inFlight = inFlight.filter { !$0.hasPrefix(prefix) }
        completions.keys
            .filter { $0.hasPrefix(prefix) }
            .forEach { completions.removeValue(forKey: $0) }
    }

    func removeAll() {
        cache.removeAllObjects()
        keysByItem.removeAll()
        inFlight.removeAll()
        completions.removeAll()
    }

    func clearAllCaches() {
        removeAll()
        diskCache.removeAll()
    }

    func diskCacheSize() -> Int64 {
        diskCache.totalSize()
    }

    private func generateThumbnail(for item: MediaItem, size: CGSize, key: String, diskKey: String) {
        if decoder.supportsDirectRasterPreview(url: item.url),
           let directImage = downsampledImage(at: item.url, size: size) {
            store(directImage, key: key, itemKey: item.thumbnailCacheKey, size: size)
            diskCache.store(directImage, for: diskKey)
            finish(key: key, image: directImage)
            inFlight.remove(key)
            return
        }

        let request = QLThumbnailGenerator.Request(
            fileAt: item.url,
            size: size,
            scale: NSScreen.main?.backingScaleFactor ?? 2,
            representationTypes: .thumbnail
        )

        QLThumbnailGenerator.shared.generateBestRepresentation(for: request) { [weak self] representation, _ in
            DispatchQueue.main.async {
                guard let self else { return }
                self.inFlight.remove(key)
                if let image = representation?.nsImage {
                    self.store(image, key: key, itemKey: item.thumbnailCacheKey, size: size)
                    self.diskCache.store(image, for: diskKey)
                    self.finish(key: key, image: image)
                } else if let fallback = self.downsampledImage(at: item.url, size: size) {
                    self.store(fallback, key: key, itemKey: item.thumbnailCacheKey, size: size)
                    self.diskCache.store(fallback, for: diskKey)
                    self.finish(key: key, image: fallback)
                } else {
                    self.finish(key: key, image: nil)
                }
            }
        }
    }

    private func cacheKey(for item: MediaItem, quantizedSize: (width: Int, height: Int)) -> String {
        "\(item.thumbnailCacheKey)-\(fileFingerprint(for: item))-\(quantizedSize.width)x\(quantizedSize.height)"
    }

    private func fileFingerprint(for item: MediaItem) -> String {
        let modified = item.modifiedDate?.timeIntervalSince1970 ?? item.createdDate?.timeIntervalSince1970 ?? 0
        return "\(Int(modified.rounded()))-\(item.fileSize)"
    }

    private func quantizedSize(for size: CGSize) -> (width: Int, height: Int) {
        (quantizedDimension(size.width), quantizedDimension(size.height))
    }

    private func finish(key: String, image: NSImage?) {
        let callbacks = completions.removeValue(forKey: key) ?? []
        callbacks.forEach { $0(image) }
    }

    private func store(_ image: NSImage, key: String, itemKey: String, size: CGSize) {
        cache.setObject(image, forKey: key as NSString, cost: imageCost(for: size))
        keysByItem[itemKey, default: []].insert(key)
    }

    private func quantizedDimension(_ value: CGFloat) -> Int {
        max(1, Int((value / 32).rounded(.up) * 32))
    }

    private func imageCost(for size: CGSize) -> Int {
        let scale = NSScreen.main?.backingScaleFactor ?? 2
        let pixels = max(1, Int(size.width * scale)) * max(1, Int(size.height * scale))
        return pixels * 4
    }

    private func downsampledImage(at url: URL, size: CGSize) -> NSImage? {
        let scale = NSScreen.main?.backingScaleFactor ?? 2
        return decoder.downsampledImage(at: url, size: size, scale: scale)
    }
}
