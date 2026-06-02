import Foundation
import SwiftUI

enum AppFormatters {
    static let dayFolderFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    static let shortDateTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    static let byteCount: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter
    }()
}

extension ColorLabel {
    var color: Color {
        switch self {
        case .red: .red
        case .yellow: .yellow
        case .green: .green
        case .blue: .blue
        case .purple: .purple
        }
    }
}

extension CopyStatus {
    var label: String {
        switch self {
        case .notCopied: L10n.tr("Not copied")
        case .queued: L10n.tr("Queued")
        case .copying: L10n.tr("Copying")
        case .copied: L10n.tr("Copied")
        case .verified: L10n.tr("Verified")
        case .failed: L10n.tr("Failed")
        case .skipped: L10n.tr("Skipped")
        case .cancelled: L10n.tr("Cancelled")
        }
    }

    var isFinalLogStatus: Bool {
        switch self {
        case .verified, .failed, .skipped, .cancelled:
            true
        case .notCopied, .queued, .copying, .copied:
            false
        }
    }
}
