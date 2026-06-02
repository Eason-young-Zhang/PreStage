import XCTest
@testable import PreStage

final class BatchRenameServiceTests: XCTestCase {
    func testBatchRenamePlanKeepsPairedRawAndJPEGTogether() throws {
        let root = try TestSupport.temporaryDirectory(named: "batch-rename-pair-plan")
        let rawURL = root.appendingPathComponent("P1000001.RW2")
        let jpegURL = root.appendingPathComponent("P1000001.JPG")
        try TestSupport.writeFile(rawURL)
        try TestSupport.writeFile(jpegURL)

        var raw = TestSupport.mediaItem(url: rawURL, type: .raw)
        var jpeg = TestSupport.mediaItem(url: jpegURL, type: .jpeg)
        raw.pairedAssetKey = "pair"
        jpeg.pairedAssetKey = "pair"

        let plan = BatchRenameService().makePlan(
            items: [raw, jpeg],
            rule: BatchRenameRule(pattern: "Select_{index}", startNumber: 7, digitCount: 3)
        )

        XCTAssertTrue(plan.issues.isEmpty)
        XCTAssertEqual(Set(plan.entries.map { $0.destinationURL.lastPathComponent }), ["Select_007.rw2", "Select_007.jpg"])
        XCTAssertEqual(Set(plan.entries.map(\.sequenceNumber)), [7])
    }

    func testBatchRenameDetectsDuplicateDestinations() throws {
        let root = try TestSupport.temporaryDirectory(named: "batch-rename-duplicates")
        let firstURL = root.appendingPathComponent("A.JPG")
        let secondURL = root.appendingPathComponent("B.JPG")
        try TestSupport.writeFile(firstURL)
        try TestSupport.writeFile(secondURL)

        let first = TestSupport.mediaItem(url: firstURL, type: .jpeg)
        let second = TestSupport.mediaItem(url: secondURL, type: .jpeg)
        let plan = BatchRenameService().makePlan(
            items: [first, second],
            rule: BatchRenameRule(pattern: "Same", startNumber: 1, digitCount: 2)
        )

        XCTAssertFalse(plan.issues.isEmpty)
        XCTAssertTrue(plan.issues.contains { $0.message.contains("Same.jpg") })
    }

    func testBatchRenameSupportsMetadataTokensAndCleanupOptions() throws {
        let root = try TestSupport.temporaryDirectory(named: "batch rename metadata")
        let mediaURL = root.appendingPathComponent("Original File.JPG")
        try TestSupport.writeFile(mediaURL)

        var item = TestSupport.mediaItem(
            url: mediaURL,
            type: .jpeg,
            captureDate: Calendar.current.date(from: DateComponents(year: 2024, month: 1, day: 1, hour: 12, minute: 30, second: 45))
        )
        item.cameraModel = "DC GX9"
        item.lensModel = "Prime 20"
        item.rating = 4

        let plan = BatchRenameService().makePlan(
            items: [item],
            rule: BatchRenameRule(
                pattern: "{date}_{time}_{camera}_{lens}_{folder}_{rating}_{index}",
                startNumber: 3,
                digitCount: 2,
                letterCase: .lowercase,
                replaceWhitespace: true
            )
        )

        XCTAssertTrue(plan.issues.isEmpty)
        XCTAssertEqual(plan.entries.first?.destinationURL.lastPathComponent, "2024-01-01_123045_dc-gx9_prime-20_batch-rename-metadata_4_03.jpg")
    }

    func testBatchRenameApplyMovesMediaAndSidecar() throws {
        let root = try TestSupport.temporaryDirectory(named: "batch-rename-apply")
        let mediaURL = root.appendingPathComponent("IMG_0001.RW2")
        let sidecarURL = root.appendingPathComponent("IMG_0001.xmp")
        try TestSupport.writeFile(mediaURL, contents: "raw")
        try TestSupport.writeFile(sidecarURL, contents: "<xmp />")

        let item = TestSupport.mediaItem(url: mediaURL, type: .raw, fileSize: 3)
        let service = BatchRenameService()
        let plan = service.makePlan(
            items: [item],
            rule: BatchRenameRule(pattern: "Renamed_{index}", startNumber: 1, digitCount: 2)
        )

        let result = try service.apply(plan)

        XCTAssertFalse(FileManager.default.fileExists(atPath: mediaURL.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: sidecarURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: root.appendingPathComponent("Renamed_01.rw2").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: root.appendingPathComponent("Renamed_01.xmp").path))
        XCTAssertEqual(result.renamedMediaCount, 1)
        XCTAssertEqual(result.movedFileCount, 2)
        XCTAssertEqual(result.undoActions.count, 2)
    }

    func testBatchRenameUndoRestoresMediaAndSidecar() throws {
        let root = try TestSupport.temporaryDirectory(named: "batch-rename-undo")
        let mediaURL = root.appendingPathComponent("IMG_0002.RW2")
        let sidecarURL = root.appendingPathComponent("IMG_0002.xmp")
        try TestSupport.writeFile(mediaURL, contents: "raw")
        try TestSupport.writeFile(sidecarURL, contents: "<xmp />")

        let item = TestSupport.mediaItem(url: mediaURL, type: .raw, fileSize: 3)
        let service = BatchRenameService()
        let plan = service.makePlan(
            items: [item],
            rule: BatchRenameRule(pattern: "Undoable_{index}", startNumber: 1, digitCount: 2)
        )
        let result = try service.apply(plan)
        let undo = BatchRenameUndoRecord(renamedMediaCount: result.renamedMediaCount, actions: result.undoActions)

        try service.undo(undo)

        XCTAssertTrue(FileManager.default.fileExists(atPath: mediaURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: sidecarURL.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent("Undoable_01.rw2").path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent("Undoable_01.xmp").path))
    }

    func testBatchRenameUndoStopsWhenOriginalNameExists() throws {
        let root = try TestSupport.temporaryDirectory(named: "batch-rename-undo-conflict")
        let mediaURL = root.appendingPathComponent("IMG_0003.RW2")
        try TestSupport.writeFile(mediaURL, contents: "raw")

        let item = TestSupport.mediaItem(url: mediaURL, type: .raw, fileSize: 3)
        let service = BatchRenameService()
        let plan = service.makePlan(
            items: [item],
            rule: BatchRenameRule(pattern: "Conflict_{index}", startNumber: 1, digitCount: 2)
        )
        let result = try service.apply(plan)
        try TestSupport.writeFile(mediaURL, contents: "new")

        XCTAssertThrowsError(try service.undo(BatchRenameUndoRecord(renamedMediaCount: result.renamedMediaCount, actions: result.undoActions)))
        XCTAssertTrue(FileManager.default.fileExists(atPath: root.appendingPathComponent("Conflict_01.rw2").path))
    }
}
