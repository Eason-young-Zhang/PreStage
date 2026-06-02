import Foundation

struct FolderBranch: Equatable {
    var pathURL: URL
    var selectedURL: URL?
    var folders: [URL]
}

struct FolderBranchService {
    func sourceBranch(for sourceURL: URL?, selectedURL: URL?) -> FolderBranch? {
        guard let sourceURL else { return nil }
        let standardizedSource = sourceURL.standardizedFileURL
        return FolderBranch(pathURL: standardizedSource, selectedURL: selectedURL?.standardizedFileURL, folders: siblingFolders(in: standardizedSource))
    }

    func targetBranch(for targetURL: URL?, selectedURL: URL?) -> FolderBranch? {
        guard let targetURL else { return nil }
        let standardizedTarget = targetURL.standardizedFileURL
        return FolderBranch(pathURL: standardizedTarget, selectedURL: selectedURL?.standardizedFileURL, folders: siblingFolders(in: standardizedTarget))
    }

    private func siblingFolders(in parentURL: URL) -> [URL] {
        let keys: [URLResourceKey] = [.isDirectoryKey, .isPackageKey, .localizedNameKey]
        guard let urls = try? FileManager.default.contentsOfDirectory(
            at: parentURL,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        return urls.filter { url in
            guard let values = try? url.resourceValues(forKeys: Set(keys)) else { return false }
            return values.isDirectory == true && values.isPackage != true
        }
        .sorted { lhs, rhs in
            lhs.lastPathComponent.localizedStandardCompare(rhs.lastPathComponent) == .orderedAscending
        }
    }
}
