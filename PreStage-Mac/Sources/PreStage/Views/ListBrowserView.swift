import SwiftUI

struct ListBrowserView: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        Table(store.filteredItems, selection: selectionBinding) {
            TableColumn(L10n.tr("Name")) { item in
                HStack(spacing: 8) {
                    ThumbnailImage(item: item, size: CGSize(width: 34, height: 24), contentMode: .fill, transform: store.transform(for: item))
                        .frame(width: 28, height: 20)
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                        .overlay(
                            RoundedRectangle(cornerRadius: 3)
                                .stroke(.separator, lineWidth: 0.5)
                        )
                    Text(item.filename)
                        .lineLimit(1)
                }
                .contentShape(Rectangle())
                .contextMenu { FinderStyleContextMenu(item: item) }
            }

            TableColumn(L10n.tr("Type")) { item in
                Text(item.mediaType.displayName)
                    .foregroundStyle(.secondary)
            }
            .width(72)

            TableColumn(L10n.tr("Size")) { item in
                Text(AppFormatters.byteCount.string(fromByteCount: item.fileSize))
                    .foregroundStyle(.secondary)
            }
            .width(92)

            TableColumn(L10n.tr("Captured")) { item in
                Text(item.captureDate.map(AppFormatters.shortDateTime.string(from:)) ?? L10n.tr("Unknown"))
                    .foregroundStyle(.secondary)
            }
            .width(170)

            TableColumn(L10n.tr("Camera")) { item in
                Text(item.cameraModel ?? "")
                    .foregroundStyle(.secondary)
            }
            .width(140)

            TableColumn(L10n.tr("Lens")) { item in
                Text(item.lensModel ?? "")
                    .foregroundStyle(.secondary)
            }
            .width(160)

            TableColumn(L10n.tr("Rating")) { item in
                RatingStars(rating: item.rating)
            }
            .width(90)

            TableColumn(L10n.tr("Pick")) { item in
                Text(item.pickState.displayName)
                    .foregroundStyle(item.pickState == .rejected ? .red : item.pickState == .picked ? .green : .secondary)
            }
            .width(84)

            TableColumn(L10n.tr("Copy")) { item in
                Text(item.copyStatus.label)
                    .foregroundStyle(.secondary)
            }
            .width(100)

            TableColumn(L10n.tr("Pair")) { item in
                Text(item.pairedAssetKey == nil ? "" : "RAW+JPEG")
                    .foregroundStyle(.secondary)
            }
            .width(92)
        }
        .onChange(of: store.selectedItemIDs) {
            store.syncFocusedItemToSelection()
        }
        .contextMenu { FinderStyleContextMenu() }
        .background(SpaceKeyHandler { store.quickLookSelectedItems() })
    }

    private var selectionBinding: Binding<Set<UUID>> {
        Binding(
            get: { store.selectedItemIDs },
            set: { ids in store.selectItems(ids) }
        )
    }
}
