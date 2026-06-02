import Foundation

struct MediaPairingService {
    func assignPairingKeys(to items: [MediaItem]) -> [MediaItem] {
        let grouped = Dictionary(grouping: items) { item in
            item.url.deletingPathExtension().path
        }

        var pairedKeys = Set<String>()
        for (key, members) in grouped {
            let hasRaw = members.contains { $0.mediaType == .raw }
            let hasJPEG = members.contains { $0.mediaType == .jpeg }
            if hasRaw && hasJPEG {
                pairedKeys.insert(key)
            }
        }

        return items.map { item in
            var updated = item
            let key = item.url.deletingPathExtension().path
            updated.pairedAssetKey = pairedKeys.contains(key) ? key : nil
            return updated
        }
    }
}
