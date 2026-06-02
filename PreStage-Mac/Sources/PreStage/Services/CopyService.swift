import Foundation
import CryptoKit

enum CopyServiceError: Error {
    case missingTarget
}

actor CopyOperationControl {
    private var paused = false
    private var cancelled = false

    func pause() {
        paused = true
    }

    func resume() {
        paused = false
    }

    func cancel() {
        cancelled = true
        paused = false
    }

    func isPaused() -> Bool {
        paused
    }

    func isCancelled() -> Bool {
        cancelled
    }

    func waitIfPaused() async -> Bool {
        while paused && !cancelled {
            try? await Task.sleep(nanoseconds: 120_000_000)
        }
        return !cancelled
    }
}

final class CopyService {
    func copyItems(
        _ items: [MediaItem],
        to targetFolder: URL,
        sourceRoot: URL?,
        rule: CopyOrganizationRule,
        conflictPolicy: CopyConflictPolicy,
        verificationMode: CopyVerificationMode = .sizeOnly,
        control: CopyOperationControl,
        progress: @escaping @MainActor (CopyProgress, UUID?, CopyStatus?) -> Void
    ) async {
        let totalBytes = items.reduce(Int64(0)) { $0 + $1.fileSize }
        var snapshot = CopyProgress(currentItem: "", completedCount: 0, totalCount: items.count, completedBytes: 0, totalBytes: totalBytes, isRunning: true, message: "Copying")
        await progress(snapshot, nil, nil)
        for item in items {
            await progress(snapshot, item.id, .queued)
        }

        for (index, item) in items.enumerated() {
            if await control.isPaused() {
                snapshot.isPaused = true
                snapshot.message = "Copy paused"
                await progress(snapshot, nil, nil)
            }
            guard await control.waitIfPaused() else {
                snapshot.isRunning = false
                snapshot.isCancelled = true
                snapshot.message = "Copy cancelled: \(snapshot.completedCount) of \(snapshot.totalCount) complete"
                for cancelledItem in items[index...] {
                    await progress(snapshot, cancelledItem.id, .cancelled)
                }
                await progress(snapshot, nil, nil)
                return
            }
            snapshot.isPaused = false

            await progress(snapshot, item.id, .copying)
            let folder = destinationFolder(for: item, targetFolder: targetFolder, sourceRoot: sourceRoot, rule: rule)

            do {
                try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                if let destination = try destinationURL(for: item, in: folder, policy: conflictPolicy) {
                    if conflictPolicy == .overwrite, FileManager.default.fileExists(atPath: destination.path) {
                        try FileManager.default.removeItem(at: destination)
                        try removeSidecarIfNeeded(for: destination)
                    }

                    try FileManager.default.copyItem(at: item.url, to: destination)
                    try copySidecarIfNeeded(for: item.url, to: destination, conflictPolicy: conflictPolicy)
                    await progress(snapshot, item.id, .copied)
                    let status = try verificationStatus(for: item, destination: destination, mode: verificationMode)
                    await progress(snapshot, item.id, status)
                } else {
                    await progress(snapshot, item.id, .skipped)
                }
            } catch {
                await progress(snapshot, item.id, .failed)
            }

            snapshot.completedCount += 1
            snapshot.completedBytes += item.fileSize
            snapshot.currentItem = item.filename
            snapshot.message = "\(snapshot.completedCount) of \(snapshot.totalCount) complete"
            await progress(snapshot, nil, nil)

            if await control.isCancelled() {
                snapshot.isRunning = false
                snapshot.isCancelled = true
                snapshot.message = "Copy cancelled: \(snapshot.completedCount) of \(snapshot.totalCount) complete"
                for cancelledItem in items.dropFirst(index + 1) {
                    await progress(snapshot, cancelledItem.id, .cancelled)
                }
                await progress(snapshot, nil, nil)
                return
            }
        }

        snapshot.isRunning = false
        snapshot.message = "Finished: \(snapshot.completedCount) files checked by \(verificationMode.completionDescription)"
        await progress(snapshot, nil, nil)
    }

    private func verificationStatus(for item: MediaItem, destination: URL, mode: CopyVerificationMode) throws -> CopyStatus {
        let copiedSize = (try? destination.resourceValues(forKeys: [.fileSizeKey]).fileSize).map(Int64.init) ?? -1
        guard copiedSize == item.fileSize else { return .failed }

        switch mode {
        case .sizeOnly:
            return .verified
        case .sha256:
            let sourceHash = try sha256Digest(for: item.url)
            let destinationHash = try sha256Digest(for: destination)
            return sourceHash == destinationHash ? .verified : .failed
        }
    }

    private func sha256Digest(for url: URL) throws -> SHA256.Digest {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }

        var hasher = SHA256()
        while true {
            let data = try handle.read(upToCount: 1_048_576) ?? Data()
            guard !data.isEmpty else { break }
            hasher.update(data: data)
        }
        return hasher.finalize()
    }

    private func destinationURL(for item: MediaItem, in folder: URL, policy: CopyConflictPolicy) throws -> URL? {
        let baseURL = folder.appendingPathComponent(item.filename)
        guard mediaOrSidecarExists(for: baseURL) else { return baseURL }

        switch policy {
        case .skipExisting:
            return nil
        case .overwrite:
            return baseURL
        case .autoRename:
            return nextAvailableURL(for: baseURL)
        }
    }

    private func nextAvailableURL(for url: URL) -> URL {
        let folder = url.deletingLastPathComponent()
        let baseName = url.deletingPathExtension().lastPathComponent
        let ext = url.pathExtension

        var index = 2
        while true {
            let filename = ext.isEmpty ? "\(baseName) \(index)" : "\(baseName) \(index).\(ext)"
            let candidate = folder.appendingPathComponent(filename)
            if !mediaOrSidecarExists(for: candidate) {
                return candidate
            }
            index += 1
        }
    }

    private func mediaOrSidecarExists(for mediaURL: URL) -> Bool {
        if FileManager.default.fileExists(atPath: mediaURL.path) {
            return true
        }
        let sidecar = mediaURL.deletingPathExtension().appendingPathExtension("xmp")
        return FileManager.default.fileExists(atPath: sidecar.path)
    }

    private func removeSidecarIfNeeded(for mediaURL: URL) throws {
        let sidecar = mediaURL.deletingPathExtension().appendingPathExtension("xmp")
        guard FileManager.default.fileExists(atPath: sidecar.path) else { return }
        try FileManager.default.removeItem(at: sidecar)
    }

    private func copySidecarIfNeeded(for sourceMediaURL: URL, to destinationMediaURL: URL, conflictPolicy: CopyConflictPolicy) throws {
        let sourceSidecar = sourceMediaURL.deletingPathExtension().appendingPathExtension("xmp")
        guard FileManager.default.fileExists(atPath: sourceSidecar.path) else { return }
        let destinationSidecar = destinationMediaURL.deletingPathExtension().appendingPathExtension("xmp")
        if FileManager.default.fileExists(atPath: destinationSidecar.path) {
            guard conflictPolicy == .overwrite else { return }
            try FileManager.default.removeItem(at: destinationSidecar)
        }

        if conflictPolicy == .autoRename, FileManager.default.fileExists(atPath: destinationSidecar.path) {
            return
        }
        try FileManager.default.copyItem(at: sourceSidecar, to: destinationSidecar)
    }

    private func destinationFolder(for item: MediaItem, targetFolder: URL, sourceRoot: URL?, rule: CopyOrganizationRule) -> URL {
        switch rule {
        case .captureDate:
            let day = AppFormatters.dayFolderFormatter.string(from: item.captureDate ?? item.createdDate ?? item.modifiedDate ?? Date())
            return targetFolder.appendingPathComponent(day, isDirectory: true)
        case .preserveStructure:
            guard let sourceRoot else { return targetFolder }
            let sourceFolder = item.url.deletingLastPathComponent()
            let rootPath = sourceRoot.standardizedFileURL.path
            let sourcePath = sourceFolder.standardizedFileURL.path
            guard sourcePath.hasPrefix(rootPath) else { return targetFolder }
            let relativePath = String(sourcePath.dropFirst(rootPath.count)).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            guard !relativePath.isEmpty else { return targetFolder }
            return targetFolder.appendingPathComponent(relativePath, isDirectory: true)
        case .cameraModel:
            return targetFolder.appendingPathComponent(safeFolderName(item.cameraModel ?? "Unknown Camera"), isDirectory: true)
        case .rating:
            return targetFolder.appendingPathComponent("\(item.rating)-Star", isDirectory: true)
        }
    }

    private func safeFolderName(_ value: String) -> String {
        let invalid = CharacterSet(charactersIn: "/:")
        let parts = value.components(separatedBy: invalid).filter { !$0.isEmpty }
        return parts.joined(separator: "-").trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
