import SwiftUI

struct HistogramPanel: View {
    @EnvironmentObject private var store: AppStore
    let item: MediaItem
    let previewURL: URL
    var compact = false
    var showsTitle = true
    var fillsAvailableSpace = false
    var showsPanelChrome = true
    var showsGraphChrome = true

    @State private var loadState = HistogramLoadState.loading

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
        .task(id: "\(item.thumbnailCacheKey)|\(previewURL.path)") {
            loadState = .loading
            if let histogram = await store.histograms.histogram(for: item, previewURL: previewURL), !histogram.isEmpty {
                loadState = .ready(histogram)
            } else {
                loadState = .unavailable
            }
        }
        .contextMenu {
            ForEach(HistogramDisplayMode.allCases) { mode in
                Button {
                    store.panelLayout.histogramDisplayMode = mode
                    store.saveWorkspace()
                } label: {
                    if mode == store.panelLayout.histogramDisplayMode {
                        Label(mode.displayName, systemImage: "checkmark")
                    } else {
                        Text(mode.displayName)
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
                    Label(L10n.tr("Histogram"), systemImage: "chart.bar.xaxis")
                        .font(compact ? .caption.weight(.semibold) : .callout.weight(.semibold))
                    Spacer()
                }
            }

            switch loadState {
            case .ready(let histogram):
                HistogramGraph(data: histogram, mode: store.panelLayout.histogramDisplayMode, showsChrome: showsGraphChrome)
                    .frame(height: graphHeight)
            case .loading:
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .frame(height: graphHeight)
            case .unavailable:
                AnalysisUnavailableView(compact: compact)
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
        if isFloatingChrome { return 74 }
        return compact ? 86 : 112
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

private enum HistogramLoadState {
    case loading
    case ready(HistogramData)
    case unavailable
}

private struct AnalysisUnavailableView: View {
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

private struct HistogramGraph: View {
    @Environment(\.colorScheme) private var colorScheme

    let data: HistogramData
    let mode: HistogramDisplayMode
    let showsChrome: Bool

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                if showsChrome {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(plotBackground)
                }

                if showsLuminance {
                    histogramAreaPath(data.luminance, in: proxy.size)
                        .fill(luminanceFill)
                }

                if showsRed {
                    histogramLinePath(data.red, in: proxy.size)
                        .stroke(redStroke, lineWidth: strokeWidth)
                }

                if showsGreen {
                    histogramLinePath(data.green, in: proxy.size)
                        .stroke(greenStroke, lineWidth: strokeWidth)
                }

                if showsBlue {
                    histogramLinePath(data.blue, in: proxy.size)
                        .stroke(blueStroke, lineWidth: strokeWidth)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: showsChrome ? 4 : 0))
        }
    }

    private var showsLuminance: Bool {
        mode == .rgbAndLuminance || mode == .luminance
    }

    private var showsRed: Bool {
        mode == .rgbAndLuminance || mode == .rgb || mode == .red
    }

    private var showsGreen: Bool {
        mode == .rgbAndLuminance || mode == .rgb || mode == .green
    }

    private var showsBlue: Bool {
        mode == .rgbAndLuminance || mode == .rgb || mode == .blue
    }

    private var plotBackground: Color {
        colorScheme == .light ? Color.black.opacity(0.46) : Color.black.opacity(0.38)
    }

    private var luminanceFill: Color {
        colorScheme == .light ? Color.white.opacity(0.34) : Color.white.opacity(0.26)
    }

    private var redStroke: Color {
        colorScheme == .light ? Color(red: 1.0, green: 0.12, blue: 0.12) : Color.red.opacity(0.9)
    }

    private var greenStroke: Color {
        colorScheme == .light ? Color(red: 0.05, green: 0.82, blue: 0.28) : Color.green.opacity(0.86)
    }

    private var blueStroke: Color {
        colorScheme == .light ? Color(red: 0.0, green: 0.48, blue: 1.0) : Color.blue.opacity(0.92)
    }

    private var strokeWidth: CGFloat {
        colorScheme == .light ? 1.35 : 1.15
    }

    private func histogramAreaPath(_ values: [Double], in size: CGSize) -> Path {
        var path = Path()
        guard !values.isEmpty, size.width > 0, size.height > 0 else { return path }
        let step = size.width / CGFloat(max(1, values.count - 1))
        path.move(to: CGPoint(x: 0, y: size.height))
        for (index, value) in values.enumerated() {
            let x = CGFloat(index) * step
            let y = size.height - CGFloat(min(max(value, 0), 1)) * size.height
            path.addLine(to: CGPoint(x: x, y: y))
        }
        path.addLine(to: CGPoint(x: size.width, y: size.height))
        path.closeSubpath()
        return path
    }

    private func histogramLinePath(_ values: [Double], in size: CGSize) -> Path {
        var path = Path()
        guard !values.isEmpty, size.width > 0, size.height > 0 else { return path }
        let step = size.width / CGFloat(max(1, values.count - 1))
        for (index, value) in values.enumerated() {
            let x = CGFloat(index) * step
            let y = size.height - CGFloat(min(max(value, 0), 1)) * size.height
            if index == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        return path
    }
}
