import XCTest
@testable import PreStage

final class MediaPairingServiceTests: XCTestCase {
    func testAssignsPairingKeyToSameFolderRawAndJPEGWithSameBaseName() {
        let folder = URL(fileURLWithPath: "/tmp/pairing")
        let jpeg = TestSupport.mediaItem(url: folder.appendingPathComponent("P1110156.JPG"), type: .jpeg)
        let raw = TestSupport.mediaItem(url: folder.appendingPathComponent("P1110156.RW2"), type: .raw)
        let unpaired = TestSupport.mediaItem(url: folder.appendingPathComponent("P1110157.JPG"), type: .jpeg)

        let paired = MediaPairingService().assignPairingKeys(to: [jpeg, raw, unpaired])

        XCTAssertEqual(paired[0].pairedAssetKey, folder.appendingPathComponent("P1110156").path)
        XCTAssertEqual(paired[1].pairedAssetKey, folder.appendingPathComponent("P1110156").path)
        XCTAssertNil(paired[2].pairedAssetKey)
    }

    func testDoesNotPairSameBaseNameAcrossDifferentFolders() {
        let jpeg = TestSupport.mediaItem(url: URL(fileURLWithPath: "/tmp/a/P1110156.JPG"), type: .jpeg)
        let raw = TestSupport.mediaItem(url: URL(fileURLWithPath: "/tmp/b/P1110156.RW2"), type: .raw)

        let paired = MediaPairingService().assignPairingKeys(to: [jpeg, raw])

        XCTAssertNil(paired[0].pairedAssetKey)
        XCTAssertNil(paired[1].pairedAssetKey)
    }
}
