import Foundation

struct PerformanceBaselineResult: Equatable {
    var sourceURL: URL
    var recursive: Bool
    var totalItems: Int
    var totalBytes: Int64
    var mediaCounts: PerformanceMediaCounts
    var rawOnlyCount: Int
    var rawProxyValidCount: Int
    var rawProxyMissingCount: Int
    var scanDuration: TimeInterval
    var metadataDuration: TimeInterval
    var xmpDuration: TimeInterval
    var pairingDuration: TimeInterval
    var proxyCheckDuration: TimeInterval
    var totalDuration: TimeInterval

    var rawProxyTotalCount: Int {
        rawProxyValidCount + rawProxyMissingCount
    }
}

struct PerformanceMediaCounts: Equatable {
    var raw = 0
    var jpeg = 0
    var heic = 0
    var tiff = 0
    var png = 0
    var video = 0
    var unknown = 0

    mutating func add(_ type: MediaType) {
        switch type {
        case .raw: raw += 1
        case .jpeg: jpeg += 1
        case .heic: heic += 1
        case .tiff: tiff += 1
        case .png: png += 1
        case .video: video += 1
        case .unknown: unknown += 1
        }
    }
}

struct PerformanceBaselineService {
    private let scanner = MediaScanner()
    private let proxyGenerator = ProxyGenerationService()

    func recordBaseline(sourceURL: URL, recursive: Bool) async throws -> PerformanceBaselineResult {
        try await Task.detached(priority: .userInitiated) {
            let totalStart = Date()

            let scanStart = Date()
            let scannedItems = try scanner.scan(directory: sourceURL, recursive: recursive)
            let scanDuration = Date().timeIntervalSince(scanStart)

            let metadataService = MetadataService()
            let metadataStart = Date()
            let metadataItems = scannedItems.map { metadataService.applyMetadata(to: $0) }
            let metadataDuration = Date().timeIntervalSince(metadataStart)

            let xmpService = XMPService()
            let xmpStart = Date()
            let xmpItems = metadataItems.map { xmpService.applySidecarMetadata(to: $0) }
            let xmpDuration = Date().timeIntervalSince(xmpStart)

            let pairingService = MediaPairingService()
            let pairingStart = Date()
            let pairedItems = pairingService.assignPairingKeys(to: xmpItems)
            let pairingDuration = Date().timeIntervalSince(pairingStart)

            var counts = PerformanceMediaCounts()
            var totalBytes: Int64 = 0
            for item in pairedItems {
                counts.add(item.mediaType)
                totalBytes += item.fileSize
            }

            let rawOnlyCount = rawOnlyItemCount(in: pairedItems)
            let proxyStart = Date()
            let rawItems = pairedItems.filter { $0.mediaType == .raw }
            var rawProxyValidCount = 0
            for item in rawItems where proxyGenerator.validProxyURL(for: item, sourceRoot: sourceURL) != nil {
                rawProxyValidCount += 1
            }
            let proxyCheckDuration = Date().timeIntervalSince(proxyStart)

            return PerformanceBaselineResult(
                sourceURL: sourceURL,
                recursive: recursive,
                totalItems: pairedItems.count,
                totalBytes: totalBytes,
                mediaCounts: counts,
                rawOnlyCount: rawOnlyCount,
                rawProxyValidCount: rawProxyValidCount,
                rawProxyMissingCount: max(0, rawItems.count - rawProxyValidCount),
                scanDuration: scanDuration,
                metadataDuration: metadataDuration,
                xmpDuration: xmpDuration,
                pairingDuration: pairingDuration,
                proxyCheckDuration: proxyCheckDuration,
                totalDuration: Date().timeIntervalSince(totalStart)
            )
        }.value
    }

    private func rawOnlyItemCount(in items: [MediaItem]) -> Int {
        let membersByPairKey = Dictionary(grouping: items.filter { $0.pairedAssetKey != nil }) { item in
            item.pairedAssetKey ?? ""
        }
        return items.filter { item in
            guard item.mediaType == .raw else { return false }
            guard let key = item.pairedAssetKey else { return true }
            return !(membersByPairKey[key] ?? []).contains { $0.mediaType == .jpeg }
        }.count
    }
}
