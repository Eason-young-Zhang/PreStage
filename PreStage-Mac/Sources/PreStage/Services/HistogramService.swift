import Foundation

struct HistogramData: Equatable, Sendable {
    let red: [Double]
    let green: [Double]
    let blue: [Double]
    let luminance: [Double]

    var isEmpty: Bool {
        red.isEmpty || green.isEmpty || blue.isEmpty || luminance.isEmpty
    }
}

actor HistogramService {
    private var cache = [String: HistogramData]()
    private let binCount: Int
    private let maxPixelSize: Int

    init(binCount: Int = 64, maxPixelSize: Int = 640) {
        self.binCount = max(8, binCount)
        self.maxPixelSize = max(64, maxPixelSize)
    }

    func histogram(for item: MediaItem, previewURL: URL) async -> HistogramData? {
        let key = cacheKey(for: item, previewURL: previewURL)
        if let cached = cache[key] {
            return cached
        }

        let binCount = binCount
        let maxPixelSize = maxPixelSize
        let data = await Task.detached(priority: .utility) {
            Self.makeHistogram(for: previewURL, binCount: binCount, maxPixelSize: maxPixelSize)
        }.value
        if let data {
            cache[key] = data
        }
        return data
    }

    func removeAll() {
        cache.removeAll()
    }

    static func makeHistogram(for url: URL, binCount: Int = 64, maxPixelSize: Int = 640) -> HistogramData? {
        guard let buffer = ImageAnalysisService.makeBuffer(for: url, maxPixelSize: maxPixelSize) else {
            return nil
        }

        var red = Array(repeating: 0, count: binCount)
        var green = Array(repeating: 0, count: binCount)
        var blue = Array(repeating: 0, count: binCount)
        var luminance = Array(repeating: 0, count: binCount)

        let maxValue = max(1, binCount - 1)
        for offset in stride(from: 0, to: buffer.pixels.count, by: 4) {
            let r = Int(buffer.pixels[offset])
            let g = Int(buffer.pixels[offset + 1])
            let b = Int(buffer.pixels[offset + 2])
            red[min(maxValue, r * binCount / 256)] += 1
            green[min(maxValue, g * binCount / 256)] += 1
            blue[min(maxValue, b * binCount / 256)] += 1
            let y = Int((0.2126 * Double(r)) + (0.7152 * Double(g)) + (0.0722 * Double(b)))
            luminance[min(maxValue, y * binCount / 256)] += 1
        }

        return HistogramData(
            red: normalize(red),
            green: normalize(green),
            blue: normalize(blue),
            luminance: normalize(luminance)
        )
    }

    private func cacheKey(for item: MediaItem, previewURL: URL) -> String {
        let modified = item.modifiedDate?.timeIntervalSince1970 ?? item.createdDate?.timeIntervalSince1970 ?? 0
        return "\(item.thumbnailCacheKey)|\(previewURL.path)|\(Int(modified.rounded()))|\(item.fileSize)"
    }

    private static func normalize(_ values: [Int]) -> [Double] {
        let peak = max(values.max() ?? 0, 1)
        return values.map { Double($0) / Double(peak) }
    }
}
