import CoreGraphics
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers
@testable import InsetFrame

struct PhotoExportTests {
    private let frameOnly = FrameSettings(widthPercent: 1, offsetPercent: 5, transparencyPercent: 0, color: .black)
    private let noFrame = FrameSettings(widthPercent: 0, offsetPercent: 5, transparencyPercent: 0, color: .black)

    private func export(_ data: Data, settings: FrameSettings) throws -> ExportedPhoto {
        let directory = TestImages.temporaryDirectory()
        return try PhotoExporter.export(data: data, settings: settings, to: directory)
    }

    // MARK: - Dimensions

    @Test(arguments: [
        (1200, 800), (800, 1200), (1000, 1000), (3000, 500), (333, 1777),
    ])
    func preservesDimensions(width: Int, height: Int) throws {
        let data = TestImages.encode(TestImages.image(width: width, height: height), as: .jpeg)
        let exported = try export(data, settings: frameOnly)
        let decoded = TestImages.decode(contentsOf: exported.url)
        #expect(decoded.image.width == width)
        #expect(decoded.image.height == height)
        #expect(exported.pixelSize == CGSize(width: width, height: height))
    }

    // MARK: - Orientation

    @Test(arguments: [
        // EXIF orientation, expected output size, where the stored top-left marker ends up.
        (UInt32(1), 400, 200, "topLeft"),
        (UInt32(3), 400, 200, "bottomRight"),
        (UInt32(6), 200, 400, "topRight"),
        (UInt32(8), 200, 400, "bottomLeft"),
    ])
    func appliesOrientationAndWritesUprightPixels(orientation: UInt32, width: Int, height: Int, corner: String) throws {
        let raw = TestImages.image(width: 400, height: 200, topLeftMarkerSize: 60)
        let data = TestImages.encode(raw, as: .jpeg, properties: [kCGImagePropertyOrientation: orientation])

        let exported = try export(data, settings: noFrame)
        let decoded = TestImages.decode(contentsOf: exported.url)
        #expect(decoded.image.width == width)
        #expect(decoded.image.height == height)
        #expect((decoded.properties[kCGImagePropertyOrientation] as? NSNumber)?.intValue ?? 1 == 1)

        let bitmap = TestImages.Bitmap(decoded.image)
        let near = 20
        let far = { (extent: Int) in extent - 1 - near }
        let corners = [
            "topLeft": (near, near),
            "topRight": (far(width), near),
            "bottomLeft": (near, far(height)),
            "bottomRight": (far(width), far(height)),
        ]
        for (name, point) in corners {
            let expected = name == corner ? TestImages.red : TestImages.gray
            #expect(bitmap[point.0, point.1].isClose(to: expected, tolerance: 40), "\(name) of orientation \(orientation)")
        }
    }

    @Test func loaderReportsOrientedSizeAndPreviewAspect() throws {
        let raw = TestImages.image(width: 4000, height: 3000)
        let data = TestImages.encode(raw, as: .jpeg, properties: [kCGImagePropertyOrientation: UInt32(6)])
        let photo = try PhotoLoader.load(data: data, previewMaxPixelSize: 1000)
        #expect(photo.pixelSize == CGSize(width: 3000, height: 4000))
        #expect(max(photo.previewImage.width, photo.previewImage.height) == 1000)
        #expect(photo.previewImage.height > photo.previewImage.width)
        #expect(photo.data == data)
    }

    @Test func rejectsUnreadableData() {
        #expect(throws: PhotoError.unreadableImage) { try PhotoLoader.load(data: Data("not an image".utf8)) }
        #expect(throws: PhotoError.unreadableImage) {
            try PhotoExporter.export(data: Data(), settings: .defaults, to: TestImages.temporaryDirectory())
        }
    }

    // MARK: - Frame pixels

    @Test func drawsFrameAtExactPositionOnAllSides() throws {
        // S = 800: offset 5% = 40 px, width 1% = 8 px, so the ring spans 40..<48 from each edge.
        let data = TestImages.encode(TestImages.image(width: 1000, height: 800), as: .png)
        let exported = try export(data, settings: frameOnly)
        let bitmap = TestImages.Bitmap(TestImages.decode(contentsOf: exported.url).image)

        let ring = [(44, 400), (1000 - 1 - 44, 400), (500, 44), (500, 800 - 1 - 44)]
        let outside = [(20, 400), (1000 - 1 - 20, 400), (500, 20), (500, 800 - 1 - 20)]
        let inside = [(60, 400), (1000 - 1 - 60, 400), (500, 60), (500, 800 - 1 - 60), (500, 400)]

        for point in ring { #expect(bitmap[point.0, point.1].isClose(to: TestImages.black, tolerance: 12), "ring \(point)") }
        for point in outside + inside { #expect(bitmap[point.0, point.1].isClose(to: TestImages.gray, tolerance: 12), "photo \(point)") }
    }

    @Test func appliesTransparency() throws {
        var settings = frameOnly
        settings.transparencyPercent = 50
        let data = TestImages.encode(TestImages.image(width: 1000, height: 800), as: .png)
        let exported = try export(data, settings: settings)
        let bitmap = TestImages.Bitmap(TestImages.decode(contentsOf: exported.url).image)
        #expect(bitmap[44, 400].isClose(to: TestImages.Pixel(red: 64, green: 64, blue: 64), tolerance: 12))
    }

    @Test func fullyTransparentFrameLeavesPhotoUnchanged() throws {
        var settings = frameOnly
        settings.transparencyPercent = 100
        let data = TestImages.encode(TestImages.image(width: 1000, height: 800), as: .png)
        let exported = try export(data, settings: settings)
        let bitmap = TestImages.Bitmap(TestImages.decode(contentsOf: exported.url).image)
        #expect(bitmap[44, 400].isClose(to: TestImages.gray, tolerance: 12))
    }

    @Test func usesCustomColor() throws {
        var settings = frameOnly
        settings.color = FrameColor(sRGBRed: 1, green: 1, blue: 1)
        let data = TestImages.encode(TestImages.image(width: 1000, height: 800), as: .png)
        let exported = try export(data, settings: settings)
        let bitmap = TestImages.Bitmap(TestImages.decode(contentsOf: exported.url).image)
        #expect(bitmap[44, 400].isClose(to: TestImages.Pixel(red: 255, green: 255, blue: 255), tolerance: 12))
    }

    // MARK: - Format and metadata

    @Test func keepsJPEGAsJPEG() throws {
        let data = TestImages.encode(TestImages.image(width: 300, height: 200), as: .jpeg)
        let exported = try export(data, settings: frameOnly)
        #expect(exported.typeIdentifier == UTType.jpeg.identifier)
        #expect(TestImages.decode(contentsOf: exported.url).type == UTType.jpeg.identifier)
        #expect(exported.url.pathExtension == "jpeg" || exported.url.pathExtension == "jpg")
    }

    @Test func mapsOtherFormatsToHEIC() {
        let supported = (CGImageDestinationCopyTypeIdentifiers() as? [String]) ?? []
        let expected = supported.contains(UTType.heic.identifier) ? UTType.heic.identifier : UTType.jpeg.identifier
        #expect(PhotoExporter.outputType(forSourceType: UTType.png.identifier) == expected)
        #expect(PhotoExporter.outputType(forSourceType: UTType.heic.identifier) == expected)
        #expect(PhotoExporter.outputType(forSourceType: "com.adobe.raw-image") == expected)
        #expect(PhotoExporter.outputType(forSourceType: nil) == expected)
        #expect(PhotoExporter.outputType(forSourceType: UTType.jpeg.identifier) == UTType.jpeg.identifier)
    }

    @Test func preservesMetadataAndResetsOrientation() throws {
        let properties: [CFString: Any] = [
            kCGImagePropertyOrientation: UInt32(6),
            kCGImagePropertyExifDictionary: [
                kCGImagePropertyExifLensModel: "Test Lens 50mm",
                kCGImagePropertyExifFNumber: 2.8,
            ] as [CFString: Any],
            kCGImagePropertyGPSDictionary: [
                kCGImagePropertyGPSLatitude: 37.5,
                kCGImagePropertyGPSLatitudeRef: "N",
                kCGImagePropertyGPSLongitude: 122.25,
                kCGImagePropertyGPSLongitudeRef: "W",
            ] as [CFString: Any],
            kCGImagePropertyTIFFDictionary: [
                kCGImagePropertyTIFFMake: "Test Camera",
                kCGImagePropertyTIFFOrientation: UInt32(6),
            ] as [CFString: Any],
        ]
        let data = TestImages.encode(TestImages.image(width: 400, height: 300), as: .jpeg, properties: properties)
        let exported = try export(data, settings: frameOnly)
        let output = TestImages.decode(contentsOf: exported.url).properties

        #expect((output[kCGImagePropertyOrientation] as? NSNumber)?.intValue ?? 1 == 1)
        let exif = try #require(output[kCGImagePropertyExifDictionary] as? [CFString: Any])
        #expect(exif[kCGImagePropertyExifLensModel] as? String == "Test Lens 50mm")
        #expect((exif[kCGImagePropertyExifFNumber] as? NSNumber)?.doubleValue == 2.8)
        let gps = try #require(output[kCGImagePropertyGPSDictionary] as? [CFString: Any])
        #expect((gps[kCGImagePropertyGPSLatitude] as? NSNumber)?.doubleValue == 37.5)
        #expect(gps[kCGImagePropertyGPSLongitudeRef] as? String == "W")
        let tiff = try #require(output[kCGImagePropertyTIFFDictionary] as? [CFString: Any])
        #expect(tiff[kCGImagePropertyTIFFMake] as? String == "Test Camera")
        #expect((tiff[kCGImagePropertyTIFFOrientation] as? NSNumber)?.intValue ?? 1 == 1)
    }

    @Test func keepsOnlyTheLatestExport() throws {
        let directory = TestImages.temporaryDirectory()
        let data = TestImages.encode(TestImages.image(width: 300, height: 200), as: .jpeg)
        _ = try PhotoExporter.export(data: data, settings: frameOnly, to: directory)
        let second = try PhotoExporter.export(data: data, settings: frameOnly, to: directory)
        let files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        #expect(files.map(\.lastPathComponent) == [second.url.lastPathComponent])
    }

    @Test func neverModifiesSourceData() throws {
        let data = TestImages.encode(TestImages.image(width: 300, height: 200), as: .jpeg)
        let copy = data
        _ = try export(data, settings: frameOnly)
        #expect(data == copy)
    }
}
