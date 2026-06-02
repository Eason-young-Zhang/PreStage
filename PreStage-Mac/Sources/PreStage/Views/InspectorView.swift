import SwiftUI

struct InspectorView: View {
    @EnvironmentObject private var store: AppStore
    let item: MediaItem?

    var body: some View {
        Group {
            if let item {
                ScrollView {
                    inspectorContent(for: item)
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                }
            } else {
                EmptyStateView(title: L10n.tr("Inspector"), systemImage: "sidebar.right", message: L10n.tr("Select media to edit rating, label, and copy state."))
                    .padding(16)
            }
        }
    }

    private func inspectorContent(for item: MediaItem) -> some View {
        VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 10) {
                    ThumbnailImage(item: item, size: CGSize(width: 58, height: 46), contentMode: .fit, transform: store.transform(for: item))
                        .frame(width: 58, height: 46)
                        .background(.quaternary.opacity(0.14))
                        .clipShape(RoundedRectangle(cornerRadius: 6))

                    VStack(alignment: .leading, spacing: 4) {
                        Text(store.displayName(for: item, hidingProxyExtension: true))
                            .font(.headline)
                            .lineLimit(2)
                        Text("\(item.mediaType.displayName) \(L10n.tr("Image")) - \(AppFormatters.byteCount.string(fromByteCount: item.fileSize))")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        if item.pairedAssetKey != nil {
                            Text(L10n.tr("RAW+JPEG pair"))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                        Text(item.url.deletingLastPathComponent().path)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .lineLimit(2)
                            .truncationMode(.middle)
                    }
                }

                Divider()

                RatingControl(rating: item.rating)
                PickStateControl(state: item.pickState)
                ColorLabelControl(label: item.colorLabel)

                if store.panelLayout.histogramPlacement == .inspector {
                    Divider()
                    HistogramPanel(item: item, previewURL: store.galleryPreviewURL(for: item), showsPanelChrome: false, showsGraphChrome: false)
                }

                if store.panelLayout.waveformPlacement == .inspector {
                    Divider()
                    WaveformPanel(item: item, previewURL: store.galleryPreviewURL(for: item), showsPanelChrome: false, showsGraphChrome: false)
                }

                Divider()

                MetadataRow(label: L10n.tr("Created"), value: formatted(item.createdDate))
                MetadataRow(label: L10n.tr("Captured"), value: formatted(item.captureDate))
                MetadataRow(label: L10n.tr("Modified"), value: formatted(item.modifiedDate))
                MetadataRow(label: L10n.tr("Dimensions"), value: dimensions(item))
                MetadataRow(label: L10n.tr("Color Space"), value: item.colorSpaceName ?? L10n.tr("Unknown"))
                MetadataRow(label: L10n.tr("Color Profile"), value: item.colorProfileName ?? L10n.tr("Unknown"))
                MetadataRow(label: L10n.tr("Camera"), value: item.cameraModel ?? L10n.tr("Unknown"))
                MetadataRow(label: L10n.tr("Lens"), value: item.lensModel ?? L10n.tr("Unknown"))
                MetadataRow(label: L10n.tr("Focal"), value: item.focalLength.map { String(format: "%.0f mm", $0) } ?? L10n.tr("Unknown"))
                MetadataRow(label: L10n.tr("Aperture"), value: item.aperture.map { String(format: "f/%.1f", $0) } ?? L10n.tr("Unknown"))
                MetadataRow(label: L10n.tr("Shutter"), value: item.shutterSpeed ?? L10n.tr("Unknown"))
                MetadataRow(label: L10n.tr("ISO"), value: item.iso.map(String.init) ?? L10n.tr("Unknown"))
                MetadataRow(label: L10n.tr("Pair"), value: item.pairedAssetKey == nil ? L10n.tr("None") : "RAW+JPEG")
                MetadataRow(label: L10n.tr("Copy"), value: item.copyStatus.label)
        }
    }

    private func formatted(_ date: Date?) -> String {
        guard let date else { return L10n.tr("Unknown") }
        return AppFormatters.shortDateTime.string(from: date)
    }

    private func dimensions(_ item: MediaItem) -> String {
        guard let width = item.pixelWidth, let height = item.pixelHeight else { return L10n.tr("Unknown") }
        return "\(width) x \(height)"
    }
}

private struct RatingControl: View {
    @EnvironmentObject private var store: AppStore
    let rating: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(L10n.tr("Rating")).font(.caption).foregroundStyle(.secondary)
            HStack(spacing: 4) {
                ForEach(1...5, id: \.self) { value in
                    Button {
                        store.setRating(value == rating ? 0 : value)
                    } label: {
                        Image(systemName: value <= rating ? "star.fill" : "star")
                    }
                    .buttonStyle(.plain)
                }
            }
            .font(.title3)
        }
    }
}

private struct PickStateControl: View {
    @EnvironmentObject private var store: AppStore
    let state: PickState

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(L10n.tr("Pick State")).font(.caption).foregroundStyle(.secondary)
            Picker(L10n.tr("Pick State"), selection: Binding(get: { state }, set: { store.setPickState($0) })) {
                Text(L10n.tr("Unmarked")).tag(PickState.unmarked)
                Text(L10n.tr("Pick")).tag(PickState.picked)
                Text(L10n.tr("Reject")).tag(PickState.rejected)
            }
            .labelsHidden()
            .pickerStyle(.segmented)
        }
    }
}

private struct ColorLabelControl: View {
    @EnvironmentObject private var store: AppStore
    let label: ColorLabel?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(L10n.tr("Color Label")).font(.caption).foregroundStyle(.secondary)
            HStack(spacing: 8) {
                ForEach(ColorLabel.allCases) { color in
                    Button {
                        store.setColorLabel(label == color ? nil : color)
                    } label: {
                        Circle()
                            .fill(color.color)
                            .frame(width: 18, height: 18)
                            .overlay(Circle().stroke(label == color ? Color.primary : Color.clear, lineWidth: 2))
                    }
                    .buttonStyle(.plain)
                    .help(color.displayName)
                }
            }
        }
    }
}

private struct MetadataRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .font(.caption)
    }
}
