import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Helpers for synthesizing and inspecting test images.
enum TestImages {
    struct Pixel {
        let red: Int
        let green: Int
        let blue: Int

        func isClose(to other: Pixel, tolerance: Int) -> Bool {
            abs(red - other.red) <= tolerance
                && abs(green - other.green) <= tolerance
                && abs(blue - other.blue) <= tolerance
        }
    }

    static let gray = Pixel(red: 128, green: 128, blue: 128)
    static let black = Pixel(red: 0, green: 0, blue: 0)
    static let red = Pixel(red: 255, green: 0, blue: 0)

    static var sRGB: CGColorSpace { CGColorSpace(name: CGColorSpace.sRGB)! }

    /// A solid mid-gray image with an optional red square in the top-left corner of the stored pixels.
    static func image(width: Int, height: Int, topLeftMarkerSize: Int = 0) -> CGImage {
        let context = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: sRGB, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        )!
        context.setFillColor(CGColor(srgbRed: 128 / 255, green: 128 / 255, blue: 128 / 255, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        if topLeftMarkerSize > 0 {
            context.setFillColor(CGColor(srgbRed: 1, green: 0, blue: 0, alpha: 1))
            // Core Graphics has a bottom-left origin, so the top-left corner is at maxY.
            context.fill(CGRect(
                x: 0, y: height - topLeftMarkerSize,
                width: topLeftMarkerSize, height: topLeftMarkerSize
            ))
        }
        return context.makeImage()!
    }

    static func encode(_ image: CGImage, as type: UTType, properties: [CFString: Any] = [:]) -> Data {
        let data = NSMutableData()
        let destination = CGImageDestinationCreateWithData(data, type.identifier as CFString, 1, nil)!
        var options = properties
        options[kCGImageDestinationLossyCompressionQuality] = 1.0
        CGImageDestinationAddImage(destination, image, options as CFDictionary)
        precondition(CGImageDestinationFinalize(destination))
        return data as Data
    }

    static func decode(contentsOf url: URL) -> (image: CGImage, properties: [CFString: Any], type: String) {
        let source = CGImageSourceCreateWithURL(url as CFURL, nil)!
        let image = CGImageSourceCreateImageAtIndex(source, 0, nil)!
        let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as! [CFString: Any]
        return (image, properties, CGImageSourceGetType(source)! as String)
    }

    /// Reads pixels in sRGB with a top-left origin.
    struct Bitmap {
        let width: Int
        let height: Int
        private let bytes: [UInt8]

        init(_ image: CGImage) {
            width = image.width
            height = image.height
            var buffer = [UInt8](repeating: 0, count: width * height * 4)
            buffer.withUnsafeMutableBytes { pointer in
                let context = CGContext(
                    data: pointer.baseAddress, width: image.width, height: image.height,
                    bitsPerComponent: 8, bytesPerRow: image.width * 4, space: TestImages.sRGB,
                    bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
                )!
                context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
            }
            bytes = buffer
        }

        subscript(x: Int, y: Int) -> Pixel {
            let index = (y * width + x) * 4
            return Pixel(red: Int(bytes[index]), green: Int(bytes[index + 1]), blue: Int(bytes[index + 2]))
        }
    }

    static func temporaryDirectory() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("InsetFrameTests-\(UUID().uuidString)", isDirectory: true)
    }
}
