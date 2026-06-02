import AppKit
import XCTest
@testable import PreStage

final class PreviewDecodeServiceTests: XCTestCase {
    func testPreviewDecodeServiceChoosesFreshProxyForRawItems() throws {
        let root = try TestSupport.temporaryDirectory(named: "preview-decode-source")
        let rawURL = root.appendingPathComponent("P1110163.RW2")
        try TestSupport.writeFile(rawURL)
        let modifiedDate = TestSupport.date(2026, 5, 20)
        try FileManager.default.setAttributes([.modificationDate: modifiedDate], ofItemAtPath: rawURL.path)
        let item = TestSupport.mediaItem(url: rawURL, type: .raw, modifiedDate: modifiedDate)

        let proxyURL = ProxyGenerationService().proxyURL(for: rawURL, sourceRoot: root)
        try writeTestJPEG(width: 1200, height: 800, to: proxyURL)
        try FileManager.default.setAttributes([.modificationDate: TestSupport.date(2026, 5, 21)], ofItemAtPath: proxyURL.path)

        let source = PreviewDecodeService.shared.previewSource(for: item, sourceRoot: root)

        XCTAssertEqual(source.kind, .proxy)
        XCTAssertEqual(source.url, proxyURL)
    }

    func testPreviewDecodeServiceMarksRawMissingProxyWhenNoFreshProxyExists() throws {
        let root = try TestSupport.temporaryDirectory(named: "preview-decode-missing-proxy")
        let rawURL = root.appendingPathComponent("P1110164.RW2")
        try TestSupport.writeFile(rawURL)
        let item = TestSupport.mediaItem(url: rawURL, type: .raw)

        let source = PreviewDecodeService.shared.previewSource(for: item, sourceRoot: root)

        XCTAssertEqual(source.kind, .rawMissingProxy)
        XCTAssertEqual(source.url, rawURL)
    }

    func testPreviewDecodeServiceDownsamplesAndCachesImage() throws {
        let root = try TestSupport.temporaryDirectory(named: "preview-decode-downsample")
        let url = root.appendingPathComponent("sample.jpg")
        try writeTestJPEG(width: 400, height: 200, to: url)

        let first = try XCTUnwrap(PreviewDecodeService.shared.downsampledImage(at: url, maxPixelSize: 64))
        let second = try XCTUnwrap(PreviewDecodeService.shared.downsampledImage(at: url, maxPixelSize: 64))

        XCTAssertLessThanOrEqual(max(first.width, first.height), 64)
        XCTAssertEqual(first.width, second.width)
        XCTAssertEqual(first.height, second.height)
        let aspectRatio = try XCTUnwrap(PreviewDecodeService.shared.imageAspectRatio(at: url))
        XCTAssertEqual(aspectRatio, 2, accuracy: 0.001)
    }

    func testPreviewDecodeServiceCanUseInjectedRasterProvider() throws {
        let root = try TestSupport.temporaryDirectory(named: "preview-decode-provider")
        let url = root.appendingPathComponent("sample.raw")
        try TestSupport.writeFile(url)
        let provider = StubRasterDecodeProvider(pixelSize: CGSize(width: 300, height: 100))
        let decoder = PreviewDecodeService(rasterProvider: provider)

        XCTAssertTrue(decoder.supportsDirectRasterPreview(url: url))
        XCTAssertEqual(decoder.imagePixelSize(at: url), CGSize(width: 300, height: 100))
        XCTAssertEqual(try XCTUnwrap(decoder.imageAspectRatio(at: url)), 3, accuracy: 0.001)

        _ = decoder.downsampledImage(at: url, maxPixelSize: 80)
        _ = decoder.downsampledImage(at: url, maxPixelSize: 80)

        XCTAssertEqual(provider.downsampleCallCount, 1)
    }

    private func writeTestJPEG(width: Int, height: Int, to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: width,
            pixelsHigh: height,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else {
            XCTFail("Failed to create test bitmap.")
            return
        }
        NSColor(deviceRed: 0.2, green: 0.4, blue: 0.8, alpha: 1).setFill()
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        NSRect(x: 0, y: 0, width: width, height: height).fill()
        NSGraphicsContext.restoreGraphicsState()

        let data = try XCTUnwrap(bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.9]))
        try data.write(to: url)
    }
}

private final class StubRasterDecodeProvider: PreviewRasterDecodeProvider {
    let identifier = "stub"
    let pixelSize: CGSize
    private(set) var downsampleCallCount = 0

    init(pixelSize: CGSize) {
        self.pixelSize = pixelSize
    }

    func supportsDirectRasterPreview(url: URL) -> Bool {
        true
    }

    func imagePixelSize(at url: URL) -> CGSize? {
        pixelSize
    }

    func downsampledImage(at url: URL, maxPixelSize: Int) -> CGImage? {
        downsampleCallCount += 1
        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: maxPixelSize,
            pixelsHigh: maxPixelSize / 2,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else {
            return nil
        }
        return bitmap.cgImage
    }
}
