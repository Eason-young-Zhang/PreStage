import AppKit
import Quartz
import SwiftUI

struct RasterMediaPreviewView: NSViewRepresentable {
    let previewURL: URL
    let backgroundColor: NSColor

    func makeNSView(context: Context) -> RasterPreviewContainerView {
        RasterPreviewContainerView()
    }

    func updateNSView(_ nsView: RasterPreviewContainerView, context: Context) {
        nsView.previewBackgroundColor = backgroundColor
        nsView.update(with: previewURL)
    }
}

final class RasterPreviewContainerView: NSView {
    private let imageView = RasterImageView()
    private let fallbackQuickLookView = QLPreviewView(frame: .zero, style: .normal) ?? QLPreviewView()
    private var currentURL: URL?
    private var generation = 0
    private let decoder = PreviewDecodeService.shared

    var previewBackgroundColor: NSColor = .textBackgroundColor {
        didSet { applyBackgroundColor() }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    func update(with url: URL) {
        guard url != currentURL else { return }
        currentURL = url
        generation += 1
        let currentGeneration = generation
        imageView.image = nil
        imageView.isHidden = false
        fallbackQuickLookView.isHidden = true
        let targetSize = rasterTargetSize()

        DispatchQueue.global(qos: .userInitiated).async {
            let maxPixelSize = max(1024, Int(max(targetSize.width, targetSize.height).rounded()))
            let image = self.decoder.downsampledImage(at: url, maxPixelSize: maxPixelSize)
            DispatchQueue.main.async { [weak self] in
                guard let self, self.generation == currentGeneration else { return }
                self.imageView.image = image
                if image == nil {
                    self.showFallbackPreview(url)
                } else {
                    self.imageView.isHidden = false
                    self.fallbackQuickLookView.isHidden = true
                }
            }
        }
    }

    override func layout() {
        super.layout()
        imageView.frame = bounds
        fallbackQuickLookView.frame = bounds
        guard currentURL != nil, imageView.image == nil else { return }
        update(with: currentURL!)
    }

    private func setup() {
        wantsLayer = true
        applyBackgroundColor()
        imageView.frame = bounds
        imageView.autoresizingMask = [.width, .height]
        fallbackQuickLookView.frame = bounds
        fallbackQuickLookView.autoresizingMask = [.width, .height]
        fallbackQuickLookView.autostarts = true
        fallbackQuickLookView.shouldCloseWithWindow = false
        fallbackQuickLookView.isHidden = true
        fallbackQuickLookView.wantsLayer = true
        fallbackQuickLookView.layer?.backgroundColor = previewBackgroundColor.cgColor
        addSubview(fallbackQuickLookView)
        addSubview(imageView)
    }

    private func applyBackgroundColor() {
        wantsLayer = true
        layer?.backgroundColor = previewBackgroundColor.cgColor
        imageView.previewBackgroundColor = previewBackgroundColor
        fallbackQuickLookView.layer?.backgroundColor = previewBackgroundColor.cgColor
    }

    private func rasterTargetSize() -> CGSize {
        let scale = window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2
        let maxSide = max(bounds.width, bounds.height) * scale
        let fallback: CGFloat = 3200
        let value = max(1024, min(maxSide.isFinite && maxSide > 0 ? maxSide : fallback, 6144))
        return CGSize(width: value, height: value)
    }

    private func showFallbackPreview(_ url: URL) {
        fallbackQuickLookView.previewItem = url as NSURL
        fallbackQuickLookView.refreshPreviewItem()
        imageView.isHidden = true
        fallbackQuickLookView.isHidden = false
    }
}

final class RasterImageView: NSView {
    var image: CGImage? {
        didSet { needsDisplay = true }
    }

    var previewBackgroundColor: NSColor = .textBackgroundColor {
        didSet {
            layer?.backgroundColor = previewBackgroundColor.cgColor
            needsDisplay = true
        }
    }

    override var isFlipped: Bool { false }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    override func draw(_ dirtyRect: NSRect) {
        previewBackgroundColor.setFill()
        bounds.fill()
        guard let image, let context = NSGraphicsContext.current?.cgContext else { return }
        context.interpolationQuality = .high
        context.draw(image, in: bounds)
    }

    private func setup() {
        wantsLayer = true
        layer?.backgroundColor = previewBackgroundColor.cgColor
    }
}
