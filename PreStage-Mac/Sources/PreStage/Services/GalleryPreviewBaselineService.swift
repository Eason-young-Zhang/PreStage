import Foundation

struct GalleryPreviewBaselineResult: Equatable {
    var sourceURL: URL
    var sampledItems: Int
    var rawItems: Int
    var rawProxyHitCount: Int
    var rawProxyMissingCount: Int
    var originalSourceCount: Int
    var proxySourceCount: Int
    var failedCount: Int
    var totalDuration: TimeInterval
    var samples: [GalleryPreviewBaselineSample]

    var averageWarmDuration: TimeInterval {
        guard !samples.isEmpty else { return 0 }
        return samples.reduce(0) { $0 + $1.warmDuration } / Double(samples.count)
    }

    var slowestSamples: [GalleryPreviewBaselineSample] {
        samples.sorted { $0.warmDuration > $1.warmDuration }.prefix(5).map { $0 }
    }
}

struct GalleryPreviewBaselineSample: Equatable {
    var filename: String
    var mediaType: MediaType
    var previewSource: GalleryPreviewSource
    var warmDuration: TimeInterval
    var didWarm: Bool
}

enum GalleryPreviewSource: String, Equatable {
    case original
    case proxy
    case rawMissingProxy

    var displayName: String {
        switch self {
        case .original: "Original / 原图"
        case .proxy: "Proxy / 代理"
        case .rawMissingProxy: "RAW original, missing proxy / RAW 原图，代理缺失"
        }
    }
}

struct GalleryPreviewBaselineService {
    private let decoder = PreviewDecodeService.shared
    private let maxPixelSize = 768

    func recordBaseline(items: [MediaItem], sourceRoot: URL, sampleLimit: Int = 40) async -> GalleryPreviewBaselineResult {
        let decoder = decoder
        let maxPixelSize = maxPixelSize
        return await Task.detached(priority: .utility) {
            let totalStart = Date()
            let candidates = items.filter { $0.mediaType != .video }.prefix(max(1, sampleLimit))
            var samples: [GalleryPreviewBaselineSample] = []
            var rawItems = 0
            var rawProxyHitCount = 0
            var rawProxyMissingCount = 0
            var originalSourceCount = 0
            var proxySourceCount = 0
            var failedCount = 0

            for item in candidates where !Task.isCancelled {
                let source = decoder.previewSource(for: item, sourceRoot: sourceRoot)
                switch source.kind {
                case .original:
                    originalSourceCount += 1
                case .proxy:
                    proxySourceCount += 1
                case .rawMissingProxy:
                    originalSourceCount += 1
                }

                if item.mediaType == .raw {
                    rawItems += 1
                    if source.kind == .proxy {
                        rawProxyHitCount += 1
                    } else {
                        rawProxyMissingCount += 1
                    }
                }

                let warmStart = Date()
                let didWarm = decoder.warmImage(at: source.url, maxPixelSize: maxPixelSize)
                let warmDuration = Date().timeIntervalSince(warmStart)
                if !didWarm {
                    failedCount += 1
                }
                samples.append(
                    GalleryPreviewBaselineSample(
                        filename: item.filename,
                        mediaType: item.mediaType,
                        previewSource: GalleryPreviewSource(source.kind),
                        warmDuration: warmDuration,
                        didWarm: didWarm
                    )
                )
            }

            return GalleryPreviewBaselineResult(
                sourceURL: sourceRoot,
                sampledItems: samples.count,
                rawItems: rawItems,
                rawProxyHitCount: rawProxyHitCount,
                rawProxyMissingCount: rawProxyMissingCount,
                originalSourceCount: originalSourceCount,
                proxySourceCount: proxySourceCount,
                failedCount: failedCount,
                totalDuration: Date().timeIntervalSince(totalStart),
                samples: samples
            )
        }.value
    }

}

private extension GalleryPreviewSource {
    init(_ source: PreviewDecodeSourceKind) {
        switch source {
        case .original:
            self = .original
        case .proxy:
            self = .proxy
        case .rawMissingProxy:
            self = .rawMissingProxy
        }
    }
}
