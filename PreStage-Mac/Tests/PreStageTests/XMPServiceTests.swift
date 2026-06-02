import XCTest
@testable import PreStage

final class XMPServiceTests: XCTestCase {
    func testApplySidecarReadsRatingColorLabelAndLegacyPickState() throws {
        let root = try TestSupport.temporaryDirectory(named: "xmp-read")
        let mediaURL = root.appendingPathComponent("IMG_0001.RW2")
        let sidecarURL = root.appendingPathComponent("IMG_0001.xmp")
        try TestSupport.writeFile(mediaURL)
        try TestSupport.writeFile(sidecarURL, contents: """
        <?xml version="1.0" encoding="UTF-8"?>
        <x:xmpmeta xmlns:x="adobe:ns:meta/">
          <rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
            <rdf:Description
              xmlns:xmp="http://ns.adobe.com/xap/1.0/"
              xmlns:photocopy="https://local.codex/photocopy/1.0/"
              xmp:Rating="7"
              xmp:Label="蓝色"
              photocopy:PickState="rejected" />
          </rdf:RDF>
        </x:xmpmeta>
        """)

        let item = TestSupport.mediaItem(url: mediaURL, type: .raw)
        let updated = XMPService().applySidecarMetadata(to: item)

        XCTAssertEqual(updated.rating, 5)
        XCTAssertEqual(updated.colorLabel, .blue)
        XCTAssertEqual(updated.pickState, .rejected)
        XCTAssertEqual(updated.xmpStatus, .sidecarFound)
    }

    func testWriteSidecarPreservesUnknownXMLAndUsesLanguageIndependentLabel() throws {
        let root = try TestSupport.temporaryDirectory(named: "xmp-write")
        let mediaURL = root.appendingPathComponent("IMG_0002.RW2")
        let sidecarURL = root.appendingPathComponent("IMG_0002.xmp")
        try TestSupport.writeFile(mediaURL)
        try TestSupport.writeFile(sidecarURL, contents: """
        <?xml version="1.0" encoding="UTF-8"?>
        <x:xmpmeta xmlns:x="adobe:ns:meta/">
          <rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
            <rdf:Description
              xmlns:xmp="http://ns.adobe.com/xap/1.0/"
              xmlns:custom="https://example.com/custom/1.0/"
              xmlns:photocopy="https://local.codex/photocopy/1.0/"
              xmp:Rating="1"
              custom:Keep="yes"
              photocopy:PickState="rejected">
              <custom:Nested>keep-me</custom:Nested>
            </rdf:Description>
          </rdf:RDF>
        </x:xmpmeta>
        """)

        var item = TestSupport.mediaItem(url: mediaURL, type: .raw)
        item.rating = 4
        item.colorLabel = .blue
        item.pickState = .picked

        try XMPService().writeSidecar(for: item)

        let text = try String(contentsOf: sidecarURL, encoding: .utf8)
        XCTAssertTrue(text.contains("custom:Keep=\"yes\""))
        XCTAssertTrue(text.contains("keep-me"))
        XCTAssertTrue(text.contains("xmp:Rating=\"4\""))
        XCTAssertTrue(text.contains("xmp:Label=\"Blue\""))
        XCTAssertTrue(text.contains("prestage:PickState=\"picked\""))
        XCTAssertFalse(text.contains("photocopy:PickState=\"rejected\""))
    }

    func testReadsLightroomRejectedRatingAsPickReject() throws {
        let root = try TestSupport.temporaryDirectory(named: "xmp-lightroom-rejected")
        let mediaURL = root.appendingPathComponent("LR_0001.CR3")
        let sidecarURL = root.appendingPathComponent("LR_0001.xmp")
        try TestSupport.writeFile(mediaURL)
        try TestSupport.writeFile(sidecarURL, contents: """
        <?xml version="1.0" encoding="UTF-8"?>
        <x:xmpmeta xmlns:x="adobe:ns:meta/">
          <rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
            <rdf:Description
              xmlns:xmp="http://ns.adobe.com/xap/1.0/"
              xmp:CreatorTool="Adobe Photoshop Lightroom Classic"
              xmp:Rating="-1"
              xmp:Label="Yellow" />
          </rdf:RDF>
        </x:xmpmeta>
        """)

        let item = TestSupport.mediaItem(url: mediaURL, type: .raw)
        let updated = XMPService().applySidecarMetadata(to: item)

        XCTAssertEqual(updated.rating, 0)
        XCTAssertEqual(updated.pickState, .rejected)
        XCTAssertEqual(updated.colorLabel, .yellow)
        XCTAssertEqual(updated.xmpStatus, .sidecarFound)
    }

    func testReadsElementFormXMPValues() throws {
        let root = try TestSupport.temporaryDirectory(named: "xmp-element-form")
        let mediaURL = root.appendingPathComponent("C1_0001.RAF")
        let sidecarURL = root.appendingPathComponent("C1_0001.xmp")
        try TestSupport.writeFile(mediaURL)
        try TestSupport.writeFile(sidecarURL, contents: """
        <?xml version="1.0" encoding="UTF-8"?>
        <x:xmpmeta xmlns:x="adobe:ns:meta/">
          <rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
            <rdf:Description
              xmlns:xmp="http://ns.adobe.com/xap/1.0/"
              xmlns:prestage="https://local.codex/prestage/1.0/">
              <xmp:Rating>3</xmp:Rating>
              <xmp:Label>Green</xmp:Label>
              <prestage:PickState>picked</prestage:PickState>
            </rdf:Description>
          </rdf:RDF>
        </x:xmpmeta>
        """)

        let item = TestSupport.mediaItem(url: mediaURL, type: .raw)
        let updated = XMPService().applySidecarMetadata(to: item)

        XCTAssertEqual(updated.rating, 3)
        XCTAssertEqual(updated.pickState, .picked)
        XCTAssertEqual(updated.colorLabel, .green)
    }

    func testWriteSidecarPreservesExistingCreatorTool() throws {
        let root = try TestSupport.temporaryDirectory(named: "xmp-preserve-creator")
        let mediaURL = root.appendingPathComponent("C1_0002.NEF")
        let sidecarURL = root.appendingPathComponent("C1_0002.xmp")
        try TestSupport.writeFile(mediaURL)
        try TestSupport.writeFile(sidecarURL, contents: """
        <?xml version="1.0" encoding="UTF-8"?>
        <x:xmpmeta xmlns:x="adobe:ns:meta/">
          <rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
            <rdf:Description
              xmlns:xmp="http://ns.adobe.com/xap/1.0/"
              xmlns:crs="http://ns.adobe.com/camera-raw-settings/1.0/"
              xmp:CreatorTool="Capture One"
              crs:Version="17.3"
              xmp:Rating="2" />
          </rdf:RDF>
        </x:xmpmeta>
        """)

        var item = TestSupport.mediaItem(url: mediaURL, type: .raw)
        item.rating = 5
        item.colorLabel = .purple
        item.pickState = .picked

        try XMPService().writeSidecar(for: item)

        let text = try String(contentsOf: sidecarURL, encoding: .utf8)
        XCTAssertTrue(text.contains("xmp:CreatorTool=\"Capture One\""))
        XCTAssertTrue(text.contains("crs:Version=\"17.3\""))
        XCTAssertTrue(text.contains("xmp:Rating=\"5\""))
        XCTAssertTrue(text.contains("xmp:Label=\"Purple\""))
    }

    func testMalformedExistingSidecarMarksConflictAndIsNotOverwritten() throws {
        let root = try TestSupport.temporaryDirectory(named: "xmp-malformed")
        let mediaURL = root.appendingPathComponent("BAD_0001.ARW")
        let sidecarURL = root.appendingPathComponent("BAD_0001.xmp")
        try TestSupport.writeFile(mediaURL)
        try TestSupport.writeFile(sidecarURL, contents: "<x:xmpmeta><broken>")

        let item = TestSupport.mediaItem(url: mediaURL, type: .raw)
        let updated = XMPService().applySidecarMetadata(to: item)

        XCTAssertEqual(updated.xmpStatus, .conflict)
        XCTAssertThrowsError(try XMPService().writeSidecar(for: item))
        XCTAssertEqual(try String(contentsOf: sidecarURL, encoding: .utf8), "<x:xmpmeta><broken>")
    }
}
