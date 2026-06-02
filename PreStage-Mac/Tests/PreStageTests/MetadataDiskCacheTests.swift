import XCTest
@testable import PreStage

final class MetadataDiskCacheTests: XCTestCase {
    func testMetadataDiskCachePersistsSnapshotsByFingerprint() async throws {
        let directory = try TestSupport.temporaryDirectory()
        let cacheURL = directory.appendingPathComponent("metadata-cache.json")
        let mediaURL = directory.appendingPathComponent("P1000001.RW2")
        let fingerprint = "\(mediaURL.path)|42|1770000000"

        var loaded = TestSupport.mediaItem(url: mediaURL, type: .raw, fileSize: 42)
        loaded.cameraMake = "Panasonic"
        loaded.cameraModel = "DC-GX9"
        loaded.lensModel = "20mm"
        loaded.focalLength = 20
        loaded.aperture = 1.7
        loaded.shutterSpeed = "1/250"
        loaded.iso = 200
        loaded.pixelWidth = 5184
        loaded.pixelHeight = 3888
        loaded.displayPixelWidth = 768
        loaded.displayPixelHeight = 1024
        loaded.displayRotationDegrees = 90
        loaded.colorSpaceName = "RGB"
        loaded.colorProfileName = "Display P3"

        let cache = MetadataDiskCache(cacheURL: cacheURL)
        await cache.store([(fingerprint, MediaMetadataSnapshot(item: loaded))])

        let reloadedCache = MetadataDiskCache(cacheURL: cacheURL)
        let snapshots = await reloadedCache.snapshots(for: [fingerprint])

        XCTAssertEqual(snapshots[fingerprint]?.cameraModel, "DC-GX9")
        XCTAssertEqual(snapshots[fingerprint]?.pixelWidth, 5184)
        XCTAssertEqual(snapshots[fingerprint]?.displayPixelHeight, 1024)
        XCTAssertEqual(snapshots[fingerprint]?.displayRotationDegrees, 90)
        XCTAssertEqual(snapshots[fingerprint]?.colorProfileName, "Display P3")
    }

    func testMetadataSnapshotPreservesUserEditableFieldsWhenApplied() {
        let baseURL = URL(fileURLWithPath: "/tmp/P1000002.JPG")
        var base = TestSupport.mediaItem(url: baseURL, type: .jpeg)
        base.rating = 4
        base.colorLabel = .red
        base.pickState = .picked
        base.copyStatus = .copied

        var loaded = base
        loaded.cameraModel = "X-T5"
        loaded.pixelWidth = 7728
        loaded.pixelHeight = 5152
        loaded.displayPixelWidth = 1024
        loaded.displayPixelHeight = 683
        loaded.displayRotationDegrees = 270
        loaded.rating = 0
        loaded.colorLabel = nil
        loaded.pickState = .unmarked
        loaded.copyStatus = .notCopied

        let applied = MediaMetadataSnapshot(item: loaded).applying(to: base)

        XCTAssertEqual(applied.cameraModel, "X-T5")
        XCTAssertEqual(applied.pixelWidth, 7728)
        XCTAssertEqual(applied.displayPixelWidth, 1024)
        XCTAssertEqual(applied.displayRotationDegrees, 270)
        XCTAssertEqual(applied.rating, 4)
        XCTAssertEqual(applied.colorLabel, .red)
        XCTAssertEqual(applied.pickState, .picked)
        XCTAssertEqual(applied.copyStatus, .copied)
    }
}
