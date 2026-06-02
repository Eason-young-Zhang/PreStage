import AppKit
import XCTest
@testable import PreStage

final class WaveformServiceTests: XCTestCase {
    func testHorizontalWaveformMapsLeftAndRightImageColumns() throws {
        let buffer = ImageAnalysisBuffer(
            width: 4,
            height: 1,
            pixels: [
                0, 0, 0, 255,
                0, 0, 0, 255,
                255, 255, 255, 255,
                255, 255, 255, 255
            ]
        )

        let waveform = try XCTUnwrap(WaveformService.makeWaveform(from: buffer, direction: .horizontalX, columns: 4, bins: 16))

        XCTAssertEqual(waveform.direction, .horizontalX)
        XCTAssertGreaterThan(waveform.luminance[0][0], 0)
        XCTAssertGreaterThan(waveform.luminance[4][0], 0)
        XCTAssertGreaterThan(waveform.luminance[8][15], 0)
        XCTAssertGreaterThan(waveform.luminance[12][15], 0)
    }

    func testVerticalWaveformMapsTopAndBottomImageRows() throws {
        let buffer = ImageAnalysisBuffer(
            width: 1,
            height: 4,
            pixels: [
                0, 0, 0, 255,
                0, 0, 0, 255,
                255, 255, 255, 255,
                255, 255, 255, 255
            ]
        )

        let waveform = try XCTUnwrap(WaveformService.makeWaveform(from: buffer, direction: .verticalY, columns: 4, bins: 16))

        XCTAssertEqual(waveform.direction, .verticalY)
        XCTAssertGreaterThan(waveform.luminance[0][0], 0)
        XCTAssertGreaterThan(waveform.luminance[4][0], 0)
        XCTAssertGreaterThan(waveform.luminance[8][15], 0)
        XCTAssertGreaterThan(waveform.luminance[12][15], 0)
    }

    func testWaveformServiceCachesDataByFileFingerprint() async throws {
        let root = try TestSupport.temporaryDirectory(named: "waveform")
        let url = root.appendingPathComponent("waveform.png")
        try writeTestImage(to: url)
        let fileSize = Int64((try Data(contentsOf: url)).count)
        let item = TestSupport.mediaItem(url: url, type: .jpeg, fileSize: fileSize)
        let service = WaveformService(columns: 16, bins: 16, maxPixelSize: 32)

        let first = await service.waveform(for: item, previewURL: url, direction: .horizontalX)
        let second = await service.waveform(for: item, previewURL: url, direction: .horizontalX)

        XCTAssertNotNil(first)
        XCTAssertEqual(first, second)
    }

    private func writeTestImage(to url: URL) throws {
        let size = NSSize(width: 4, height: 2)
        let image = NSImage(size: size)
        image.lockFocus()
        NSColor.black.setFill()
        NSRect(x: 0, y: 0, width: 2, height: 2).fill()
        NSColor.white.setFill()
        NSRect(x: 2, y: 0, width: 2, height: 2).fill()
        image.unlockFocus()
        guard let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let data = bitmap.representation(using: .png, properties: [:]) else {
            XCTFail("Could not encode test image.")
            return
        }
        try data.write(to: url)
    }
}
