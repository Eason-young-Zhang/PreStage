import AppKit
import XCTest
@testable import PreStage

final class ThumbnailDiskCacheTests: XCTestCase {
    func testStoresReadsAndClearsThumbnailImage() throws {
        let root = try TestSupport.temporaryDirectory(named: "thumbnail-cache")
        let cache = ThumbnailDiskCache(directoryURL: root, maxBytes: 10 * 1024 * 1024, maxAge: 60 * 60)
        let item = TestSupport.mediaItem(
            url: URL(fileURLWithPath: "/tmp/thumb/IMG_0001.JPG"),
            type: .jpeg,
            fileSize: 2048,
            modifiedDate: TestSupport.date(2026, 5, 10)
        )
        let key = cache.key(for: item, quantizedWidth: 128, quantizedHeight: 128)

        cache.store(testImage(), for: key)

        XCTAssertNotNil(cache.image(for: key))
        XCTAssertGreaterThan(cache.totalSize(), 0)

        cache.removeAll()

        XCTAssertNil(cache.image(for: key))
        XCTAssertEqual(cache.totalSize(), 0)
    }

    func testCacheKeyChangesWhenSourceFileFingerprintChanges() throws {
        let root = try TestSupport.temporaryDirectory(named: "thumbnail-cache-key")
        let cache = ThumbnailDiskCache(directoryURL: root, maxBytes: 10 * 1024 * 1024, maxAge: 60 * 60)
        let url = URL(fileURLWithPath: "/tmp/thumb/IMG_0001.JPG")
        let original = TestSupport.mediaItem(
            url: url,
            type: .jpeg,
            fileSize: 2048,
            modifiedDate: TestSupport.date(2026, 5, 10)
        )
        let changed = TestSupport.mediaItem(
            url: url,
            type: .jpeg,
            fileSize: 4096,
            modifiedDate: TestSupport.date(2026, 5, 11)
        )

        XCTAssertNotEqual(
            cache.key(for: original, quantizedWidth: 128, quantizedHeight: 128),
            cache.key(for: changed, quantizedWidth: 128, quantizedHeight: 128)
        )
    }

    func testTrimRemovesOldestFilesWhenCacheExceedsLimit() throws {
        let root = try TestSupport.temporaryDirectory(named: "thumbnail-cache-trim")
        let cache = ThumbnailDiskCache(directoryURL: root, maxBytes: 10 * 1024 * 1024, maxAge: 60 * 60)
        let oldKey = "old"
        let newKey = "new"

        cache.store(testImage(width: 160, height: 160), for: oldKey)
        cache.store(testImage(width: 160, height: 160), for: newKey)
        try FileManager.default.setAttributes(
            [.modificationDate: Date(timeIntervalSince1970: 1)],
            ofItemAtPath: root.appendingPathComponent(oldKey).appendingPathExtension("jpg").path
        )
        let newFileSize = try root
            .appendingPathComponent(newKey)
            .appendingPathExtension("jpg")
            .resourceValues(forKeys: [.fileSizeKey])
            .fileSize ?? 1

        let trimmingCache = ThumbnailDiskCache(directoryURL: root, maxBytes: Int64(newFileSize), maxAge: 60 * 60)
        trimmingCache.trimIfNeeded(now: Date())

        XCTAssertNil(trimmingCache.image(for: oldKey))
        XCTAssertNotNil(trimmingCache.image(for: newKey))
    }

    private func testImage(width: Int = 32, height: Int = 32) -> NSImage {
        let image = NSImage(size: NSSize(width: width, height: height))
        image.lockFocus()
        NSColor.systemBlue.setFill()
        NSRect(x: 0, y: 0, width: width, height: height).fill()
        image.unlockFocus()
        return image
    }
}
