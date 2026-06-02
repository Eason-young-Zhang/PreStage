import SwiftUI

struct CopyLogView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(L10n.tr("Copy Log"))
                    .font(.title2.weight(.semibold))
                Spacer()
                Button(L10n.tr("Clear")) { store.clearCopyLogs() }
                    .disabled(store.copyLogs.isEmpty)
                Button(L10n.tr("Done")) { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding(16)

            Divider()

            if store.copyLogs.isEmpty {
                EmptyStateView(
                    title: L10n.tr("No Copy Logs"),
                    systemImage: "doc.text.magnifyingglass",
                    message: L10n.tr("Copy operations will appear here with per-file status and verification results.")
                )
            } else {
                List {
                    ForEach(store.copyLogs) { log in
                        Section {
                            CopyLogHeader(log: log)
                            ForEach(log.entries) { entry in
                                CopyLogEntryRow(entry: entry)
                            }
                        }
                    }
                }
                .listStyle(.inset)
            }
        }
        .frame(width: 760, height: 560)
    }
}

private struct CopyLogHeader: View {
    let log: CopyLogRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label(log.isFinished ? L10n.tr("Finished") : L10n.tr("Running"), systemImage: log.isFinished ? "checkmark.circle" : "clock")
                    .foregroundStyle(log.isFinished ? .green : .secondary)
                Spacer()
                Text(AppFormatters.shortDateTime.string(from: log.startedAt))
                    .foregroundStyle(.secondary)
            }
            Text(log.destinationPath)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
            HStack(spacing: 12) {
                Text("\(log.totalItems) \(L10n.tr("files"))")
                Text(AppFormatters.byteCount.string(fromByteCount: log.totalBytes))
                Text(log.rule.displayName)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

private struct CopyLogEntryRow: View {
    let entry: CopyLogEntry

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: iconName)
                .foregroundStyle(iconColor)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.filename)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(entry.message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(AppFormatters.shortDateTime.string(from: entry.timestamp))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var iconName: String {
        switch entry.status {
        case .verified, .copied:
            "checkmark.circle.fill"
        case .failed:
            "xmark.circle.fill"
        case .skipped:
            "forward.circle.fill"
        case .cancelled:
            "stop.circle.fill"
        case .copying, .queued:
            "clock.fill"
        case .notCopied:
            "circle"
        }
    }

    private var iconColor: Color {
        switch entry.status {
        case .verified, .copied:
            .green
        case .failed:
            .red
        case .skipped:
            .orange
        case .cancelled:
            .orange
        default:
            .secondary
        }
    }
}
