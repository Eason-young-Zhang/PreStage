import Foundation
import XCTest
@testable import PreStage

final class RealWorldBaselineTests: XCTestCase {
    func testRealWorldFolderBaselineWhenConfigured() async throws {
        let environment = ProcessInfo.processInfo.environment
        guard let sourcePath = environment["PRESTAGE_REALWORLD_SOURCE"], !sourcePath.isEmpty else {
            throw XCTSkip("Set PRESTAGE_REALWORLD_SOURCE to run real-folder regression baselines.")
        }

        let sourceURL = URL(fileURLWithPath: sourcePath, isDirectory: true)
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: sourceURL.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            XCTFail("PRESTAGE_REALWORLD_SOURCE is not an existing directory: \(sourceURL.path)")
            return
        }

        let recursive = environment["PRESTAGE_REALWORLD_RECURSIVE"].map(parseBool) ?? true
        let sampleLimit = Int(environment["PRESTAGE_REALWORLD_SAMPLE_LIMIT"] ?? "") ?? 60

        let workflow = try await PerformanceBaselineService().recordBaseline(
            sourceURL: sourceURL,
            recursive: recursive
        )
        XCTAssertGreaterThan(workflow.totalItems, 0, "Real-world baseline needs at least one supported media item.")

        let preparedItems = try prepareItems(sourceURL: sourceURL, recursive: recursive)
        let preview = await GalleryPreviewBaselineService().recordBaseline(
            items: preparedItems,
            sourceRoot: sourceURL,
            sampleLimit: sampleLimit
        )

        let report = markdownReport(workflow: workflow, preview: preview)
        print("\n\(report)\n")

        if let reportPath = environment["PRESTAGE_REALWORLD_REPORT"], !reportPath.isEmpty {
            let reportURL = URL(fileURLWithPath: reportPath)
            try FileManager.default.createDirectory(
                at: reportURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try report.write(to: reportURL, atomically: true, encoding: .utf8)
        }
    }

    private func prepareItems(sourceURL: URL, recursive: Bool) throws -> [MediaItem] {
        let scanned = try MediaScanner().scan(directory: sourceURL, recursive: recursive)
        let metadataService = MetadataService()
        let xmpService = XMPService()
        let pairingService = MediaPairingService()
        let metadataItems = scanned.map { metadataService.applyMetadata(to: $0) }
        let xmpItems = metadataItems.map { xmpService.applySidecarMetadata(to: $0) }
        return pairingService.assignPairingKeys(to: xmpItems)
    }

    private func markdownReport(
        workflow: PerformanceBaselineResult,
        preview: GalleryPreviewBaselineResult
    ) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB, .useKB]
        formatter.countStyle = .file

        let slowSamples = preview.slowestSamples
            .map {
                "- \($0.filename): \($0.previewSource.rawValue), \(formatSeconds($0.warmDuration)), warmed=\($0.didWarm)"
            }
            .joined(separator: "\n")

        return """
        # Real-World Baseline / 真实样本基线

        Source: `\(workflow.sourceURL.path)`
        Recursive: \(workflow.recursive)
        Created: \(Date())

        ## Workflow / 工作流

        - Total items: \(workflow.totalItems)
        - Total bytes: \(formatter.string(fromByteCount: workflow.totalBytes))
        - RAW: \(workflow.mediaCounts.raw)
        - JPEG: \(workflow.mediaCounts.jpeg)
        - HEIC: \(workflow.mediaCounts.heic)
        - TIFF: \(workflow.mediaCounts.tiff)
        - PNG: \(workflow.mediaCounts.png)
        - Video: \(workflow.mediaCounts.video)
        - RAW-only count: \(workflow.rawOnlyCount)
        - RAW proxy valid/missing: \(workflow.rawProxyValidCount)/\(workflow.rawProxyMissingCount)
        - Scan: \(formatSeconds(workflow.scanDuration))
        - Metadata: \(formatSeconds(workflow.metadataDuration))
        - XMP: \(formatSeconds(workflow.xmpDuration))
        - Pairing: \(formatSeconds(workflow.pairingDuration))
        - Proxy check: \(formatSeconds(workflow.proxyCheckDuration))
        - Total: \(formatSeconds(workflow.totalDuration))

        ## Gallery Preview / 画廊预览

        - Sampled items: \(preview.sampledItems)
        - RAW sampled: \(preview.rawItems)
        - Proxy hits/missing: \(preview.rawProxyHitCount)/\(preview.rawProxyMissingCount)
        - Preview source original/proxy: \(preview.originalSourceCount)/\(preview.proxySourceCount)
        - Failed warmups: \(preview.failedCount)
        - Average warmup: \(formatSeconds(preview.averageWarmDuration))
        - Total preview baseline: \(formatSeconds(preview.totalDuration))

        ## Slowest Preview Samples / 最慢预览样本

        \(slowSamples.isEmpty ? "- None" : slowSamples)
        """
    }

    private func parseBool(_ value: String) -> Bool {
        switch value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "1", "true", "yes", "y", "on":
            return true
        default:
            return false
        }
    }

    private func formatSeconds(_ value: TimeInterval) -> String {
        String(format: "%.3fs", value)
    }
}
