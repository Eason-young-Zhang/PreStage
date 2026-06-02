import XCTest
@testable import PreStage

final class PerformanceBaselineServiceTests: XCTestCase {
    func testPerformanceBaselineCountsRawOnlyAndProxyReadiness() async throws {
        let root = try TestSupport.temporaryDirectory(named: "performance-baseline")
        let rawOnlyURL = root.appendingPathComponent("A.RW2")
        let pairedRawURL = root.appendingPathComponent("B.RW2")
        let pairedJPEGURL = root.appendingPathComponent("B.JPG")
        let videoURL = root.appendingPathComponent("C.MOV")
        try TestSupport.writeFile(rawOnlyURL)
        try TestSupport.writeFile(pairedRawURL)
        try TestSupport.writeFile(pairedJPEGURL)
        try TestSupport.writeFile(videoURL)

        let sourceModified = TestSupport.date(2026, 5, 20)
        try setModifiedDate(sourceModified, for: rawOnlyURL)
        let rawOnlyItem = TestSupport.mediaItem(url: rawOnlyURL, type: .raw, modifiedDate: sourceModified)
        let proxyURL = ProxyGenerationService().proxyURL(for: rawOnlyURL, sourceRoot: root)
        try TestSupport.writeFile(proxyURL)
        try setModifiedDate(TestSupport.date(2026, 5, 21), for: proxyURL)

        let result = try await PerformanceBaselineService().recordBaseline(sourceURL: root, recursive: false)

        XCTAssertEqual(result.totalItems, 4)
        XCTAssertEqual(result.mediaCounts.raw, 2)
        XCTAssertEqual(result.mediaCounts.jpeg, 1)
        XCTAssertEqual(result.mediaCounts.video, 1)
        XCTAssertEqual(result.rawOnlyCount, 1)
        XCTAssertEqual(result.rawProxyValidCount, 1)
        XCTAssertEqual(result.rawProxyMissingCount, 1)
        XCTAssertGreaterThanOrEqual(result.totalBytes, rawOnlyItem.fileSize)
        XCTAssertGreaterThanOrEqual(result.totalDuration, 0)
    }

    func testGalleryPreviewBaselineCountsPreviewSourcesAndProxyReadiness() async throws {
        let root = try TestSupport.temporaryDirectory(named: "gallery-preview-baseline")
        let jpegURL = root.appendingPathComponent("A.JPG")
        let rawWithProxyURL = root.appendingPathComponent("B.RW2")
        let rawMissingProxyURL = root.appendingPathComponent("C.RW2")
        try TestSupport.writeFile(jpegURL)
        try TestSupport.writeFile(rawWithProxyURL)
        try TestSupport.writeFile(rawMissingProxyURL)

        let sourceModified = TestSupport.date(2026, 5, 20)
        try setModifiedDate(sourceModified, for: rawWithProxyURL)
        let jpeg = TestSupport.mediaItem(url: jpegURL, type: .jpeg)
        let rawWithProxy = TestSupport.mediaItem(url: rawWithProxyURL, type: .raw, modifiedDate: sourceModified)
        let rawMissingProxy = TestSupport.mediaItem(url: rawMissingProxyURL, type: .raw, modifiedDate: sourceModified)
        let proxyURL = ProxyGenerationService().proxyURL(for: rawWithProxyURL, sourceRoot: root)
        try TestSupport.writeFile(proxyURL)
        try setModifiedDate(TestSupport.date(2026, 5, 21), for: proxyURL)

        let result = await GalleryPreviewBaselineService().recordBaseline(
            items: [jpeg, rawWithProxy, rawMissingProxy],
            sourceRoot: root,
            sampleLimit: 10
        )

        XCTAssertEqual(result.sampledItems, 3)
        XCTAssertEqual(result.rawItems, 2)
        XCTAssertEqual(result.rawProxyHitCount, 1)
        XCTAssertEqual(result.rawProxyMissingCount, 1)
        XCTAssertEqual(result.proxySourceCount, 1)
        XCTAssertEqual(result.originalSourceCount, 2)
        XCTAssertEqual(result.samples.map(\.previewSource), [.original, .proxy, .rawMissingProxy])
    }

    private func setModifiedDate(_ date: Date, for url: URL) throws {
        try FileManager.default.setAttributes([.modificationDate: date], ofItemAtPath: url.path)
    }
}
