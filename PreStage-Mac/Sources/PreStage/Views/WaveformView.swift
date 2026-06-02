import SwiftUI

struct WaveformPanel: View {
    @EnvironmentObject private var store: AppStore
    let item: MediaItem
    let previewURL: URL
    var compact = false
    var showsTitle = true
    var fillsAvailableSpace = false
    var showsPanelChrome = true
    var showsGraphChrome = true

    @State private var loadState = WaveformLoadState.loading

    var body: some View {
        Group {
            if fillsAvailableSpace {
                GeometryReader { proxy in
                    panelContent(graphHeight: graphHeight(availableHeight: proxy.size.height))
                        .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
                }
            } else {
                panelContent(graphHeight: fixedGraphHeight)
            }
        }
        .background {
            if showsPanelChrome {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(panelMaterial)
            }
        }
        .overlay {
            if showsPanelChrome {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(.separator.opacity(borderOpacity), lineWidth: borderWidth)
            }
        }
        .task(id: "\(item.thumbnailCacheKey)|\(previewURL.path)|\(store.panelLayout.waveformDirection.rawValue)") {
            loadState = .loading
            if let waveform = await store.waveforms.waveform(
                for: item,
                previewURL: previewURL,
                direction: store.panelLayout.waveformDirection
            ), !waveform.isEmpty {
                loadState = .ready(waveform)
            } else {
                loadState = .unavailable
            }
        }
        .contextMenu {
            Section(L10n.tr("Direction")) {
                ForEach(WaveformDirection.allCases) { direction in
                    Button {
                        store.panelLayout.waveformDirection = direction
                        store.saveWorkspace()
                    } label: {
                        if direction == store.panelLayout.waveformDirection {
                            Label(direction.displayName, systemImage: "checkmark")
                        } else {
                            Text(direction.displayName)
                        }
                    }
                }
            }
            Section(L10n.tr("Channel")) {
                ForEach(WaveformChannelMode.allCases) { mode in
                    Button {
                        store.panelLayout.waveformChannelMode = mode
                        store.saveWorkspace()
                    } label: {
                        if mode == store.panelLayout.waveformChannelMode {
                            Label(mode.displayName, systemImage: "checkmark")
                        } else {
                            Text(mode.displayName)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func panelContent(graphHeight: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: panelSpacing) {
            if showsTitle {
                HStack {
                    Label(L10n.tr("Waveform"), systemImage: "waveform.path.ecg.rectangle")
                        .font(compact ? .caption.weight(.semibold) : .callout.weight(.semibold))
                    Spacer()
                }
            }

            switch loadState {
            case .ready(let waveform):
                WaveformGraph(
                    data: waveform,
                    mode: store.panelLayout.waveformChannelMode,
                    showsChrome: showsGraphChrome
                )
                .frame(height: graphHeight)
            case .loading:
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .frame(height: graphHeight)
            case .unavailable:
                WaveformUnavailableView(compact: compact)
                    .frame(maxWidth: .infinity)
                    .frame(height: graphHeight)
            }
        }
        .padding(panelPadding)
        .frame(maxWidth: fillsAvailableSpace ? .infinity : nil, maxHeight: fillsAvailableSpace ? .infinity : nil, alignment: .topLeading)
    }

    private var isFloatingChrome: Bool {
        compact && !showsTitle
    }

    private var panelSpacing: CGFloat {
        isFloatingChrome ? 0 : 8
    }

    private var fixedGraphHeight: CGFloat {
        if isFloatingChrome { return 90 }
        return compact ? 96 : 124
    }

    private func graphHeight(availableHeight: CGFloat) -> CGFloat {
        guard fillsAvailableSpace else { return fixedGraphHeight }
        let titleHeight: CGFloat = showsTitle ? (compact ? 16 : 20) : 0
        let spacing = showsTitle ? panelSpacing : 0
        let available = availableHeight - panelPadding * 2 - titleHeight - spacing
        return max(1, available)
    }

    private var panelPadding: CGFloat {
        if !showsPanelChrome { return 0 }
        if isFloatingChrome { return 6 }
        return compact ? 10 : 12
    }

    private var cornerRadius: CGFloat {
        isFloatingChrome ? 6 : (compact ? 8 : 6)
    }

    private var panelMaterial: Material {
        isFloatingChrome ? .thinMaterial : .regularMaterial
    }

    private var borderOpacity: Double {
        isFloatingChrome ? 0.22 : 0.35
    }

    private var borderWidth: CGFloat {
        isFloatingChrome ? 0.35 : 0.5
    }
}

private enum WaveformLoadState {
    case loading
    case ready(WaveformData)
    case unavailable
}

private struct WaveformUnavailableView: View {
    var compact: Bool

    var body: some View {
        VStack(spacing: compact ? 3 : 5) {
            Image(systemName: "exclamationmark.triangle")
                .font(compact ? .caption : .callout)
            Text(L10n.tr("Unavailable"))
                .font(compact ? .caption2.weight(.semibold) : .caption.weight(.semibold))
            if !compact {
                Text(L10n.tr("Analysis unavailable for this file."))
                    .font(.caption2)
            }
        }
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
    }
}

private struct WaveformGraph: View {
    @Environment(\.colorScheme) private var colorScheme

    let data: WaveformData
    let mode: WaveformChannelMode
    let showsChrome: Bool

    var body: some View {
        GeometryReader { proxy in
            Canvas { context, size in
                if showsChrome {
                    context.fill(Path(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: 4), with: .color(plotBackground))
                }

                switch mode {
                case .luminance:
                    draw(data.luminance, in: size, color: luminanceColor, context: &context)
                case .rgbOverlay:
                    draw(data.red, in: size, color: redColor, context: &context)
                    draw(data.green, in: size, color: greenColor, context: &context)
                    draw(data.blue, in: size, color: blueColor, context: &context)
                case .red:
                    draw(data.red, in: size, color: redColor, context: &context)
                case .green:
                    draw(data.green, in: size, color: greenColor, context: &context)
                case .blue:
                    draw(data.blue, in: size, color: blueColor, context: &context)
                case .rgbParade:
                    drawParade(in: size, context: &context)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: showsChrome ? 4 : 0))
        }
    }

    private var plotBackground: Color {
        colorScheme == .light ? Color.black.opacity(0.58) : Color.black.opacity(0.42)
    }

    private var luminanceColor: Color {
        colorScheme == .light ? Color.white.opacity(0.86) : Color.white.opacity(0.72)
    }

    private var redColor: Color {
        colorScheme == .light ? Color(red: 1.0, green: 0.12, blue: 0.12).opacity(0.76) : Color.red.opacity(0.68)
    }

    private var greenColor: Color {
        colorScheme == .light ? Color(red: 0.05, green: 0.9, blue: 0.32).opacity(0.76) : Color.green.opacity(0.64)
    }

    private var blueColor: Color {
        colorScheme == .light ? Color(red: 0.0, green: 0.5, blue: 1.0).opacity(0.78) : Color.blue.opacity(0.7)
    }

    private func drawParade(in size: CGSize, context: inout GraphicsContext) {
        let third = size.width / 3
        draw(data.red, in: CGSize(width: third, height: size.height), xOffset: 0, color: redColor, context: &context)
        draw(data.green, in: CGSize(width: third, height: size.height), xOffset: third, color: greenColor, context: &context)
        draw(data.blue, in: CGSize(width: third, height: size.height), xOffset: third * 2, color: blueColor, context: &context)
    }

    private func draw(
        _ matrix: [[Double]],
        in size: CGSize,
        xOffset: CGFloat = 0,
        color: Color,
        context: inout GraphicsContext
    ) {
        guard !matrix.isEmpty, let first = matrix.first, !first.isEmpty, size.width > 0, size.height > 0 else { return }
        let columnCount = matrix.count
        let binCount = first.count
        let cellWidth = max(1, size.width / CGFloat(columnCount))
        let cellHeight = max(1, size.height / CGFloat(binCount))

        for (columnIndex, column) in matrix.enumerated() {
            for (binIndex, density) in column.enumerated() where density > 0.02 {
                let alpha = min(0.95, max(0.08, sqrt(density)))
                let x = xOffset + CGFloat(columnIndex) * size.width / CGFloat(columnCount)
                let y = size.height - CGFloat(binIndex + 1) * size.height / CGFloat(binCount)
                let rect = CGRect(x: x, y: y, width: cellWidth, height: cellHeight)
                context.fill(Path(rect), with: .color(color.opacity(alpha)))
            }
        }
    }
}
