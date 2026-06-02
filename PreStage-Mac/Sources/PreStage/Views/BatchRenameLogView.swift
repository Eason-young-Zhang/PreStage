import SwiftUI

struct BatchRenameLogView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(L10n.tr("Batch Rename Log"))
                    .font(.title2.weight(.semibold))
                Spacer()
                Button(L10n.tr("Clear")) { store.clearBatchRenameLogs() }
                    .disabled(store.batchRenameLogs.isEmpty)
                Button(L10n.tr("Done")) { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding(16)

            Divider()

            if store.batchRenameLogs.isEmpty {
                EmptyStateView(
                    title: L10n.tr("No Batch Rename Logs"),
                    systemImage: "text.badge.checkmark",
                    message: L10n.tr("Batch rename operations will appear here with original and new filenames.")
                )
            } else {
                List {
                    ForEach(store.batchRenameLogs) { log in
                        Section {
                            BatchRenameLogHeader(log: log)
                            ForEach(log.entries) { entry in
                                BatchRenameLogEntryRow(entry: entry)
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

private struct BatchRenameLogHeader: View {
    let log: BatchRenameLogRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label(L10n.tr("Finished"), systemImage: "checkmark.circle")
                    .foregroundStyle(.green)
                Spacer()
                Text(AppFormatters.shortDateTime.string(from: log.createdAt))
                    .foregroundStyle(.secondary)
            }
            if let sourcePath = log.sourcePath {
                Text(sourcePath)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Text("\(log.totalItems) \(L10n.tr("files"))")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

private struct BatchRenameLogEntryRow: View {
    let entry: BatchRenameLogEntry

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "arrow.right.circle.fill")
                .foregroundStyle(.blue)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(entry.originalName)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Image(systemName: "arrow.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(entry.newName)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                Text(entry.folderPath)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer()
        }
    }
}
