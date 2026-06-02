import Foundation

struct PreviewPreheatProgress {
    var completedCount = 0
    var totalCount = 0
    var createdProxyCount = 0
    var skippedProxyCount = 0
    var failedCount = 0
    var currentFilename = ""
    var isRunning = false
    var startedAt: Date?
    var finishedAt: Date?

    var fraction: Double {
        guard totalCount > 0 else { return 0 }
        return Double(completedCount) / Double(totalCount)
    }

    var warmedCount: Int {
        max(0, completedCount - createdProxyCount - skippedProxyCount - failedCount)
    }

    var elapsedSeconds: TimeInterval {
        guard let startedAt else { return 0 }
        return (finishedAt ?? Date()).timeIntervalSince(startedAt)
    }
}

struct PreviewPreheatService {
    private let proxyGenerator = ProxyGenerationService()
    private let decoder = PreviewDecodeService.shared
    private let maxPixelSize = 768

    func preheat(
        items: [MediaItem],
        sourceRoot: URL,
        progress: @escaping @MainActor (PreviewPreheatProgress) -> Void
    ) async {
        var snapshot = PreviewPreheatProgress(totalCount: items.count, isRunning: true, startedAt: Date())
        await progress(snapshot)

        for item in items where !Task.isCancelled {
            snapshot.currentFilename = item.filename
            let outcome = await preheat(item: item, sourceRoot: sourceRoot)
            switch outcome {
            case .createdProxy:
                snapshot.createdProxyCount += 1
            case .skippedProxy:
                snapshot.skippedProxyCount += 1
            case .warmed:
                break
            case .failed:
                snapshot.failedCount += 1
            }
            snapshot.completedCount += 1
            await progress(snapshot)
        }

        guard !Task.isCancelled else { return }
        snapshot.isRunning = false
        snapshot.currentFilename = ""
        snapshot.finishedAt = Date()
        await progress(snapshot)
    }

    private func preheat(item: MediaItem, sourceRoot: URL) async -> PreviewPreheatOutcome {
        await Task.detached(priority: .utility) {
            guard item.mediaType != .video else { return .warmed }
            if item.mediaType == .raw {
                do {
                    let result = try proxyGenerator.prepareProxyIfNeeded(for: item, sourceRoot: sourceRoot)
                    switch result {
                    case .created(let url):
                        decoder.warmImage(at: url, maxPixelSize: maxPixelSize)
                        return .createdProxy
                    case .skipped(let url):
                        decoder.warmImage(at: url, maxPixelSize: maxPixelSize)
                        return .skippedProxy
                    }
                } catch {
                    return .failed
                }
            }

            decoder.warmImage(at: item.url, maxPixelSize: maxPixelSize)
            return .warmed
        }.value
    }
}

private enum PreviewPreheatOutcome {
    case createdProxy
    case skippedProxy
    case warmed
    case failed
}
