import Foundation

enum WaveformDirection: String, Codable, CaseIterable, Identifiable {
    case horizontalX
    case verticalY

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .horizontalX: L10n.tr("Horizontal X")
        case .verticalY: L10n.tr("Vertical Y")
        }
    }
}

enum WaveformChannelMode: String, Codable, CaseIterable, Identifiable {
    case luminance
    case rgbOverlay
    case red
    case green
    case blue
    case rgbParade

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .luminance: L10n.tr("Luminance")
        case .rgbOverlay: L10n.tr("RGB Overlay")
        case .red: L10n.tr("Red Channel")
        case .green: L10n.tr("Green Channel")
        case .blue: L10n.tr("Blue Channel")
        case .rgbParade: L10n.tr("RGB Parade")
        }
    }
}

struct WaveformData: Equatable, Sendable {
    let direction: WaveformDirection
    let columns: Int
    let bins: Int
    let luminance: [[Double]]
    let red: [[Double]]
    let green: [[Double]]
    let blue: [[Double]]

    var isEmpty: Bool {
        columns <= 0 || bins <= 0 || luminance.isEmpty || red.isEmpty || green.isEmpty || blue.isEmpty
    }
}

actor WaveformService {
    private var cache = [String: WaveformData]()
    private let columns: Int
    private let bins: Int
    private let maxPixelSize: Int
    private let imageAnalysis: ImageAnalysisService

    init(
        columns: Int = 256,
        bins: Int = 256,
        maxPixelSize: Int = 768,
        imageAnalysis: ImageAnalysisService? = nil
    ) {
        self.columns = max(16, columns)
        self.bins = max(16, bins)
        self.maxPixelSize = max(64, maxPixelSize)
        self.imageAnalysis = imageAnalysis ?? ImageAnalysisService(maxPixelSize: self.maxPixelSize)
    }

    func waveform(for item: MediaItem, previewURL: URL, direction: WaveformDirection) async -> WaveformData? {
        let key = cacheKey(for: item, previewURL: previewURL, direction: direction)
        if let cached = cache[key] {
            return cached
        }

        guard let buffer = await imageAnalysis.buffer(for: item, previewURL: previewURL) else {
            return nil
        }

        let columns = columns
        let bins = bins
        let data = await Task.detached(priority: .utility) {
            Self.makeWaveform(from: buffer, direction: direction, columns: columns, bins: bins)
        }.value
        if let data {
            cache[key] = data
        }
        return data
    }

    func removeAll() {
        cache.removeAll()
    }

    static func makeWaveform(
        for url: URL,
        direction: WaveformDirection,
        columns: Int = 256,
        bins: Int = 256,
        maxPixelSize: Int = 768
    ) -> WaveformData? {
        guard let buffer = ImageAnalysisService.makeBuffer(for: url, maxPixelSize: maxPixelSize) else {
            return nil
        }
        return makeWaveform(from: buffer, direction: direction, columns: columns, bins: bins)
    }

    static func makeWaveform(
        from buffer: ImageAnalysisBuffer,
        direction: WaveformDirection,
        columns: Int = 256,
        bins: Int = 256
    ) -> WaveformData? {
        guard !buffer.isEmpty else { return nil }
        let columns = max(16, columns)
        let bins = max(16, bins)
        var luminance = emptyMatrix(columns: columns, bins: bins)
        var red = emptyMatrix(columns: columns, bins: bins)
        var green = emptyMatrix(columns: columns, bins: bins)
        var blue = emptyMatrix(columns: columns, bins: bins)

        for y in 0..<buffer.height {
            for x in 0..<buffer.width {
                let offset = ((y * buffer.width) + x) * 4
                guard offset + 2 < buffer.pixels.count else { continue }
                let r = Int(buffer.pixels[offset])
                let g = Int(buffer.pixels[offset + 1])
                let b = Int(buffer.pixels[offset + 2])
                let column = columnIndex(x: x, y: y, width: buffer.width, height: buffer.height, direction: direction, columns: columns)
                let luma = Int((0.2126 * Double(r)) + (0.7152 * Double(g)) + (0.0722 * Double(b)))

                red[column][binIndex(r, bins: bins)] += 1
                green[column][binIndex(g, bins: bins)] += 1
                blue[column][binIndex(b, bins: bins)] += 1
                luminance[column][binIndex(luma, bins: bins)] += 1
            }
        }

        return WaveformData(
            direction: direction,
            columns: columns,
            bins: bins,
            luminance: normalize(luminance),
            red: normalize(red),
            green: normalize(green),
            blue: normalize(blue)
        )
    }

    private func cacheKey(for item: MediaItem, previewURL: URL, direction: WaveformDirection) -> String {
        let modified = item.modifiedDate?.timeIntervalSince1970 ?? item.createdDate?.timeIntervalSince1970 ?? 0
        return "\(item.thumbnailCacheKey)|\(previewURL.path)|\(Int(modified.rounded()))|\(item.fileSize)|\(direction.rawValue)|\(columns)|\(bins)|\(maxPixelSize)"
    }

    private static func emptyMatrix(columns: Int, bins: Int) -> [[Double]] {
        Array(repeating: Array(repeating: 0, count: bins), count: columns)
    }

    private static func columnIndex(
        x: Int,
        y: Int,
        width: Int,
        height: Int,
        direction: WaveformDirection,
        columns: Int
    ) -> Int {
        switch direction {
        case .horizontalX:
            return min(columns - 1, x * columns / max(1, width))
        case .verticalY:
            return min(columns - 1, y * columns / max(1, height))
        }
    }

    private static func binIndex(_ value: Int, bins: Int) -> Int {
        min(bins - 1, max(0, value) * bins / 256)
    }

    private static func normalize(_ matrix: [[Double]]) -> [[Double]] {
        let peak = matrix.flatMap { $0 }.max() ?? 0
        guard peak > 0 else { return matrix }
        return matrix.map { column in
            column.map { $0 / peak }
        }
    }
}
