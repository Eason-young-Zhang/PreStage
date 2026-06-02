import AppKit
import CryptoKit
import Foundation

final class ThumbnailDiskCache {
    static let `default` = ThumbnailDiskCache(
        directoryURL: defaultDirectoryURL(),
        maxBytes: 512 * 1024 * 1024,
        maxAge: 60 * 60 * 24 * 30
    )

    let directoryURL: URL
    private let maxBytes: Int64
    private let maxAge: TimeInterval
    private let fileManager: FileManager
    private var lastTrimDate = Date.distantPast
    private let trimInterval: TimeInterval = 60

    init(directoryURL: URL, maxBytes: Int64, maxAge: TimeInterval, fileManager: FileManager = .default) {
        self.directoryURL = directoryURL
        self.maxBytes = maxBytes
        self.maxAge = maxAge
        self.fileManager = fileManager
        try? fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
    }

    func key(for item: MediaItem, quantizedWidth: Int, quantizedHeight: Int) -> String {
        let modified = item.modifiedDate?.timeIntervalSince1970 ?? item.createdDate?.timeIntervalSince1970 ?? 0
        let rawKey = "\(item.thumbnailCacheKey)|modified:\(modified)|bytes:\(item.fileSize)|\(quantizedWidth)x\(quantizedHeight)"
        let digest = SHA256.hash(data: Data(rawKey.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    func image(for key: String) -> NSImage? {
        NSImage(contentsOf: fileURL(for: key))
    }

    func store(_ image: NSImage, for key: String) {
        guard let data = jpegData(for: image) else { return }
        try? fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        try? data.write(to: fileURL(for: key), options: .atomic)
        trimIfNeeded()
    }

    func removeAll() {
        guard let files = try? fileManager.contentsOfDirectory(at: directoryURL, includingPropertiesForKeys: nil) else { return }
        for file in files {
            try? fileManager.removeItem(at: file)
        }
    }

    func totalSize() -> Int64 {
        cacheFiles().reduce(Int64(0)) { total, file in
            total + file.size
        }
    }

    func trimIfNeeded(now: Date = Date(), force: Bool = false) {
        guard force || now.timeIntervalSince(lastTrimDate) >= trimInterval else { return }
        lastTrimDate = now

        let files = cacheFiles()
        let expiredCutoff = now.addingTimeInterval(-maxAge)
        for file in files where file.modifiedDate < expiredCutoff {
            try? fileManager.removeItem(at: file.url)
        }

        var remainingFiles = cacheFiles().sorted { $0.modifiedDate < $1.modifiedDate }
        var remainingBytes = remainingFiles.reduce(Int64(0)) { $0 + $1.size }
        while remainingBytes > maxBytes, let file = remainingFiles.first {
            try? fileManager.removeItem(at: file.url)
            remainingBytes -= file.size
            remainingFiles.removeFirst()
        }
    }

    private func fileURL(for key: String) -> URL {
        directoryURL.appendingPathComponent(key).appendingPathExtension("jpg")
    }

    private func cacheFiles() -> [CacheFile] {
        let keys: Set<URLResourceKey> = [.isRegularFileKey, .fileSizeKey, .contentModificationDateKey]
        guard let urls = try? fileManager.contentsOfDirectory(at: directoryURL, includingPropertiesForKeys: Array(keys)) else {
            return []
        }
        return urls.compactMap { url in
            guard url.pathExtension.lowercased() == "jpg",
                  let values = try? url.resourceValues(forKeys: keys),
                  values.isRegularFile == true else {
                return nil
            }
            return CacheFile(
                url: url,
                size: Int64(values.fileSize ?? 0),
                modifiedDate: values.contentModificationDate ?? .distantPast
            )
        }
    }

    private func jpegData(for image: NSImage) -> Data? {
        var rect = NSRect(origin: .zero, size: image.size)
        guard let cgImage = image.cgImage(forProposedRect: &rect, context: nil, hints: nil) else { return nil }
        let representation = NSBitmapImageRep(cgImage: cgImage)
        return representation.representation(using: .jpeg, properties: [.compressionFactor: 0.82])
    }

    private static func defaultDirectoryURL() -> URL {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return caches
            .appendingPathComponent("PreStage", isDirectory: true)
            .appendingPathComponent("Thumbnails", isDirectory: true)
    }

    private struct CacheFile {
        let url: URL
        let size: Int64
        let modifiedDate: Date
    }
}
