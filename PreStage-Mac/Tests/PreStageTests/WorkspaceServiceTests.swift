import XCTest
@testable import PreStage

final class WorkspaceServiceTests: XCTestCase {
    func testSavesAndLoadsWorkspaceLibraryWithActivePreset() throws {
        let defaults = try temporaryDefaults()
        let service = WorkspaceService(defaults: defaults)
        var first = preset(name: "First")
        first.batchRenameLogs = [
            BatchRenameLogRecord(
                id: UUID(),
                createdAt: Date(),
                sourcePath: "/tmp/source",
                totalItems: 1,
                entries: [
                    BatchRenameLogEntry(id: UUID(), originalName: "A.RW2", newName: "B.RW2", folderPath: "/tmp/source")
                ]
            )
        ]
        let second = preset(name: "Second", action: .selectAndScan)
        let library = WorkspaceLibrary(activePresetID: second.id, presets: [first, second])

        service.saveLibrary(library)
        let loaded = service.loadLibrary()

        XCTAssertEqual(loaded.activePresetID, second.id)
        XCTAssertEqual(loaded.presets.map(\.name), ["First", "Second"])
        XCTAssertEqual(loaded.presets.first?.batchRenameLogs.first?.entries.first?.newName, "B.RW2")
        XCTAssertEqual(service.load().name, "Second")
        XCTAssertEqual(service.load().cameraCardAction, .selectAndScan)
    }

    func testMigratesLegacyDefaultPresetIntoLibrary() throws {
        let defaults = try temporaryDefaults()
        let legacy = preset(name: "Legacy", action: .selectDCIM)
        let data = try JSONEncoder().encode(legacy)
        defaults.set(data, forKey: "PreStage.workspace.default")
        let service = WorkspaceService(defaults: defaults)

        let loaded = service.loadLibrary()

        XCTAssertEqual(loaded.activePresetID, legacy.id)
        XCTAssertEqual(loaded.presets.count, 1)
        XCTAssertEqual(loaded.presets.first?.name, "Legacy")
        XCTAssertEqual(loaded.presets.first?.cameraCardAction, .selectDCIM)
    }

    func testWorkspacePresetDecodesMissingRecentFieldsWithDefaults() throws {
        let oldPreset = preset(name: "Old", action: .selectAndScan)
        let encoded = try JSONEncoder().encode(oldPreset)
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        object.removeValue(forKey: "cameraCardAction")
        object.removeValue(forKey: "copyContentMode")
        object.removeValue(forKey: "copyVerificationMode")
        object.removeValue(forKey: "batchRenameLogs")
        let legacyData = try JSONSerialization.data(withJSONObject: object)

        let preset = try JSONDecoder().decode(WorkspacePreset.self, from: legacyData)

        XCTAssertEqual(preset.cameraCardAction, .notify)
        XCTAssertEqual(preset.copyContentMode, .allSupported)
        XCTAssertEqual(preset.copyVerificationMode, .sizeOnly)
        XCTAssertTrue(preset.batchRenameLogs.isEmpty)
    }

    func testPanelLayoutDecodesMissingHistogramFieldsWithDefaults() throws {
        let encoded = try JSONEncoder().encode(PanelLayout())
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        object.removeValue(forKey: "galleryPreviewZoom")
        object.removeValue(forKey: "histogramFloatingWidth")
        object.removeValue(forKey: "histogramFloatingHeight")
        object.removeValue(forKey: "histogramFloatingAnchor")
        object.removeValue(forKey: "histogramDisplayMode")
        object.removeValue(forKey: "waveformPlacement")
        object.removeValue(forKey: "waveformFloatingWidth")
        object.removeValue(forKey: "waveformFloatingHeight")
        object.removeValue(forKey: "waveformFloatingAnchor")
        object.removeValue(forKey: "waveformDirection")
        object.removeValue(forKey: "waveformChannelMode")
        object.removeValue(forKey: "compositionOverlays")
        object.removeValue(forKey: "compositionOverlayColor")
        object.removeValue(forKey: "compositionOverlayOpacity")
        object.removeValue(forKey: "compositionGuidesFollowCrop")
        object.removeValue(forKey: "cropGuideRatio")
        object.removeValue(forKey: "cropGuideStyle")
        object.removeValue(forKey: "cropGuideOrientation")
        object.removeValue(forKey: "customCropGuideRatios")
        object.removeValue(forKey: "activeCustomCropGuideRatioID")
        object.removeValue(forKey: "appAppearance")
        object.removeValue(forKey: "previewBackground")
        object.removeValue(forKey: "reviewMatteSize")
        let legacyData = try JSONSerialization.data(withJSONObject: object)

        let layout = try JSONDecoder().decode(PanelLayout.self, from: legacyData)

        XCTAssertEqual(layout.histogramFloatingWidth, 230)
        XCTAssertEqual(layout.galleryPreviewZoom, 1.0)
        XCTAssertEqual(layout.histogramFloatingHeight, 112)
        XCTAssertEqual(layout.histogramFloatingAnchor, .topRight)
        XCTAssertEqual(layout.histogramDisplayMode, .rgbAndLuminance)
        XCTAssertEqual(layout.waveformPlacement, .hidden)
        XCTAssertEqual(layout.waveformFloatingWidth, 260)
        XCTAssertEqual(layout.waveformFloatingHeight, 128)
        XCTAssertEqual(layout.waveformFloatingAnchor, .topLeft)
        XCTAssertEqual(layout.waveformDirection, .horizontalX)
        XCTAssertEqual(layout.waveformChannelMode, .luminance)
        XCTAssertTrue(layout.compositionOverlays.isEmpty)
        XCTAssertEqual(layout.compositionOverlayColor, .gray)
        XCTAssertEqual(layout.compositionOverlayOpacity, 0.46)
        XCTAssertFalse(layout.compositionGuidesFollowCrop)
        XCTAssertEqual(layout.cropGuideRatio, .hidden)
        XCTAssertEqual(layout.cropGuideStyle, .mask)
        XCTAssertEqual(layout.cropGuideOrientation, .automatic)
        XCTAssertTrue(layout.customCropGuideRatios.isEmpty)
        XCTAssertNil(layout.activeCustomCropGuideRatioID)
        XCTAssertEqual(layout.appAppearance, .system)
        XCTAssertEqual(layout.previewBackground, .system)
        XCTAssertEqual(layout.reviewMatteSize, .none)
    }

    func testPanelLayoutLimitsCustomCropRatiosAndClearsMissingActiveRatio() throws {
        var layout = PanelLayout()
        layout.customCropGuideRatios = (0..<12).map { index in
            CustomCropGuideRatio(name: "Ratio \(index)", width: Double(index + 1), height: 1)
        }
        layout.activeCustomCropGuideRatioID = UUID()
        let data = try JSONEncoder().encode(layout)

        let decoded = try JSONDecoder().decode(PanelLayout.self, from: data)

        XCTAssertEqual(decoded.customCropGuideRatios.count, CustomCropGuideRatio.maximumSavedCount)
        XCTAssertNil(decoded.activeCustomCropGuideRatioID)
    }

    func testPanelLayoutClampsGalleryPreviewZoom() throws {
        var layout = PanelLayout()
        layout.galleryPreviewZoom = 8.0
        let data = try JSONEncoder().encode(layout)

        let decoded = try JSONDecoder().decode(PanelLayout.self, from: data)

        XCTAssertEqual(decoded.galleryPreviewZoom, 4.0)
    }

    private func temporaryDefaults() throws -> UserDefaults {
        let name = "PreStageTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: name) else {
            throw XCTSkip("Could not create temporary UserDefaults suite.")
        }
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    private func preset(name: String, action: CameraCardAction = .notify) -> WorkspacePreset {
        WorkspacePreset(
            id: UUID(),
            name: name,
            panelLayout: PanelLayout(),
            viewMode: .grid,
            filterState: FilterState(),
            sortRule: .default,
            copyRule: .captureDate,
            localSourcePath: nil,
            localTargetPath: nil,
            preservePaths: true,
            cameraCardAction: action
        )
    }
}
