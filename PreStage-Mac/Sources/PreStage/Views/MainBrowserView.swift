import SwiftUI

struct MainBrowserView: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        VStack(spacing: 0) {
            BrowserHeaderView()
            Divider()
            if store.browserItems.isEmpty {
                EmptyStateView(
                    title: L10n.tr("No Media"),
                    systemImage: "photo.on.rectangle.angled",
                    message: store.sourceURL == nil ? L10n.tr("Choose a source folder or camera card.") : L10n.tr("No supported media files were found.")
                )
            } else {
                switch store.viewMode {
                case .grid:
                    GridBrowserView()
                case .list:
                    ListBrowserView()
                case .gallery:
                    GalleryBrowserView()
                }
            }
        }
    }
}

private struct BrowserHeaderView: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(store.activeSourceURL?.lastPathComponent ?? L10n.tr("Photo Preselect"))
                    .font(.headline)
                Text("\(store.browserItems.count) \(L10n.tr("visible of")) \(store.mediaItems.count) \(L10n.tr("files"))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            BrowserViewModeControl()

            HStack(spacing: 8) {
                Button {
                    store.toggleSortDirection()
                } label: {
                    Image(systemName: store.sortRule.direction.systemImage)
                        .font(.title3.weight(.medium))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .shortcutHelp(store.sortRule.direction.accessibilityLabel)
                .accessibilityLabel(store.sortRule.direction.accessibilityLabel)

                Picker(L10n.tr("Sort"), selection: sortFieldBinding) {
                    ForEach(SortField.allCases) { field in
                        Text(field.displayName).tag(field)
                    }
                }
                .labelsHidden()
            }
            .frame(width: 160)
            .onChange(of: store.sortRule) { store.saveWorkspace() }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var sortFieldBinding: Binding<SortField> {
        Binding(
            get: { store.sortRule.field },
            set: { store.setSortField($0) }
        )
    }
}

private struct BrowserViewModeControl: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        HStack(spacing: 0) {
            ForEach(ViewMode.allCases) { mode in
                Button {
                    store.viewMode = mode
                    store.saveWorkspace()
                } label: {
                    Image(systemName: mode.systemImage)
                        .font(.system(size: 13, weight: .semibold))
                        .frame(width: 38, height: 26)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(store.viewMode == mode ? .white : .primary)
                .background {
                    if store.viewMode == mode {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.accentColor)
                    }
                }
                .shortcutHelp(mode.displayName, shortcut: shortcut(for: mode))
                .accessibilityLabel(mode.displayName)
            }
        }
        .padding(2)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(.separator.opacity(0.2), lineWidth: 0.5)
        }
        .frame(width: 132)
    }

    private func shortcut(for mode: ViewMode) -> String {
        switch mode {
        case .grid:
            "⌘1"
        case .list:
            "⌘2"
        case .gallery:
            "⌘3"
        }
    }
}
