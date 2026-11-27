import CoreGraphics
import Testing
@testable import InsetFrame

/// Verifies that the preview (aspect-fit, letterboxed) and the full-resolution export
/// produce the same proportional frame.
struct PreviewExportConsistencyTests {
    private let settings = FrameSettings(widthPercent: 1.75, offsetPercent: 6.2, transparencyPercent: 0, color: .black)

    @Test(arguments: [
        (CGSize(width: 4032, height: 3024), CGSize(width: 390, height: 500)),
        (CGSize(width: 3024, height: 4032), CGSize(width: 1024, height: 700)),
        (CGSize(width: 8000, height: 1500), CGSize(width: 680, height: 900)),
        (CGSize(width: 2048, height: 2048), CGSize(width: 320, height: 600)),
    ])
    func previewGeometryMapsExactlyToExportGeometry(imageSize: CGSize, viewSize: CGSize) {
        let displayRect = AspectFit.rect(for: imageSize, in: CGRect(origin: .zero, size: viewSize))
        let preview = FrameGeometry(imageRect: displayRect, settings: settings)
        let export = FrameGeometry(imageRect: CGRect(origin: .zero, size: imageSize), settings: settings)

        let scale = displayRect.width / imageSize.width
        func toExport(_ rect: CGRect) -> CGRect {
            CGRect(
                x: (rect.minX - displayRect.minX) / scale,
                y: (rect.minY - displayRect.minY) / scale,
                width: rect.width / scale,
                height: rect.height / scale
            )
        }

        for (previewRect, exportRect) in [(preview.outerRect, export.outerRect), (preview.innerRect, export.innerRect)] {
            let mapped = toExport(previewRect)
            #expect(abs(mapped.minX - exportRect.minX) < 1e-6)
            #expect(abs(mapped.minY - exportRect.minY) < 1e-6)
            #expect(abs(mapped.width - exportRect.width) < 1e-6)
            #expect(abs(mapped.height - exportRect.height) < 1e-6)
        }
    }

    @Test func previewFrameIsAlignedToDisplayedImageNotViewBounds() {
        // A landscape photo letterboxed in a tall view: the frame must start at the photo, not the view.
        let displayRect = AspectFit.rect(for: CGSize(width: 4000, height: 2000), in: CGRect(x: 0, y: 0, width: 400, height: 800))
        let geometry = FrameGeometry(imageRect: displayRect, settings: settings)
        #expect(displayRect.minY == 300)
        #expect(abs(geometry.outerRect.minY - (300 + 200 * 0.062)) < 1e-9)
        #expect(abs(geometry.outerRect.minX - 200 * 0.062) < 1e-9)
    }

    /// Rasterizes the frame at two resolutions and compares the normalized edge positions.
    @Test func rasterizedFrameIsProportionalAcrossResolutions() {
        let small = edges(width: 300, height: 200)
        let large = edges(width: 3000, height: 2000)
        // One small-image pixel is 1/200 of S.
        #expect(abs(small.outerStart / 200 - large.outerStart / 2000) <= 1.0 / 200)
        #expect(abs(small.thickness / 200 - large.thickness / 2000) <= 1.0 / 200)
        #expect(large.outerStart == 124)  // 2000 * 6.2%
        #expect(large.thickness == 35)    // 2000 * 1.75%
    }

    private func edges(width: Int, height: Int) -> (outerStart: Double, thickness: Double) {
        let context = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: TestImages.sRGB, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        )!
        context.setFillColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        FrameRenderer.draw(settings, in: context, imageRect: CGRect(x: 0, y: 0, width: width, height: height))
        let bitmap = TestImages.Bitmap(context.makeImage()!)

        // Sum coverage along the middle row, left of center, to measure sub-pixel edges.
        let row = height / 2
        var start = 0.0
        var thickness = 0.0
        var foundStart = false
        for x in 0..<(width / 2) {
            let coverage = 1 - Double(bitmap[x, row].red) / 255
            if !foundStart && coverage > 0 {
                start = Double(x) + (1 - coverage)
                foundStart = true
            }
            thickness += coverage
        }
        return (start, thickness)
    }
}
