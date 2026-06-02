import SwiftUI

struct GridBrowserView: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        GeometryReader { proxy in
            let metrics = gridMetrics(for: proxy.size.width)
            ScrollView {
                LazyVGrid(columns: metrics.columns, spacing: 14) {
                    ForEach(store.browserItems) { item in
                        MediaTileView(
                            item: item,
                            tileWidth: metrics.itemWidth,
                            thumbnailSize: CGSize(width: metrics.itemWidth - 16, height: metrics.thumbnailHeight)
                        )
                            .frame(width: metrics.itemWidth)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 16)
            }
            .background(SpaceKeyHandler { store.quickLookSelectedItems() })
        }
    }

    private func gridMetrics(for width: CGFloat) -> (columns: [GridItem], itemWidth: CGFloat, thumbnailHeight: CGFloat) {
        let horizontalPadding: CGFloat = 36
        let spacing: CGFloat = 14
        let availableWidth = max(width - horizontalPadding, 160)
        let minimumItemWidth: CGFloat = 168 * store.panelLayout.gridThumbnailScale
        let columnCount = max(1, Int((availableWidth + spacing) / (minimumItemWidth + spacing)))
        let itemWidth = floor((availableWidth - CGFloat(columnCount - 1) * spacing) / CGFloat(columnCount))
        let thumbnailHeight = max(96, min(220, itemWidth * 0.72))
        let columns = Array(repeating: GridItem(.fixed(itemWidth), spacing: spacing, alignment: .top), count: columnCount)
        return (columns, itemWidth, thumbnailHeight)
    }
}

struct MediaTileView: View {
    @EnvironmentObject private var store: AppStore
    let item: MediaItem
    let tileWidth: CGFloat
    let thumbnailSize: CGSize

    init(item: MediaItem, tileWidth: CGFloat, thumbnailSize: CGSize) {
        self.item = item
        self.tileWidth = tileWidth
        self.thumbnailSize = thumbnailSize
    }

    var body: some View {
        let isCollapsedStack = store.isCollapsedProxyStackRepresentative(item)
        Button {
            store.expandProxyStackIfNeeded(for: item)
            store.selectItem(id: item.id, extendingSelection: NSEvent.modifierFlags.contains(.command))
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                ZStack(alignment: .topTrailing) {
                    standardThumbnail
                    CopyStatusBadge(status: item.copyStatus)
                        .padding(6)
                    if isCollapsedStack {
                        Text("RAW+JPEG")
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 3)
                            .background(.regularMaterial)
                            .clipShape(Capsule())
                            .padding(6)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                    }
                }

                Text(item.filename)
                    .font(.caption)
                    .lineLimit(1)

                HStack {
                    RatingStars(rating: item.rating)
                    Spacer()
                    PickBadge(state: item.pickState)
                    if let label = item.colorLabel {
                        Circle().fill(label.color).frame(width: 9, height: 9)
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .padding(8)
        .frame(width: tileWidth, alignment: .center)
        .background(alignment: .topLeading) {
            stackBackground(isCollapsedStack: isCollapsedStack)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(store.isFocusedForDisplay(item) ? Color.accentColor : Color.clear, lineWidth: 2)
        )
        .padding(.top, isCollapsedStack ? 8 : 0)
        .padding(.trailing, isCollapsedStack ? 8 : 0)
        .contentShape(Rectangle())
        .contextMenu { FinderStyleContextMenu(item: item) }
    }

    private var selectionBackground: some ShapeStyle {
        store.isSelectedForDisplay(item) ? AnyShapeStyle(.selection.opacity(0.28)) : AnyShapeStyle(.quaternary.opacity(0.18))
    }

    private var standardThumbnail: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(.quaternary.opacity(0.16))
            ThumbnailImage(item: item, size: thumbnailSize, contentMode: .fit, transform: store.transform(for: item))
                .padding(4)
        }
        .frame(width: thumbnailSize.width, height: thumbnailSize.height)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    @ViewBuilder
    private func stackBackground(isCollapsedStack: Bool) -> some View {
        if isCollapsedStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(.quaternary.opacity(0.20))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(.separator.opacity(0.45), lineWidth: 0.75)
                )
                .offset(x: 8, y: -8)
        }
        RoundedRectangle(cornerRadius: 8)
            .fill(selectionBackground)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(.separator.opacity(isCollapsedStack ? 0.52 : 0), lineWidth: 0.75)
            )
    }
}
