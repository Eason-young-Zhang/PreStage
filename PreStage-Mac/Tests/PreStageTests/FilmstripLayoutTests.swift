import AppKit
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import XCTest
@testable import PreStage

final class FilmstripLayoutTests: XCTestCase {
    func testFilmstripReloadKeysChangeWhenImageDimensionsArrive() throws {
        let directory = try TestSupport.temporaryDirectory(named: "filmstrip layout")
        var item = TestSupport.mediaItem(url: directory.appendingPathComponent("P1110030.RW2"))

        let initialKeys = NativeFilmstripView.Coordinator.reloadKeys(
            for: [item],
            transforms: [:],
            titleProvider: \.filename
        )

        item.pixelWidth = 3888
        item.pixelHeight = 5184
        item.displayPixelWidth = 3888
        item.displayPixelHeight = 5184
        item.displayRotationDegrees = 90
        let dimensionKeys = NativeFilmstripView.Coordinator.reloadKeys(
            for: [item],
            transforms: [:],
            titleProvider: \.filename
        )

        XCTAssertNotEqual(initialKeys, dimensionKeys)
        XCTAssertTrue(dimensionKeys.first?.contains("3888x5184") == true)
        XCTAssertTrue(dimensionKeys.first?.contains("display:3888x5184") == true)
        XCTAssertTrue(dimensionKeys.first?.contains("orientation:90") == true)
    }

    func testFilmstripAspectRatioUsesDisplayOrientationAndManualRotation() throws {
        let directory = try TestSupport.temporaryDirectory(named: "filmstrip orientation")
        var item = TestSupport.mediaItem(url: directory.appendingPathComponent("P1110031.DNG"))
        item.pixelWidth = 5184
        item.pixelHeight = 3888

        XCTAssertEqual(
            FilmstripFlowLayout.displayAspectRatio(for: item, transform: MediaTransform()),
            4.0 / 3.0,
            accuracy: 0.001
        )

        item.displayRotationDegrees = 90
        XCTAssertEqual(
            FilmstripFlowLayout.displayAspectRatio(for: item, transform: MediaTransform()),
            3.0 / 4.0,
            accuracy: 0.001
        )

        XCTAssertEqual(
            FilmstripFlowLayout.displayAspectRatio(for: item, transform: MediaTransform(rotationDegrees: 90)),
            4.0 / 3.0,
            accuracy: 0.001
        )
    }

    func testFilmstripAspectRatioPrefersActualPreviewDimensions() throws {
        let directory = try TestSupport.temporaryDirectory(named: "filmstrip preview dimensions")
        var item = TestSupport.mediaItem(url: directory.appendingPathComponent("DJI_20260519194113_0388_D.DNG"))
        item.pixelWidth = 8192
        item.pixelHeight = 6144
        item.displayPixelWidth = 768
        item.displayPixelHeight = 1024

        XCTAssertEqual(
            FilmstripFlowLayout.displayAspectRatio(for: item, transform: MediaTransform()),
            0.75,
            accuracy: 0.001
        )
    }

    func testPreviewOverlayGeometryUsesActualPreviewDimensions() throws {
        let directory = try TestSupport.temporaryDirectory(named: "overlay preview dimensions")
        var item = TestSupport.mediaItem(url: directory.appendingPathComponent("DJI_20260519194113_0388_D.DNG"))
        item.pixelWidth = 8192
        item.pixelHeight = 6144
        item.displayPixelWidth = 768
        item.displayPixelHeight = 1024

        let rect = PreviewOverlayGeometry.previewImageRect(for: item, in: CGSize(width: 1200, height: 900))

        XCTAssertEqual(rect.width, 676, accuracy: 0.001)
        XCTAssertEqual(rect.height, 900, accuracy: 0.001)
        XCTAssertEqual(rect.minX, 262, accuracy: 0.001)
    }

    func testPreviewOverlayGeometryUsesPreviewSourceAspectWhenProxyDiffers() throws {
        let directory = try TestSupport.temporaryDirectory(named: "overlay preview source")
        let proxyURL = directory.appendingPathComponent("proxy.jpg")
        try writeTestJPEG(width: 1200, height: 600, to: proxyURL)

        var item = TestSupport.mediaItem(url: directory.appendingPathComponent("DJI_20260519194113_0388_D.DNG"))
        item.pixelWidth = 8192
        item.pixelHeight = 6144
        item.displayPixelWidth = 8192
        item.displayPixelHeight = 6144

        let rect = PreviewOverlayGeometry.previewImageRect(for: item, previewURL: proxyURL, in: CGSize(width: 1200, height: 900))

        XCTAssertEqual(rect.width, 1200, accuracy: 0.001)
        XCTAssertEqual(rect.height, 600, accuracy: 0.001)
        XCTAssertEqual(rect.minX, 0, accuracy: 0.001)
        XCTAssertEqual(rect.minY, 150, accuracy: 0.001)
    }

    func testCropMaskRectsOverlapCropBoundaryToAvoidBrightSlivers() {
        let imageRect = CGRect(x: 0, y: 0, width: 1200, height: 600)
        let cropRect = PreviewRenderGeometry.cropRect(in: imageRect, aspectRatio: 4.0 / 3.0, scale: 2)
        let maskRects = PreviewRenderGeometry.maskRects(imageRect: imageRect, cropRect: cropRect, scale: 2)

        XCTAssertTrue(maskRects.contains { $0.minX <= imageRect.minX && $0.maxX >= cropRect.minX })
        XCTAssertTrue(maskRects.contains { $0.minX <= cropRect.maxX && $0.maxX >= imageRect.maxX })
    }

    func testCropMaskRectsCoverTopAndBottomWithoutGapsForUltraWideCrop() {
        let imageRect = CGRect(x: 0, y: 0, width: 1200, height: 600)
        let cropRect = PreviewRenderGeometry.cropRect(in: imageRect, aspectRatio: 3, scale: 2)
        let maskRects = PreviewRenderGeometry.maskRects(imageRect: imageRect, cropRect: cropRect, scale: 2)

        XCTAssertTrue(maskRects.contains { $0.minY <= imageRect.minY && $0.maxY >= cropRect.minY })
        XCTAssertTrue(maskRects.contains { $0.minY <= cropRect.maxY && $0.maxY >= imageRect.maxY })
    }

    func testFilmstripItemWidthCanUseRenderedThumbnailAspectRatio() throws {
        let directory = try TestSupport.temporaryDirectory(named: "filmstrip rendered aspect")
        var item = TestSupport.mediaItem(url: directory.appendingPathComponent("DJI_20260108160127_0043_D.JPG"))
        item.pixelWidth = 12000
        item.pixelHeight = 6000
        item.displayPixelWidth = 12000
        item.displayPixelHeight = 6000

        let collectionView = NSCollectionView(frame: NSRect(x: 0, y: 0, width: 900, height: 120))
        let layout = FilmstripFlowLayout()
        layout.sectionInset = NSEdgeInsets(top: 10, left: 12, bottom: 10, right: 12)
        collectionView.collectionViewLayout = layout

        let metadataSize = FilmstripFlowLayout.itemSize(for: item, transform: MediaTransform(), in: collectionView)
        let renderedSize = FilmstripFlowLayout.itemSize(
            for: item,
            transform: MediaTransform(),
            renderedAspectRatio: 1.6,
            in: collectionView
        )

        XCTAssertLessThan(renderedSize.width, metadataSize.width)
    }

    private func writeTestJPEG(width: Int, height: Int, to url: URL) throws {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            XCTFail("Could not create test image context")
            return
        }
        context.setFillColor(CGColor(red: 0.2, green: 0.4, blue: 0.6, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        guard let image = context.makeImage(),
              let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.jpeg.identifier as CFString, 1, nil) else {
            XCTFail("Could not create test JPEG")
            return
        }
        CGImageDestinationAddImage(destination, image, nil)
        XCTAssertTrue(CGImageDestinationFinalize(destination))
    }
}
