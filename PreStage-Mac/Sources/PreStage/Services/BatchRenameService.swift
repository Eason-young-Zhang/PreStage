import Foundation

struct BatchRenameRule: Equatable {
    var pattern = "PreStage_{index}"
    var startNumber = 1
    var digitCount = 4
    var letterCase: BatchRenameLetterCase = .preserve
    var replaceWhitespace = false
}

enum BatchRenameLetterCase: String, CaseIterable, Identifiable {
    case preserve
    case lowercase
    case uppercase

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .preserve: L10n.tr("Preserve Case")
        case .lowercase: L10n.tr("Lowercase")
        case .uppercase: L10n.tr("Uppercase")
        }
    }
}

struct BatchRenamePlan: Equatable {
    var entries: [BatchRenameEntry]
    var issues: [BatchRenameIssue]

    var canApply: Bool {
        !entries.isEmpty && issues.isEmpty
    }
}

struct BatchRenameEntry: Identifiable, Equatable {
    let id = UUID()
    var itemID: UUID
    var sourceURL: URL
    var destinationURL: URL
    var sidecarSourceURL: URL?
    var sidecarDestinationURL: URL?
    var sequenceNumber: Int

    var isNoOp: Bool {
        sourceURL.standardizedFileURL.path == destinationURL.standardizedFileURL.path
    }
}

struct BatchRenameIssue: Identifiable, Equatable {
    let id = UUID()
    var message: String
}

enum BatchRenameError: LocalizedError {
    case planHasIssues
    case undoConflict(String)

    var errorDescription: String? {
        switch self {
        case .planHasIssues:
            L10n.tr("Fix rename conflicts before applying.")
        case .undoConflict(let filename):
            String(format: L10n.tr("Cannot undo because the original name already exists: %@"), filename)
        }
    }
}

struct BatchRenameResult: Equatable {
    var renamedMediaCount: Int
    var movedFileCount: Int
    var undoActions: [BatchRenameUndoAction]
}

struct BatchRenameUndoRecord: Equatable {
    var id = UUID()
    var createdAt = Date()
    var renamedMediaCount: Int
    var actions: [BatchRenameUndoAction]
}

struct BatchRenameUndoAction: Equatable {
    var originalURL: URL
    var renamedURL: URL
}

struct BatchRenameService {
    func makePlan(items: [MediaItem], rule: BatchRenameRule) -> BatchRenamePlan {
        guard !items.isEmpty else {
            return BatchRenamePlan(entries: [], issues: [BatchRenameIssue(message: L10n.tr("Select files before batch renaming."))])
        }

        var entries: [BatchRenameEntry] = []
        var issues: [BatchRenameIssue] = []
        var sequenceNumber = max(0, rule.startNumber)

        for group in renameGroups(from: items) {
            let primary = group.primary
            let baseName = renderedBaseName(for: primary, rule: rule, sequenceNumber: sequenceNumber)
            if baseName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                issues.append(BatchRenameIssue(message: L10n.tr("Rename pattern produced an empty filename.")))
            }

            for item in group.items {
                let destination = item.url
                    .deletingLastPathComponent()
                    .appendingPathComponent(baseName)
                    .appendingPathExtension(item.fileExtension)
                let sidecarSource = sidecarURL(for: item.url)
                let sidecarDestination = sidecarURL(for: destination)
                entries.append(
                    BatchRenameEntry(
                        itemID: item.id,
                        sourceURL: item.url,
                        destinationURL: destination,
                        sidecarSourceURL: FileManager.default.fileExists(atPath: sidecarSource.path) ? sidecarSource : nil,
                        sidecarDestinationURL: sidecarDestination,
                        sequenceNumber: sequenceNumber
                    )
                )
            }
            sequenceNumber += 1
        }

        issues.append(contentsOf: validationIssues(for: entries))
        return BatchRenamePlan(entries: entries, issues: issues)
    }

    func apply(_ plan: BatchRenamePlan) throws -> BatchRenameResult {
        guard plan.issues.isEmpty else { throw BatchRenameError.planHasIssues }

        var undoActions: [BatchRenameUndoAction] = []
        var renamedMediaCount = 0

        for entry in plan.entries where !entry.isNoOp {
            do {
                try moveForRename(from: entry.sourceURL, to: entry.destinationURL, undoActions: &undoActions)
                renamedMediaCount += 1
                if let sidecarSourceURL = entry.sidecarSourceURL,
                   let sidecarDestinationURL = entry.sidecarDestinationURL,
                   FileManager.default.fileExists(atPath: sidecarSourceURL.path) {
                    try moveForRename(from: sidecarSourceURL, to: sidecarDestinationURL, undoActions: &undoActions)
                }
            } catch {
                try? undo(actions: undoActions)
                throw error
            }
        }

        return BatchRenameResult(
            renamedMediaCount: renamedMediaCount,
            movedFileCount: undoActions.count,
            undoActions: undoActions
        )
    }

    func undo(_ record: BatchRenameUndoRecord) throws {
        try undo(actions: record.actions)
    }

    private func undo(actions: [BatchRenameUndoAction]) throws {
        for action in actions.reversed() where FileManager.default.fileExists(atPath: action.renamedURL.path) {
            if FileManager.default.fileExists(atPath: action.originalURL.path) {
                throw BatchRenameError.undoConflict(action.originalURL.lastPathComponent)
            }
            try FileManager.default.moveItem(at: action.renamedURL, to: action.originalURL)
        }
    }

    private func moveForRename(from sourceURL: URL, to destinationURL: URL, undoActions: inout [BatchRenameUndoAction]) throws {
        try FileManager.default.moveItem(at: sourceURL, to: destinationURL)
        undoActions.append(BatchRenameUndoAction(originalURL: sourceURL, renamedURL: destinationURL))
    }

    private func renameGroups(from items: [MediaItem]) -> [BatchRenameGroup] {
        let sorted = items.sorted { left, right in
            left.url.path.localizedStandardCompare(right.url.path) == .orderedAscending
        }
        var groups: [BatchRenameGroup] = []
        var consumed = Set<UUID>()

        for item in sorted where !consumed.contains(item.id) {
            if let pairKey = item.pairedAssetKey {
                let members = sorted.filter { $0.pairedAssetKey == pairKey }
                members.forEach { consumed.insert($0.id) }
                let primary = members.first(where: { $0.mediaType == .jpeg }) ?? item
                groups.append(BatchRenameGroup(primary: primary, items: members))
            } else {
                consumed.insert(item.id)
                groups.append(BatchRenameGroup(primary: item, items: [item]))
            }
        }
        return groups
    }

    private func renderedBaseName(for item: MediaItem, rule: BatchRenameRule, sequenceNumber: Int) -> String {
        let index = String(format: "%0\(max(1, rule.digitCount))d", sequenceNumber)
        let sourceDate = item.captureDate ?? item.createdDate ?? item.modifiedDate ?? Date()
        let date = AppFormatters.dayFolderFormatter.string(from: sourceDate)
        let time = Self.timeFormatter.string(from: sourceDate)
        return rule.pattern
            .replacingOccurrences(of: "{index}", with: index)
            .replacingOccurrences(of: "{name}", with: item.url.deletingPathExtension().lastPathComponent)
            .replacingOccurrences(of: "{date}", with: date)
            .replacingOccurrences(of: "{time}", with: time)
            .replacingOccurrences(of: "{rating}", with: "\(item.rating)")
            .replacingOccurrences(of: "{camera}", with: item.cameraModel ?? L10n.tr("Unknown"))
            .replacingOccurrences(of: "{lens}", with: item.lensModel ?? L10n.tr("Unknown"))
            .replacingOccurrences(of: "{folder}", with: item.url.deletingLastPathComponent().lastPathComponent)
            .applyingWhitespaceReplacement(rule.replaceWhitespace)
            .applyingLetterCase(rule.letterCase)
            .safeFilename
    }

    private func validationIssues(for entries: [BatchRenameEntry]) -> [BatchRenameIssue] {
        var issues: [BatchRenameIssue] = []
        let groupedDestinations = Dictionary(grouping: entries, by: { $0.destinationURL.standardizedFileURL.path })
        for (path, duplicates) in groupedDestinations where duplicates.count > 1 {
            issues.append(BatchRenameIssue(message: String(format: L10n.tr("Duplicate destination: %@"), URL(fileURLWithPath: path).lastPathComponent)))
        }

        for entry in entries where !entry.isNoOp {
            if FileManager.default.fileExists(atPath: entry.destinationURL.path) {
                issues.append(BatchRenameIssue(message: String(format: L10n.tr("Destination already exists: %@"), entry.destinationURL.lastPathComponent)))
            }
            if let sidecarDestinationURL = entry.sidecarDestinationURL,
               FileManager.default.fileExists(atPath: sidecarDestinationURL.path) {
                issues.append(BatchRenameIssue(message: String(format: L10n.tr("Sidecar destination already exists: %@"), sidecarDestinationURL.lastPathComponent)))
            }
        }
        return issues
    }

    private func sidecarURL(for mediaURL: URL) -> URL {
        mediaURL.deletingPathExtension().appendingPathExtension("xmp")
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "HHmmss"
        return formatter
    }()
}

private struct BatchRenameGroup {
    var primary: MediaItem
    var items: [MediaItem]
}

private extension String {
    func applyingWhitespaceReplacement(_ shouldReplace: Bool) -> String {
        guard shouldReplace else { return self }
        return components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: "-")
    }

    func applyingLetterCase(_ letterCase: BatchRenameLetterCase) -> String {
        switch letterCase {
        case .preserve:
            self
        case .lowercase:
            lowercased()
        case .uppercase:
            uppercased()
        }
    }

    var safeFilename: String {
        let invalid = CharacterSet(charactersIn: "/:")
        return components(separatedBy: invalid)
            .joined(separator: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
