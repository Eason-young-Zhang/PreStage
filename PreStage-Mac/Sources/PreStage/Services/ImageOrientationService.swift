import Foundation
import ImageIO
import UniformTypeIdentifiers

struct ImageOrientationService {
    func rotateMetadata(at url: URL, clockwise: Bool) throws {
        let current = try readOrientation(at: url)
        let next = clockwise ? current.rotatedClockwise : current.rotatedCounterClockwise
        try writeOrientation(next, to: url)
    }

    func flipMetadata(at url: URL, horizontal: Bool) throws {
        let current = try readOrientation(at: url)
        let next = horizontal ? current.flippedHorizontally : current.flippedVertically
        try writeOrientation(next, to: url)
    }

    private func readOrientation(at url: URL) throws -> CGImagePropertyOrientation {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            throw OrientationError.cannotReadSource
        }
        let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        let rawValue = properties?[kCGImagePropertyOrientation] as? UInt32
            ?? (properties?[kCGImagePropertyOrientation] as? NSNumber)?.uint32Value
            ?? CGImagePropertyOrientation.up.rawValue
        return CGImagePropertyOrientation(rawValue: rawValue) ?? .up
    }

    private func writeOrientation(_ orientation: CGImagePropertyOrientation, to url: URL) throws {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let typeIdentifier = CGImageSourceGetType(source) else {
            throw OrientationError.cannotReadSource
        }

        let temporaryURL = url.deletingLastPathComponent()
            .appendingPathComponent(".\(url.lastPathComponent).orientation-\(UUID().uuidString)")

        guard let destination = CGImageDestinationCreateWithURL(
            temporaryURL as CFURL,
            typeIdentifier,
            CGImageSourceGetCount(source),
            nil
        ) else {
            throw OrientationError.cannotCreateDestination
        }

        let frameCount = CGImageSourceGetCount(source)
        for index in 0..<frameCount {
            var properties = (CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [CFString: Any]) ?? [:]
            if index == 0 {
                properties[kCGImagePropertyOrientation] = orientation.rawValue
                if var tiff = properties[kCGImagePropertyTIFFDictionary] as? [CFString: Any] {
                    tiff[kCGImagePropertyTIFFOrientation] = orientation.rawValue
                    properties[kCGImagePropertyTIFFDictionary] = tiff
                } else {
                    properties[kCGImagePropertyTIFFDictionary] = [kCGImagePropertyTIFFOrientation: orientation.rawValue]
                }
            }
            CGImageDestinationAddImageFromSource(destination, source, index, properties as CFDictionary)
        }

        guard CGImageDestinationFinalize(destination) else {
            try? FileManager.default.removeItem(at: temporaryURL)
            throw OrientationError.writeFailed
        }

        _ = try FileManager.default.replaceItemAt(url, withItemAt: temporaryURL)
    }
}

private enum OrientationError: LocalizedError {
    case cannotReadSource
    case cannotCreateDestination
    case writeFailed

    var errorDescription: String? {
        switch self {
        case .cannotReadSource:
            return "Could not read the image file."
        case .cannotCreateDestination:
            return "Could not create a writable image destination."
        case .writeFailed:
            return "Could not write the image orientation metadata."
        }
    }
}

private extension CGImagePropertyOrientation {
    var rotatedClockwise: CGImagePropertyOrientation {
        switch self {
        case .up: .right
        case .right: .down
        case .down: .left
        case .left: .up
        case .upMirrored: .rightMirrored
        case .rightMirrored: .downMirrored
        case .downMirrored: .leftMirrored
        case .leftMirrored: .upMirrored
        }
    }

    var rotatedCounterClockwise: CGImagePropertyOrientation {
        switch self {
        case .up: .left
        case .left: .down
        case .down: .right
        case .right: .up
        case .upMirrored: .leftMirrored
        case .leftMirrored: .downMirrored
        case .downMirrored: .rightMirrored
        case .rightMirrored: .upMirrored
        }
    }

    var flippedHorizontally: CGImagePropertyOrientation {
        switch self {
        case .up: .upMirrored
        case .upMirrored: .up
        case .down: .downMirrored
        case .downMirrored: .down
        case .left: .leftMirrored
        case .leftMirrored: .left
        case .right: .rightMirrored
        case .rightMirrored: .right
        }
    }

    var flippedVertically: CGImagePropertyOrientation {
        switch self {
        case .up: .downMirrored
        case .downMirrored: .up
        case .down: .upMirrored
        case .upMirrored: .down
        case .left: .rightMirrored
        case .rightMirrored: .left
        case .right: .leftMirrored
        case .leftMirrored: .right
        }
    }
}
