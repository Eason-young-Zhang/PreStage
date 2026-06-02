import SwiftUI

struct StatusBarView: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        HStack(spacing: 12) {
            Text(store.statusMessage)
                .lineLimit(1)
            if store.copyProgress.isRunning || store.copyProgress.completedCount > 0 {
                ProgressView(value: store.copyProgress.fraction)
                    .frame(width: 160)
                Text("\(store.copyProgress.completedCount)/\(store.copyProgress.totalCount)")
                    .foregroundStyle(.secondary)
                if store.copyProgress.isRunning {
                    Button(store.copyProgress.isPaused ? L10n.tr("Resume") : L10n.tr("Pause")) {
                        store.toggleCopyPause()
                    }
                    .buttonStyle(.borderless)
                    .shortcutHelp(store.copyProgress.isPaused ? L10n.tr("Resume Copy") : L10n.tr("Pause Copy"), shortcut: "⌥⌘P")
                    Button(L10n.tr("Cancel")) {
                        store.cancelCopy()
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.red)
                    .shortcutHelp(L10n.tr("Cancel Copy"), shortcut: "⌘.")
                }
            }
            if store.proxyProgress.isRunning || store.proxyProgress.completedCount > 0 {
                ProgressView(value: store.proxyProgress.fraction)
                    .frame(width: 160)
                Text("\(store.proxyProgress.completedCount)/\(store.proxyProgress.totalCount)")
                    .foregroundStyle(.secondary)
            }
            if store.previewPreheatProgress.isRunning {
                ProgressView(value: store.previewPreheatProgress.fraction)
                    .frame(width: 86)
                Text(
                    String(
                        format: L10n.tr("Preheating previews: %d/%d"),
                        store.previewPreheatProgress.completedCount,
                        store.previewPreheatProgress.totalCount
                    )
                )
                .foregroundStyle(.secondary)
                .lineLimit(1)
            } else if let summary = store.previewPreheatSummary {
                Text(summary)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            if store.metadataProgress.isRunning {
                ProgressView(value: store.metadataProgress.fraction)
                    .frame(width: 86)
                Text(
                    String(
                        format: L10n.tr("Reading metadata: %d/%d"),
                        store.metadataProgress.completedCount,
                        store.metadataProgress.totalCount
                    )
                )
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }
            Spacer()
            Text("\(store.selectedItemIDs.count) \(L10n.tr("selected"))")
                .foregroundStyle(.secondary)
        }
        .font(.caption)
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(.bar)
    }
}
