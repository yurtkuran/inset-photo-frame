import CoreGraphics
import Testing
@testable import InsetFrame

struct FrameGeometryTests {
    @Test func matchesSpecifiedPixelValues() {
        let small = FrameGeometry(imageRect: CGRect(x: 0, y: 0, width: 4000, height: 3000), widthPercent: 0.5, offsetPercent: 2)
        #expect(small.shortestSide == 3000)
        #expect(small.frameWidth == 15)
        #expect(small.frameOffset == 60)

        let large = FrameGeometry(imageRect: CGRect(x: 0, y: 0, width: 8000, height: 6000), widthPercent: 0.5, offsetPercent: 2)
        #expect(large.frameWidth == 30)
        #expect(large.frameOffset == 120)
    }

    @Test func offsetIsMeasuredToOuterEdgeAndStrokeIsCentered() {
        let geometry = FrameGeometry(imageRect: CGRect(x: 0, y: 0, width: 4000, height: 3000), widthPercent: 0.5, offsetPercent: 2)
        #expect(geometry.outerRect == CGRect(x: 60, y: 60, width: 3880, height: 2880))
        #expect(geometry.innerRect == CGRect(x: 75, y: 75, width: 3850, height: 2850))
        #expect(geometry.strokeCenterRect == CGRect(x: 67.5, y: 67.5, width: 3865, height: 2865))
    }

    @Test(arguments: [
        CGSize(width: 4000, height: 3000),
        CGSize(width: 3000, height: 4000),
        CGSize(width: 2048, height: 2048),
        CGSize(width: 12000, height: 2000),
        CGSize(width: 731, height: 4093),
    ])
    func appliesEqualInsetsOnAllFourSides(size: CGSize) {
        let imageRect = CGRect(origin: .zero, size: size)
        let geometry = FrameGeometry(imageRect: imageRect, widthPercent: 1.37, offsetPercent: 7.3)
        let outer = geometry.outerRect
        let insets = [outer.minX - imageRect.minX, outer.minY - imageRect.minY,
                      imageRect.maxX - outer.maxX, imageRect.maxY - outer.maxY]
        for inset in insets {
            #expect(abs(inset - geometry.frameOffset) < 1e-9)
        }
        #expect(abs(geometry.frameOffset - min(size.width, size.height) * 0.073) < 1e-9)
        #expect(geometry.isDrawable)
    }

    @Test func isProportionalAcrossResolutions() {
        let base = FrameGeometry(imageRect: CGRect(x: 0, y: 0, width: 400, height: 300), widthPercent: 2.5, offsetPercent: 12.5)
        for scale in [0.37, 1.0, 10.0, 24.0] as [CGFloat] {
            let scaled = FrameGeometry(
                imageRect: CGRect(x: 0, y: 0, width: 400 * scale, height: 300 * scale),
                widthPercent: 2.5, offsetPercent: 12.5
            )
            #expect(abs(scaled.frameWidth / scaled.shortestSide - base.frameWidth / base.shortestSide) < 1e-12)
            #expect(abs(scaled.innerRect.width / scale - base.innerRect.width) < 1e-9)
            #expect(abs(scaled.innerRect.minY / scale - base.innerRect.minY) < 1e-9)
        }
    }

    @Test func respectsImageRectOrigin() {
        let geometry = FrameGeometry(imageRect: CGRect(x: 10, y: 50, width: 400, height: 300), widthPercent: 1, offsetPercent: 5)
        #expect(geometry.outerRect == CGRect(x: 25, y: 65, width: 370, height: 270))
    }

    @Test func zeroWidthIsNotDrawable() {
        let geometry = FrameGeometry(imageRect: CGRect(x: 0, y: 0, width: 400, height: 300), widthPercent: 0, offsetPercent: 5)
        #expect(!geometry.isDrawable)
    }

    @Test func maximumSettingsLeaveAPositiveInterior() {
        let geometry = FrameGeometry(
            imageRect: CGRect(x: 0, y: 0, width: 6000, height: 1000),
            widthPercent: FrameSettings.widthRange.upperBound,
            offsetPercent: FrameSettings.offsetRange.upperBound
        )
        #expect(geometry.isDrawable)
        #expect(geometry.innerRect.height == 500)
    }

    @Test func emptyImageRectIsNotDrawable() {
        let geometry = FrameGeometry(imageRect: .zero, widthPercent: 1, offsetPercent: 1)
        #expect(!geometry.isDrawable)
    }
}

struct AspectFitTests {
    @Test func letterboxesPortraitImageInLandscapeBounds() {
        let rect = AspectFit.rect(for: CGSize(width: 3000, height: 4000), in: CGRect(x: 0, y: 0, width: 800, height: 400))
        #expect(rect == CGRect(x: 250, y: 0, width: 300, height: 400))
    }

    @Test func pillarboxesLandscapeImageInPortraitBounds() {
        let rect = AspectFit.rect(for: CGSize(width: 4000, height: 3000), in: CGRect(x: 0, y: 0, width: 390, height: 500))
        #expect(rect.width == 390)
        #expect(abs(rect.height - 292.5) < 1e-9)
        #expect(abs(rect.minY - 103.75) < 1e-9)
    }

    @Test func handlesDegenerateSizes() {
        #expect(AspectFit.rect(for: .zero, in: CGRect(x: 0, y: 0, width: 100, height: 100)) == .zero)
        #expect(AspectFit.rect(for: CGSize(width: 10, height: 10), in: .zero) == .zero)
    }
}
