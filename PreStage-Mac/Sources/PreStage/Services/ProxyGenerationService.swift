import AppKit
import Foundation
import ImageIO
import UniformTypeIdentifiers

struct ProxyGenerationProgress {
    var completedCount = 0
    var totalCount = 0
    var createdCount = 0
    var skippedCount = 0
    var failedCount = 0
    var currentFilename = ""
    var isRunning = false

    var fraction: Double {
        guard totalCount > 0 else { return 0 }
        return Double(completedCount) / Double(totalCount)
    }
}

enum ProxyPreparationResult: Equatable {
    case created(URL)
    case skipped(URL)
}

struct ProxyGenerationService {
    static let proxyFolderName = "PreStage Proxies"

    private let maximumPixelSize = 2048
    private let compressionQuality = 0.55

    func generateProxies(
        for items: [MediaItem],
        sourceRoot: URL,
        progress: @escaping @MainActor (ProxyGenerationProgress) -> Void
    ) async {
        var snapshot = ProxyGenerationProgress(totalCount: items.count, isRunning: true)
        await progress(snapshot)

        for item in items where item.mediaType != .video {
            snapshot.currentFilename = item.filename
            do {
                switch try prepareProxyIfNeeded(for: item, sourceRoot: sourceRoot) {
                case .created:
                    snapshot.createdCount += 1
                case .skipped:
                    snapshot.skippedCount += 1
                }
            } catch {
                snapshot.failedCount += 1
            }

            snapshot.completedCount += 1
            await progress(snapshot)
        }

        snapshot.isRunning = false
        snapshot.currentFilename = ""
        await progress(snapshot)
    }

    func validProxyURL(for item: MediaItem, sourceRoot: URL) -> URL? {
        let url = proxyURL(for: item.url, sourceRoot: sourceRoot)
        return hasValidProxy(for: item, sourceRoot: sourceRoot) ? url : nil
    }

    func prepareProxyIfNeeded(for item: MediaItem, sourceRoot: URL) throws -> ProxyPreparationResult {
        let destinationURL = proxyURL(for: item.url, sourceRoot: sourceRoot)
        if hasValidProxy(for: item, sourceRoot: sourceRoot) {
            return .skipped(destinationURL)
        }
        try FileManager.default.createDirectory(
            at: destinationURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try writeProxy(for: item.url, to: destinationURL)
        return .created(destinationURL)
    }

    func hasValidProxy(for item: MediaItem, sourceRoot: URL) -> Bool {
        let url = proxyURL(for: item.url, sourceRoot: sourceRoot)
        guard FileManager.default.fileExists(atPath: url.path) else { return false }
        guard let proxyModified = try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate else {
            return true
        }
        guard let sourceModified = item.modifiedDate ?? (try? item.url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) else {
            return true
        }
        return proxyModified >= sourceModified
    }

    func proxyURL(for sourceURL: URL, sourceRoot: URL) -> URL {
        let rootPath = sourceRoot.standardizedFileURL.path
        let sourceFolder = sourceURL.deletingLastPathComponent().standardizedFileURL.path
        let relativeFolder = sourceFolder.hasPrefix(rootPath)
            ? String(sourceFolder.dropFirst(rootPath.count)).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            : ""
        let proxyRoot = sourceRoot.appendingPathComponent(Self.proxyFolderName, isDirectory: true)
        let destinationFolder = relativeFolder.isEmpty ? proxyRoot : proxyRoot.appendingPathComponent(relativeFolder, isDirectory: true)
        let proxyName = "\(sourceURL.deletingPathExtension().lastPathComponent)-proxy.jpg"
        return destinationFolder.appendingPathComponent(proxyName)
    }

    private func writeProxy(for sourceURL: URL, to destinationURL: URL) throws {
        let sourceOptions: [CFString: Any] = [
            kCGImageSourceShouldCache: false
        ]
        guard let source = CGImageSourceCreateWithURL(sourceURL as CFURL, sourceOptions as CFDictionary),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions() as CFDictionary),
              let destination = CGImageDestinationCreateWithURL(destinationURL as CFURL, UTType.jpeg.identifier as CFString, 1, nil) else {
            throw ProxyGenerationError.cannotCreateProxy
        }

        let properties: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: compressionQuality
        ]
        CGImageDestinationAddImage(destination, image, properties as CFDictionary)
        guard CGImageDestinationFinalize(destination) else {
            throw ProxyGenerationError.cannotWriteProxy
        }
    }

    private func thumbnailOptions() -> [CFString: Any] {
        [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maximumPixelSize
        ]
    }
}

private enum ProxyGenerationError: Error {
    case cannotCreateProxy
    case cannotWriteProxy
}
