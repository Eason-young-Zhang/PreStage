import XCTest
@testable import PreStage

final class CopyServiceTests: XCTestCase {
    func testCopiesIntoAllOrganizationRuleDestinations() async throws {
        let root = try TestSupport.temporaryDirectory(named: "copy-rules")
        let sourceRoot = root.appendingPathComponent("source", isDirectory: true)
        let sourceFolder = sourceRoot.appendingPathComponent("Session", isDirectory: true)
        let target = root.appendingPathComponent("target", isDirectory: true)
        let sourceFile = sourceFolder.appendingPathComponent("IMG_0001.RW2")
        try TestSupport.writeFile(sourceFile, contents: "abc")

        var item = TestSupport.mediaItem(
            url: sourceFile,
            type: .raw,
            fileSize: 3,
            captureDate: TestSupport.date(2026, 5, 3)
        )
        item.cameraModel = "Canon/R5:II"
        item.rating = 4

        let service = CopyService()
        await service.copyItems([item], to: target, sourceRoot: sourceRoot, rule: .captureDate, conflictPolicy: .autoRename, control: CopyOperationControl()) { _, _, _ in }
        await service.copyItems([item], to: target, sourceRoot: sourceRoot, rule: .preserveStructure, conflictPolicy: .autoRename, control: CopyOperationControl()) { _, _, _ in }
        await service.copyItems([item], to: target, sourceRoot: sourceRoot, rule: .cameraModel, conflictPolicy: .autoRename, control: CopyOperationControl()) { _, _, _ in }
        await service.copyItems([item], to: target, sourceRoot: sourceRoot, rule: .rating, conflictPolicy: .autoRename, control: CopyOperationControl()) { _, _, _ in }

        XCTAssertTrue(FileManager.default.fileExists(atPath: target.appendingPathComponent("2026-05-03/IMG_0001.RW2").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: target.appendingPathComponent("Session/IMG_0001.RW2").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: target.appendingPathComponent("Canon-R5-II/IMG_0001.RW2").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: target.appendingPathComponent("4-Star/IMG_0001.RW2").path))
    }

    func testCopiesSidecarAndAutoRenamesWhenDestinationExists() async throws {
        let root = try TestSupport.temporaryDirectory(named: "copy-conflict")
        let sourceRoot = root.appendingPathComponent("source", isDirectory: true)
        let target = root.appendingPathComponent("target", isDirectory: true)
        let sourceFile = sourceRoot.appendingPathComponent("IMG_0001.RW2")
        let sourceSidecar = sourceRoot.appendingPathComponent("IMG_0001.xmp")
        try TestSupport.writeFile(sourceFile, contents: "abc")
        try TestSupport.writeFile(sourceSidecar, contents: "<xmp>sidecar</xmp>")

        let item = TestSupport.mediaItem(
            url: sourceFile,
            type: .raw,
            fileSize: 3,
            captureDate: TestSupport.date(2026, 5, 3)
        )
        let destinationFolder = target.appendingPathComponent("2026-05-03", isDirectory: true)
        try TestSupport.writeFile(destinationFolder.appendingPathComponent("IMG_0001.RW2"), contents: "existing")

        await CopyService().copyItems([item], to: target, sourceRoot: sourceRoot, rule: .captureDate, conflictPolicy: .autoRename, control: CopyOperationControl()) { _, _, _ in }

        XCTAssertTrue(FileManager.default.fileExists(atPath: destinationFolder.appendingPathComponent("IMG_0001 2.RW2").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: destinationFolder.appendingPathComponent("IMG_0001 2.xmp").path))
    }

    func testCancelledCopyStopsBeforeCopyingQueuedItems() async throws {
        let root = try TestSupport.temporaryDirectory(named: "copy-cancel")
        let sourceRoot = root.appendingPathComponent("source", isDirectory: true)
        let target = root.appendingPathComponent("target", isDirectory: true)
        let sourceFile = sourceRoot.appendingPathComponent("IMG_0001.RW2")
        try TestSupport.writeFile(sourceFile, contents: "abc")
        let item = TestSupport.mediaItem(url: sourceFile, type: .raw, fileSize: 3)
        let control = CopyOperationControl()
        await control.cancel()

        var finalProgress = CopyProgress()
        var statuses: [CopyStatus] = []
        await CopyService().copyItems([item], to: target, sourceRoot: sourceRoot, rule: .captureDate, conflictPolicy: .autoRename, control: control) { progress, _, status in
            finalProgress = progress
            if let status {
                statuses.append(status)
            }
        }

        XCTAssertTrue(finalProgress.isCancelled)
        XCTAssertTrue(statuses.contains(.queued))
        XCTAssertTrue(statuses.contains(.cancelled))
        XCTAssertFalse(FileManager.default.fileExists(atPath: target.appendingPathComponent("2026-05-03/IMG_0001.RW2").path))
    }

    func testSHA256VerificationMarksSuccessfulCopyAsVerified() async throws {
        let root = try TestSupport.temporaryDirectory(named: "copy-hash-verified")
        let sourceRoot = root.appendingPathComponent("source", isDirectory: true)
        let target = root.appendingPathComponent("target", isDirectory: true)
        let sourceFile = sourceRoot.appendingPathComponent("IMG_0001.RW2")
        try TestSupport.writeFile(sourceFile, contents: "hash-me")
        let item = TestSupport.mediaItem(url: sourceFile, type: .raw, fileSize: 7)

        var statuses: [CopyStatus] = []
        var finalProgress = CopyProgress()
        await CopyService().copyItems(
            [item],
            to: target,
            sourceRoot: sourceRoot,
            rule: .captureDate,
            conflictPolicy: .autoRename,
            verificationMode: .sha256,
            control: CopyOperationControl()
        ) { progress, _, status in
            finalProgress = progress
            if let status {
                statuses.append(status)
            }
        }

        XCTAssertTrue(statuses.contains(.queued))
        XCTAssertTrue(statuses.contains(.copied))
        XCTAssertTrue(statuses.contains(.verified))
        XCTAssertTrue(finalProgress.message.contains("SHA-256"))
    }

    func testSHA256VerificationFailsWhenExpectedSizeDoesNotMatch() async throws {
        let root = try TestSupport.temporaryDirectory(named: "copy-hash-failed")
        let sourceRoot = root.appendingPathComponent("source", isDirectory: true)
        let target = root.appendingPathComponent("target", isDirectory: true)
        let sourceFile = sourceRoot.appendingPathComponent("IMG_0002.RW2")
        try TestSupport.writeFile(sourceFile, contents: "hash-me")
        let item = TestSupport.mediaItem(url: sourceFile, type: .raw, fileSize: 99)

        var statuses: [CopyStatus] = []
        await CopyService().copyItems(
            [item],
            to: target,
            sourceRoot: sourceRoot,
            rule: .captureDate,
            conflictPolicy: .autoRename,
            verificationMode: .sha256,
            control: CopyOperationControl()
        ) { _, _, status in
            if let status {
                statuses.append(status)
            }
        }

        XCTAssertTrue(statuses.contains(.failed))
    }

    func testCopyContentModeCanLimitToRawFiles() {
        let raw = TestSupport.mediaItem(url: URL(fileURLWithPath: "/tmp/copy/IMG_0001.RW2"), type: .raw)
        let jpeg = TestSupport.mediaItem(url: URL(fileURLWithPath: "/tmp/copy/IMG_0001.JPG"), type: .jpeg)

        XCTAssertTrue(CopyContentMode.allSupported.includes(raw))
        XCTAssertTrue(CopyContentMode.allSupported.includes(jpeg))
        XCTAssertTrue(CopyContentMode.rawOnly.includes(raw))
        XCTAssertFalse(CopyContentMode.rawOnly.includes(jpeg))
    }

    func testCopyVerificationModeLabels() {
        XCTAssertEqual(CopyVerificationMode.sizeOnly.displayName, L10n.tr("Size Only"))
        XCTAssertEqual(CopyVerificationMode.sha256.displayName, L10n.tr("SHA-256 Hash"))
    }
}
