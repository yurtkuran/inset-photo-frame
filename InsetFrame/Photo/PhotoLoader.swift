import CoreGraphics
import Foundation
import ImageIO

/// A selected photograph: the untouched original data plus a downsampled preview.
///
/// `@unchecked Sendable` because `CGImage` is immutable.
struct SourcePhoto: @unchecked Sendable {
    /// Original encoded image data, never modified.
    let data: Data
    /// Orientation-corrected pixel dimensions of the full-resolution image.
    let pixelSize: CGSize
    /// Orientation-corrected preview image, at most `PhotoLoader.previewMaxPixelSize` on its long side.
    let previewImage: CGImage
}

enum PhotoError: Error, Equatable {
    case unreadableImage
    case renderingFailed
    case encodingFailed
}

enum PhotoLoader {
    /// Covers the largest preview area on current iPhones and iPads at native scale.
    static let previewMaxPixelSize = 2560

    static func load(data: Data, previewMaxPixelSize: Int = previewMaxPixelSize) throws -> SourcePhoto {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              CGImageSourceGetCount(source) > 0,
              let pixelSize = orientedPixelSize(of: source)
        else { throw PhotoError.unreadableImage }

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: previewMaxPixelSize,
            kCGImageSourceShouldCacheImmediately: true,
        ]
        guard let preview = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            throw PhotoError.unreadableImage
        }
        return SourcePhoto(data: data, pixelSize: pixelSize, previewImage: preview)
    }

    /// Pixel dimensions after applying the EXIF orientation (orientations 5–8 swap width and height).
    static func orientedPixelSize(of source: CGImageSource) -> CGSize? {
        guard let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = (properties[kCGImagePropertyPixelWidth] as? NSNumber)?.doubleValue,
              let height = (properties[kCGImagePropertyPixelHeight] as? NSNumber)?.doubleValue,
              width > 0, height > 0
        else { return nil }

        let orientation = (properties[kCGImagePropertyOrientation] as? NSNumber)?.uint32Value ?? 1
        return (5...8).contains(orientation)
            ? CGSize(width: height, height: width)
            : CGSize(width: width, height: height)
    }
}
