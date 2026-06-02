import AppKit
import XCTest
@testable import PreStage

final class ImageAnalysisServiceTests: XCTestCase {
    func testImageAnalysisServiceBuildsRGBABufferFromJPEG() throws {
        let root = try TestSupport.temporaryDirectory(named: "image-analysis-buffer")
        let url = root.appendingPathComponent("sample.jpg")
        try writeTestImage(to: url)

        let buffer = try XCTUnwrap(ImageAnalysisService.makeBuffer(for: url, maxPixelSize: 32))

        XCTAssertEqual(buffer.width, 4)
        XCTAssertEqual(buffer.height, 1)
        XCTAssertEqual(buffer.pixels.count, 16)
        XCTAssertFalse(buffer.isEmpty)
    }

    func testImageAnalysisServiceCachesBufferByFileFingerprint() async throws {
        let root = try TestSupport.temporaryDirectory(named: "image-analysis-cache")
        let url = root.appendingPathComponent("sample.jpg")
        try writeTestImage(to: url)
        let item = TestSupport.mediaItem(url: url, type: .jpeg, fileSize: Int64((try? Data(contentsOf: url).count) ?? 0))
        let service = ImageAnalysisService(maxPixelSize: 32)

        let first = await service.buffer(for: item, previewURL: url)
        let second = await service.buffer(for: item, previewURL: url)

        XCTAssertEqual(first, second)
        XCTAssertNotNil(first)
    }

    private func writeTestImage(to url: URL) throws {
        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: 4,
            pixelsHigh: 1,
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

        bitmap.setColor(NSColor(deviceRed: 1, green: 0, blue: 0, alpha: 1), atX: 0, y: 0)
        bitmap.setColor(NSColor(deviceRed: 0, green: 1, blue: 0, alpha: 1), atX: 1, y: 0)
        bitmap.setColor(NSColor(deviceRed: 0, green: 0, blue: 1, alpha: 1), atX: 2, y: 0)
        bitmap.setColor(NSColor(deviceWhite: 1, alpha: 1), atX: 3, y: 0)

        let data = try XCTUnwrap(bitmap.representation(using: .jpeg, properties: [.compressionFactor: 1.0]))
        try data.write(to: url)
    }
}
