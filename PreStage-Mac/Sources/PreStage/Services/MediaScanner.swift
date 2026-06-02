import Foundation

struct MediaScanner {
    private let supportedExtensions: [String: MediaType] = [
        "arw": .raw, "cr2": .raw, "cr3": .raw, "nef": .raw, "orf": .raw, "raf": .raw, "rw2": .raw, "dng": .raw,
        "jpg": .jpeg, "jpeg": .jpeg,
        "heic": .heic, "heif": .heic,
        "tif": .tiff, "tiff": .tiff,
        "png": .png,
        "mov": .video, "mp4": .video, "m4v": .video
    ]

    func scan(directory: URL, recursive: Bool = true) throws -> [MediaItem] {
        let resourceKeys: Set<URLResourceKey> = [
            .isRegularFileKey,
            .isDirectoryKey,
            .fileSizeKey,
            .creationDateKey,
            .contentModificationDateKey,
            .addedToDirectoryDateKey,
            .contentAccessDateKey
        ]
        let options: FileManager.DirectoryEnumerationOptions = recursive ? [.skipsHiddenFiles] : [.skipsHiddenFiles, .skipsSubdirectoryDescendants]

        guard let enumerator = FileManager.default.enumerator(at: directory, includingPropertiesForKeys: Array(resourceKeys), options: options) else {
            return []
        }

        var items: [MediaItem] = []
        for case let fileURL as URL in enumerator {
            let values = try fileURL.resourceValues(forKeys: resourceKeys)
            if values.isDirectory == true, fileURL.lastPathComponent == ProxyGenerationService.proxyFolderName {
                enumerator.skipDescendants()
                continue
            }

            let ext = fileURL.pathExtension.lowercased()
            guard let mediaType = supportedExtensions[ext] else { continue }
            guard values.isRegularFile == true else { continue }
            let fileSize = Int64(values.fileSize ?? 0)
            let created = values.creationDate
            let modified = values.contentModificationDate
            let added = values.addedToDirectoryDate ?? created ?? modified
            let lastOpened = values.contentAccessDate
            items.append(MediaItem(
                url: fileURL,
                mediaType: mediaType,
                fileSize: fileSize,
                captureDate: created ?? modified,
                addedDate: added,
                createdDate: created,
                modifiedDate: modified,
                lastOpenedDate: lastOpened
            ))
        }

        return items.sorted { lhs, rhs in
            (lhs.addedDate ?? lhs.createdDate ?? lhs.modifiedDate ?? .distantPast) > (rhs.addedDate ?? rhs.createdDate ?? rhs.modifiedDate ?? .distantPast)
        }
    }
}
