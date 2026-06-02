import CoreGraphics
import Foundation

enum PreviewRenderGeometry {
    static func imageRect(aspectRatio: CGFloat, in size: CGSize, scale: CGFloat) -> CGRect {
        guard aspectRatio > 0, size.width > 0, size.height > 0 else {
            return CGRect(origin: .zero, size: size)
        }

        let containerAspect = size.width / size.height
        let fittedSize: CGSize
        if aspectRatio > containerAspect {
            fittedSize = CGSize(width: size.width, height: size.width / aspectRatio)
        } else {
            fittedSize = CGSize(width: size.height * aspectRatio, height: size.height)
        }

        return pixelAligned(
            CGRect(
                x: (size.width - fittedSize.width) / 2,
                y: (size.height - fittedSize.height) / 2,
                width: fittedSize.width,
                height: fittedSize.height
            ),
            scale: scale
        )
    }

    static func cropRect(in imageRect: CGRect, aspectRatio: CGFloat, scale: CGFloat) -> CGRect {
        guard aspectRatio > 0, imageRect.width > 0, imageRect.height > 0 else {
            return .zero
        }

        let imageAspect = imageRect.width / imageRect.height
        let cropSize: CGSize
        if aspectRatio > imageAspect {
            cropSize = CGSize(width: imageRect.width, height: imageRect.width / aspectRatio)
        } else {
            cropSize = CGSize(width: imageRect.height * aspectRatio, height: imageRect.height)
        }

        return pixelAligned(
            CGRect(
                x: imageRect.midX - cropSize.width / 2,
                y: imageRect.midY - cropSize.height / 2,
                width: cropSize.width,
                height: cropSize.height
            ),
            scale: scale
        )
    }

    static func maskRects(imageRect: CGRect, cropRect: CGRect, scale: CGFloat) -> [CGRect] {
        let image = pixelAligned(imageRect, scale: scale)
        let crop = pixelAligned(cropRect, scale: scale)
        guard image.width > 0, image.height > 0, crop.width > 0, crop.height > 0 else {
            return []
        }

        let bleed = 1 / max(scale, 1)
        let top = CGRect(
            x: image.minX - bleed,
            y: image.minY - bleed,
            width: image.width + bleed * 2,
            height: max(0, crop.minY - image.minY) + bleed * 2
        )
        let bottom = CGRect(
            x: image.minX - bleed,
            y: crop.maxY - bleed,
            width: image.width + bleed * 2,
            height: max(0, image.maxY - crop.maxY) + bleed * 2
        )
        let left = CGRect(
            x: image.minX - bleed,
            y: crop.minY - bleed,
            width: max(0, crop.minX - image.minX) + bleed * 2,
            height: crop.height + bleed * 2
        )
        let right = CGRect(
            x: crop.maxX - bleed,
            y: crop.minY - bleed,
            width: max(0, image.maxX - crop.maxX) + bleed * 2,
            height: crop.height + bleed * 2
        )

        return [top, bottom, left, right]
            .filter { $0.width > bleed && $0.height > bleed }
            .map { pixelAligned($0, scale: scale) }
    }

    static func pixelAligned(_ rect: CGRect, scale: CGFloat) -> CGRect {
        let scale = max(scale, 1)
        let minX = floor(rect.minX * scale) / scale
        let minY = floor(rect.minY * scale) / scale
        let maxX = ceil(rect.maxX * scale) / scale
        let maxY = ceil(rect.maxY * scale) / scale
        return CGRect(x: minX, y: minY, width: max(0, maxX - minX), height: max(0, maxY - minY))
    }
}

enum PreviewSourceGeometry {
    static func aspectRatio(for item: MediaItem, previewURL: URL) -> CGFloat {
        if previewURL != item.url, let previewAspect = imageAspectRatio(at: previewURL) {
            return previewAspect
        }
        if let itemAspect = item.displayAspectRatio {
            return itemAspect
        }
        if let previewAspect = imageAspectRatio(at: previewURL) {
            return previewAspect
        }
        return 1
    }

    static func imageAspectRatio(at url: URL) -> CGFloat? {
        PreviewDecodeService.shared.imageAspectRatio(at: url)
    }

    static func imagePixelSize(at url: URL) -> CGSize? {
        PreviewDecodeService.shared.imagePixelSize(at: url)
    }

    static func supportsDirectRasterPreview(url: URL) -> Bool {
        PreviewDecodeService.shared.supportsDirectRasterPreview(url: url)
    }
}
