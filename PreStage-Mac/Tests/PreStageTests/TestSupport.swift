import Foundation
@testable import PreStage

enum TestSupport {
    static func temporaryDirectory(named name: String = UUID().uuidString) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("PreStageTests", isDirectory: true)
            .appendingPathComponent(name, isDirectory: true)
        try FileManager.default.removeItemIfExists(at: url)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    static func writeFile(_ url: URL, contents: String = "test-data") throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try contents.data(using: .utf8)?.write(to: url)
    }

    static func mediaItem(
        url: URL,
        type: MediaType? = nil,
        fileSize: Int64 = 10,
        captureDate: Date? = date(2026, 5, 3),
        addedDate: Date? = date(2026, 5, 4),
        createdDate: Date? = date(2026, 5, 1),
        modifiedDate: Date? = date(2026, 5, 2),
        lastOpenedDate: Date? = date(2026, 5, 5)
    ) -> MediaItem {
        MediaItem(
            url: url,
            mediaType: type ?? mediaType(for: url),
            fileSize: fileSize,
            captureDate: captureDate,
            addedDate: addedDate,
            createdDate: createdDate,
            modifiedDate: modifiedDate,
            lastOpenedDate: lastOpenedDate
        )
    }

    static func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        var components = DateComponents()
        components.calendar = Calendar(identifier: .gregorian)
        components.timeZone = TimeZone(secondsFromGMT: 0)
        components.year = year
        components.month = month
        components.day = day
        return components.date!
    }

    private static func mediaType(for url: URL) -> MediaType {
        switch url.pathExtension.lowercased() {
        case "jpg", "jpeg":
            return .jpeg
        case "rw2", "arw", "cr2", "cr3", "nef", "orf", "raf", "dng":
            return .raw
        case "mov", "mp4", "m4v":
            return .video
        case "heic", "heif":
            return .heic
        case "tif", "tiff":
            return .tiff
        case "png":
            return .png
        default:
            return .unknown
        }
    }
}

private extension FileManager {
    func removeItemIfExists(at url: URL) throws {
        guard fileExists(atPath: url.path) else { return }
        try removeItem(at: url)
    }
}
