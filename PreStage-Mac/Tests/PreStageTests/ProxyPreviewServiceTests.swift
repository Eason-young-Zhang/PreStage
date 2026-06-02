import ImageIO
import UniformTypeIdentifiers
import XCTest
@testable import PreStage

final class ProxyPreviewServiceTests: XCTestCase {
    func testScannerExcludesGeneratedProxyFolder() throws {
        let root = try TestSupport.temporaryDirectory(named: "scanner-proxy-exclusion")
        try TestSupport.writeFile(root.appendingPathComponent("Original.JPG"))
        try TestSupport.writeFile(
            root
                .appendingPathComponent(ProxyGenerationService.proxyFolderName, isDirectory: true)
                .appendingPathComponent("Original-proxy.jpg")
        )

        let items = try MediaScanner().scan(directory: root, recursive: true)

        XCTAssertEqual(items.map(\.filename), ["Original.JPG"])
    }

    func testScannerIncludesOlympusRawFiles() throws {
        let root = try TestSupport.temporaryDirectory(named: "scanner-orf")
        try TestSupport.writeFile(root.appendingPathComponent("Olympus.ORF"))

        let items = try MediaScanner().scan(directory: root, recursive: false)

        XCTAssertEqual(items.map(\.filename), ["Olympus.ORF"])
        XCTAssertEqual(items.first?.mediaType, .raw)
    }

    func testValidProxyURLRequiresProxyAtLeastAsFreshAsSource() throws {
        let root = try TestSupport.temporaryDirectory(named: "proxy-validity")
        let sourceURL = root.appendingPathComponent("RAWOnly.RW2")
        try TestSupport.writeFile(sourceURL)
        let sourceModified = TestSupport.date(2026, 5, 20)
        try setModifiedDate(sourceModified, for: sourceURL)

        var item = TestSupport.mediaItem(
            url: sourceURL,
            type: .raw,
            modifiedDate: sourceModified
        )
        let service = ProxyGenerationService()
        let proxyURL = service.proxyURL(for: sourceURL, sourceRoot: root)
        try TestSupport.writeFile(proxyURL)

        try setModifiedDate(TestSupport.date(2026, 5, 19), for: proxyURL)
        XCTAssertNil(service.validProxyURL(for: item, sourceRoot: root))

        try setModifiedDate(TestSupport.date(2026, 5, 21), for: proxyURL)
        XCTAssertEqual(service.validProxyURL(for: item, sourceRoot: root), proxyURL)

        item.modifiedDate = nil
        XCTAssertEqual(service.validProxyURL(for: item, sourceRoot: root), proxyURL)
    }

    func testProxyURLPreservesRelativeFolderStructure() throws {
        let root = URL(fileURLWithPath: "/tmp/card/DCIM")
        let sourceURL = root
            .appendingPathComponent("101PANA", isDirectory: true)
            .appendingPathComponent("P1110163.RW2")

        let proxyURL = ProxyGenerationService().proxyURL(for: sourceURL, sourceRoot: root)

        XCTAssertEqual(
            proxyURL.path,
            "/tmp/card/DCIM/\(ProxyGenerationService.proxyFolderName)/101PANA/P1110163-proxy.jpg"
        )
    }

    func testPrepareProxyIfNeededCreatesThenSkipsFreshProxy() throws {
        let root = try TestSupport.temporaryDirectory(named: "proxy-preparation")
        let sourceURL = root.appendingPathComponent("Original.JPG")
        try writeTinyJPEG(sourceURL)
        let fileSize = Int64((try sourceURL.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
        let modifiedDate = Date()
        try setModifiedDate(modifiedDate, for: sourceURL)

        let item = TestSupport.mediaItem(
            url: sourceURL,
            type: .jpeg,
            fileSize: fileSize,
            modifiedDate: modifiedDate
        )
        let service = ProxyGenerationService()

        let created = try service.prepareProxyIfNeeded(for: item, sourceRoot: root)
        guard case .created(let proxyURL) = created else {
            return XCTFail("Expected proxy creation on first preparation.")
        }
        XCTAssertTrue(FileManager.default.fileExists(atPath: proxyURL.path))

        let skipped = try service.prepareProxyIfNeeded(for: item, sourceRoot: root)
        XCTAssertEqual(skipped, .skipped(proxyURL))
    }

    private func setModifiedDate(_ date: Date, for url: URL) throws {
        try FileManager.default.setAttributes([.modificationDate: date], ofItemAtPath: url.path)
    }

    private func writeTinyJPEG(_ url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let width = 2
        let height = 2
        var pixels: [UInt8] = [
            255, 0, 0, 255,
            0, 255, 0, 255,
            0, 0, 255, 255,
            255, 255, 255, 255
        ]
        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ),
            let image = context.makeImage(),
            let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.jpeg.identifier as CFString, 1, nil) else {
            throw NSError(domain: "PreStageTests", code: 1)
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else {
            throw NSError(domain: "PreStageTests", code: 2)
        }
    }
}
