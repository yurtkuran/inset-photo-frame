import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

struct ExportedPhoto: Sendable {
    let url: URL
    let pixelSize: CGSize
    let typeIdentifier: String
}

/// Renders the frame onto the full-resolution photograph and encodes it to a file.
///
/// Runs synchronously; call it off the main thread.
enum PhotoExporter {
    static var defaultDirectory: URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("Exports", isDirectory: true)
    }

    static func export(
        data: Data,
        settings: FrameSettings,
        to directory: URL = defaultDirectory
    ) throws -> ExportedPhoto {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              CGImageSourceGetCount(source) > 0
        else { throw PhotoError.unreadableImage }

        let sourceProperties = (CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]) ?? [:]
        let type = outputType(forSourceType: CGImageSourceGetType(source) as String?)
        let image = try render(source: source, settings: settings)
        let size = CGSize(width: image.width, height: image.height)

        let url = try outputURL(in: directory, type: type)
        try encode(image, properties: outputProperties(from: sourceProperties, pixelSize: size), type: type, to: url)
        return ExportedPhoto(url: url, pixelSize: size, typeIdentifier: type)
    }

    // MARK: - Rendering

    static func render(source: CGImageSource, settings: FrameSettings) throws -> CGImage {
        guard let sourceSize = PhotoLoader.orientedPixelSize(of: source) else { throw PhotoError.unreadableImage }

        // Decode at full resolution with the EXIF orientation applied.
        let decodeOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: Int(max(sourceSize.width, sourceSize.height)),
            kCGImageSourceShouldCacheImmediately: true,
        ]
        guard let photo = CGImageSourceCreateThumbnailAtIndex(source, 0, decodeOptions as CFDictionary) else {
            throw PhotoError.unreadableImage
        }

        let width = photo.width
        let height = photo.height
        let hasAlpha = ![.none, .noneSkipFirst, .noneSkipLast].contains(photo.alphaInfo)
        let alphaInfo: CGImageAlphaInfo = hasAlpha ? .premultipliedLast : .noneSkipLast
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: outputColorSpace(for: photo.colorSpace),
            bitmapInfo: alphaInfo.rawValue
        ) else { throw PhotoError.renderingFailed }

        let imageRect = CGRect(x: 0, y: 0, width: width, height: height)
        context.interpolationQuality = .high
        context.draw(photo, in: imageRect)
        FrameRenderer.draw(settings, in: context, imageRect: imageRect)

        guard let output = context.makeImage() else { throw PhotoError.renderingFailed }
        return output
    }

    /// Keeps the source RGB color space when it is a standard-range output space; otherwise Display P3.
    static func outputColorSpace(for space: CGColorSpace?) -> CGColorSpace {
        if let space,
           space.model == .rgb,
           space.supportsOutput,
           !CGColorSpaceUsesITUR_2100TF(space),
           !CGColorSpaceUsesExtendedRange(space) {
            return space
        }
        return CGColorSpace(name: CGColorSpace.displayP3)!
    }

    // MARK: - Encoding

    /// HEIC stays HEIC and JPEG stays JPEG; everything else becomes HEIC (JPEG if HEIC encoding is unavailable).
    static func outputType(forSourceType sourceType: String?) -> String {
        let jpeg = UTType.jpeg.identifier
        let heic = UTType.heic.identifier
        let preferred = sourceType == jpeg ? jpeg : heic
        let supported = (CGImageDestinationCopyTypeIdentifiers() as? [String]) ?? []
        return supported.contains(preferred) ? preferred : jpeg
    }

    /// Copies the source metadata (EXIF, TIFF, GPS, IPTC, …), marks the pixels as upright,
    /// and drops properties that describe the source encoding rather than the photograph.
    static func outputProperties(from source: [CFString: Any], pixelSize: CGSize) -> [CFString: Any] {
        var properties = source
        let encodingKeys: [CFString] = [
            kCGImagePropertyPixelWidth,
            kCGImagePropertyPixelHeight,
            kCGImagePropertyDepth,
            kCGImagePropertyHasAlpha,
            kCGImagePropertyColorModel,
            kCGImagePropertyProfileName,
            kCGImagePropertyPNGDictionary,
            kCGImagePropertyDNGDictionary,
            kCGImagePropertyHEICSDictionary,
            kCGImagePropertyMakerAppleDictionary,  // Contains HDR rendering hints that no longer apply to SDR output.
        ]
        encodingKeys.forEach { properties.removeValue(forKey: $0) }

        properties[kCGImagePropertyOrientation] = 1
        if var tiff = properties[kCGImagePropertyTIFFDictionary] as? [CFString: Any] {
            tiff[kCGImagePropertyTIFFOrientation] = 1
            properties[kCGImagePropertyTIFFDictionary] = tiff
        }
        if var exif = properties[kCGImagePropertyExifDictionary] as? [CFString: Any] {
            exif[kCGImagePropertyExifPixelXDimension] = Int(pixelSize.width)
            exif[kCGImagePropertyExifPixelYDimension] = Int(pixelSize.height)
            properties[kCGImagePropertyExifDictionary] = exif
        }
        properties[kCGImageDestinationLossyCompressionQuality] = 0.95
        return properties
    }

    static func encode(_ image: CGImage, properties: [CFString: Any], type: String, to url: URL) throws {
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, type as CFString, 1, nil) else {
            throw PhotoError.encodingFailed
        }
        CGImageDestinationAddImage(destination, image, properties as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { throw PhotoError.encodingFailed }
    }

    /// Returns a new file URL in `directory`, removing earlier exports so only the latest is kept.
    static func outputURL(in directory: URL, type: String) throws -> URL {
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: directory.path) {
            for file in try fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) {
                try? fileManager.removeItem(at: file)
            }
        } else {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let fileExtension = UTType(type)?.preferredFilenameExtension ?? "heic"
        return directory
            .appendingPathComponent("InsetFrame-\(formatter.string(from: Date()))")
            .appendingPathExtension(fileExtension)
    }
}
